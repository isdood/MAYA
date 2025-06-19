//! Cached storage implementation for the knowledge graph

use std::sync::Arc;
use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use parking_lot::RwLock;
use rayon::prelude::*;
use crate::storage::batch_optimizer::{BatchConfig, BatchStats};
use std::fmt;
use serde::de::DeserializeOwned;
use serde::Serialize;
use lru::LruCache;
use crate::error::Result;
use crate::storage::{Storage, WriteBatch, WriteBatchExt, serialize, deserialize};
use crate::error::KnowledgeGraphError;

/// Configuration for the cached store
#[derive(Debug, Clone)]
pub struct CacheConfig {
    /// Maximum number of items to keep in the cache
    pub capacity: usize,
    /// Number of keys to prefetch on a read miss
    pub read_ahead_window: usize,
}

impl Default for CacheConfig {
    fn default() -> Self {
        Self {
            capacity: 10_000,  // Default cache size
            read_ahead_window: 0,  // No read-ahead by default
        }
    }
}

/// Performance metrics for the cached store
#[derive(Debug, Default)]
pub(crate) struct CacheMetrics {
    hits: AtomicU64,
    misses: AtomicU64,
    reads: AtomicU64,
    writes: AtomicU64,
    read_bytes: AtomicU64,
    write_bytes: AtomicU64,
}

impl CacheMetrics {
    /// Record a cache hit
    pub(crate) fn record_hit(&self, bytes: usize) {
        self.hits.fetch_add(1, Ordering::Relaxed);
        self.reads.fetch_add(1, Ordering::Relaxed);
        self.read_bytes.fetch_add(bytes as u64, Ordering::Relaxed);
    }
    
    /// Record a cache miss
    pub(crate) fn record_miss(&self) {
        self.misses.fetch_add(1, Ordering::Relaxed);
        self.reads.fetch_add(1, Ordering::Relaxed);
    }
    
    /// Record bytes written to cache
    pub(crate) fn record_write(&self, bytes: usize) {
        self.writes.fetch_add(1, Ordering::Relaxed);
        self.write_bytes.fetch_add(bytes as u64, Ordering::Relaxed);
    }
    
    /// Get cache hit rate
    pub(crate) fn hit_rate(&self) -> f64 {
        let hits = self.hits.load(Ordering::Relaxed) as f64;
        let misses = self.misses.load(Ordering::Relaxed) as f64;
        let total = hits + misses;
        
        if total > 0.0 { hits / total } else { 0.0 }
    }
    
    /// Get total read bytes
    pub(crate) fn read_bytes(&self) -> u64 {
        self.read_bytes.load(Ordering::Relaxed)
    }
    
    /// Get total write bytes
    pub(crate) fn write_bytes(&self) -> u64 {
        self.write_bytes.load(Ordering::Relaxed)
    }
}

/// A storage wrapper that adds an LRU cache in front of another storage implementation
pub struct CachedStore<S> {
    inner: S,
    cache: Arc<RwLock<LruCache<Vec<u8>, Vec<u8>>>>,
    metrics: Arc<CacheMetrics>,
    batch_config: BatchConfig,
    read_ahead_window: usize,
}

impl<S> CachedStore<S> {
    /// Create a new cached storage wrapper with default configuration
    pub fn new(inner: S) -> Self {
        let config = CacheConfig::default();
        let capacity = std::num::NonZeroUsize::new(config.capacity).unwrap();
        let cache = Arc::new(RwLock::new(LruCache::new(capacity)));
        
        Self {
            inner,
            cache,
            metrics: Arc::new(CacheMetrics::default()),
            batch_config: BatchConfig::default(),
            read_ahead_window: 0,
        }
    }
    
    /// Create a new cached storage wrapper with custom configuration
    pub fn with_config(inner: S, config: CacheConfig, batch_config: BatchConfig) -> Self {
        let capacity = std::num::NonZeroUsize::new(config.capacity).unwrap();
        let cache = Arc::new(RwLock::new(LruCache::new(capacity)));
        
        Self {
            inner,
            cache,
            metrics: Arc::new(CacheMetrics::default()),
            batch_config,
            read_ahead_window: config.read_ahead_window,
        }
    }
    
    /// Get a reference to the inner storage
    pub fn inner(&self) -> &S {
        &self.inner
    }
    
    /// Get a mutable reference to the inner storage
    pub fn inner_mut(&mut self) -> &mut S {
        &mut self.inner
    }
    
    /// Get the current batch configuration
    pub fn batch_config(&self) -> &BatchConfig {
        &self.batch_config
    }
    
    /// Update the batch configuration
    pub fn set_batch_config(&mut self, config: BatchConfig) {
        self.batch_config = config;
    }
    
    /// Invalidate the cache for a specific key
    pub fn invalidate(&self, key: &[u8]) {
        let mut cache = self.cache.write();
        cache.pop(key);
    }
    
    /// Clear the entire cache
    pub fn clear_cache(&self) {
        let mut cache = self.cache.write();
        cache.clear();
    }
    
    /// Get cache metrics
    pub fn metrics(&self) -> &CacheMetrics {
        &self.metrics
    }
    
    /// Update read-ahead keys
    pub fn update_read_ahead_keys(&self, key: &[u8]) {
        if self.read_ahead_window == 0 {
            return;
        }
        
        // In a real implementation, this would use the key to determine
        // related keys that are likely to be accessed next and prefetch them
        // For now, this is a no-op
    }
    
    /// Prefetch keys that are likely to be accessed next
    pub fn prefetch_keys(&self, _prefix: &[u8]) {
        // In a real implementation, this would prefetch keys with the given prefix
        // For now, this is a no-op
    }
}

impl<S> Storage for CachedStore<S>
where
    S: Storage + 'static,
    S: Send + Sync,
    for<'a> S::Batch<'a>: Send + Sync + 'a,
{
    type Batch<'a> = CachedBatch<S::Batch<'a>> where Self: 'a;
    
    fn get<T: DeserializeOwned + Serialize>(&self, key: &[u8]) -> Result<Option<T>> {
        // Try to get from cache first
        {
            let cache = self.cache.read();
            if let Some(cached) = cache.peek(key) {
                self.metrics.record_hit(cached.len());
                return Ok(Some(bincode::deserialize(cached)
                    .map_err(|e| KnowledgeGraphError::from(format!("Failed to deserialize cached value: {}", e)))?));
            }
        }
        
        // Cache miss, get from inner storage
        self.metrics.record_miss();
        let result = self.inner.get(key)?;
        
        // If we got a result, cache it
        if let Some(ref value) = result {
            let bytes = bincode::serialize(value)
                .map_err(|e| KnowledgeGraphError::from(format!("Failed to serialize value: {}", e)))?;
            
            let mut cache = self.cache.write();
            cache.put(key.to_vec(), bytes);
        }
        
        Ok(result)
    }
    
    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = bincode::serialize(value)
            .map_err(|e| KnowledgeGraphError::from(format!("Failed to serialize value: {}", e)))?;
        self.put_raw(key, &bytes)
    }
    
    fn put_raw(&self, key: &[u8], value: &[u8]) -> Result<()> {
        // Update cache
        {
            let mut cache = self.cache.write();
            cache.put(key.to_vec(), value.to_vec());
            self.metrics.record_write(value.len());
        }
        
        // Write to inner storage
        self.inner.put_raw(key, value)
    }
    
    fn delete(&self, key: &[u8]) -> Result<()> {
        // Invalidate cache
        self.invalidate(key);
        
        // Delete from inner storage
        self.inner.delete(key)
    }
    
    fn exists(&self, key: &[u8]) -> Result<bool> {
        // Check cache first
        {
            let cache = self.cache.read();
            if cache.contains(key) {
                self.metrics.record_hit(0);
                return Ok(true);
            }
        }
        
        // Check inner storage
        self.metrics.record_miss();
        self.inner.exists(key)
    }
    
    fn get_raw(&self, key: &[u8]) -> Result<Option<Vec<u8>>> {
        // Try to get from cache first
        {
            let cache = self.cache.read();
            if let Some(cached) = cache.peek(key) {
                self.metrics.record_hit(cached.len());
                return Ok(Some(cached.clone()));
            }
        }
        
        // Cache miss, get from inner storage
        self.metrics.record_miss();
        self.inner.get_raw(key)
    }
    
    fn put_raw(&self, key: &[u8], value: &[u8]) -> Result<()> {
        // Update cache
        {
            let mut cache = self.cache.write();
            cache.put(key.to_vec(), value.to_vec());
            self.metrics.record_write(value.len());
        }
        
        // Write to inner storage
        self.inner.put_raw(key, value)
    }
    
    fn iter_prefix(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        // In a real implementation, this would iterate over the cache first, then the inner storage
        // For now, just delegate to the inner storage
        self.inner.iter_prefix(prefix)
    }
    
    fn create_batch(&self) -> Self::Batch<'_> {
        // Create the inner batch first
        let inner_batch = self.inner.create_batch();
        
        CachedBatch::with_config(
            inner_batch,
            self.cache.clone(),
            self.metrics.clone(),
            self.batch_config.clone(),
            self.read_ahead_window,
        )
    }
}

/// A batch of operations that will be applied atomically to the storage
/// and updates the cache accordingly.
#[derive(Debug)]
pub(crate) struct CachedBatch<B> {
    inner: B,
    cache: Arc<RwLock<LruCache<Vec<u8>, Vec<u8>>>>,
    metrics: Arc<CacheMetrics>,
    pending_puts: HashMap<Vec<u8>, Vec<u8>>,
    pending_deletes: HashSet<Vec<u8>>,
    batch_config: BatchConfig,
    stats: BatchStats,
    read_ahead_window: usize,
}

impl<S> WriteBatchExt for CachedStore<S>
where
    S: Storage + WriteBatchExt + 'static,
    for<'a> S::Batch<'a>: Clone + Send + Sync + 'a,
{
    type Batch<'a> = CachedBatch<S::Batch<'a>> where Self: 'a;
    
    fn batch(&self) -> Self::Batch<'_> {
        self.create_batch()
    }
    
    fn create_batch(&self) -> Self::Batch<'_> {
        // Create the inner batch first
        let inner_batch = self.inner.create_batch();
        
        CachedBatch::with_config(
            inner_batch,
            self.cache.clone(),
            self.metrics.clone(),
            self.batch_config.clone(),
            self.read_ahead_window,
        )
    }
    
    // ... [rest of the implementation]
}

impl<B> CachedBatch<B>
where
    B: WriteBatch + 'static,
    B: Send + Sync,
{
    /// Create a new CachedBatch with the given configuration
    pub(crate) fn with_config(
        inner: B,
        cache: Arc<RwLock<LruCache<Vec<u8>, Vec<u8>>>>,
        metrics: Arc<CacheMetrics>,
        batch_config: BatchConfig,
        read_ahead_window: usize,
    ) -> Self {
        let stats = BatchStats::new(batch_config.initial_batch_size);
        
        Self {
            inner,
            cache,
            metrics,
            pending_puts: HashMap::new(),
            pending_deletes: HashSet::new(),
            batch_config,
            stats,
            read_ahead_window,
        }
    }
    
    /// Create a new CachedBatch with default configuration
    pub(crate) fn new(
        inner: B,
        cache: Arc<RwLock<LruCache<Vec<u8>, Vec<u8>>>>,
        metrics: Arc<CacheMetrics>,
    ) -> Self {
        Self::with_config(
            inner,
            cache,
            metrics,
            BatchConfig::default(),
            0, // Default read-ahead window
        )
    }
    
    /// Apply pending operations to the inner batch and clear them
    fn apply_pending_ops(&mut self) -> Result<()> {
        if !self.pending_puts.is_empty() || !self.pending_deletes.is_empty() {
            // Apply pending puts
            for (key, value) in self.pending_puts.drain() {
                self.inner.put_serialized(&key, &value)?;
            }
            
            // Apply pending deletes
            for key in self.pending_deletes.drain() {
                self.inner.delete_serialized(&key)?;
            }
            
            // Update stats
            self.stats.record_ops(self.pending_puts.len() + self.pending_deletes.len());
        }
        
        Ok(())
    }
}

impl<B> WriteBatch for CachedBatch<B>
where
    B: WriteBatch + 'static,
    B: Send + Sync,
{
    fn put<T: Serialize>(&mut self, key: &[u8], value: &T) -> Result<()> {
        let bytes = bincode::serialize(value)
            .map_err(|e| KnowledgeGraphError::from(format!("Failed to serialize value: {}", e)))?;
        self.put_serialized(key, &bytes)
    }
    
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        // Remove from pending deletes if it exists
        self.pending_deletes.remove(key);
        
        // Add to pending puts
        self.pending_puts.insert(key.to_vec(), value.to_vec());
        
        // Update cache
        {
            let mut cache = self.cache.write();
            cache.put(key.to_vec(), value.to_vec());
            self.metrics.record_write(value.len());
        }
        
        Ok(())
    }
    
    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.delete_serialized(key)
    }
    
    fn delete_serialized(&mut self, key: &[u8]) -> Result<()> {
        // Remove from pending puts if it exists
        self.pending_puts.remove(key);
        
        // Add to pending deletes
        self.pending_deletes.insert(key.to_vec());
        
        // Update cache
        {
            let mut cache = self.cache.write();
            cache.pop(key);
        }
        
        Ok(())
    }
    
    fn clear(&mut self) {
        self.pending_puts.clear();
        self.pending_deletes.clear();
        self.inner.clear();
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    
    fn as_mut_any(&mut self) -> &mut dyn std::any::Any {
        self
    }
    
    fn commit(mut self) -> Result<()> {
        // Apply all pending operations
        self.apply_pending_ops()?;
        
        // Commit the inner batch
        self.inner.commit()?;
        
        // Update metrics
        self.metrics.record_write(self.pending_puts.len() + self.pending_deletes.len());
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    // ... [test module content]
}
