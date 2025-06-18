//! Cached storage implementation for the knowledge graph

use std::sync::Arc;
use std::any::Any;
use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::atomic::{AtomicU64, Ordering};
use log::{debug, trace, warn};
use serde::{Serialize, de::DeserializeOwned};
use bincode::{self, Options};
use lru::LruCache;
use parking_lot::RwLock;

use std::fmt;
use std::error::Error as StdError;

use crate::error::{Result, KnowledgeGraphError};
use super::{Storage, WriteBatch, WriteBatchExt, serialize, deserialize};

// Helper error type for CachedStore
#[derive(Debug)]
struct CachedStoreError(String);

impl fmt::Display for CachedStoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "CachedStore error: {}", self.0)
    }
}

impl StdError for CachedStoreError {}

impl From<String> for CachedStoreError {
    fn from(err: String) -> Self {
        CachedStoreError(err)
    }
}

impl From<&str> for CachedStoreError {
    fn from(err: &str) -> Self {
        CachedStoreError(err.to_string())
    }
}

/// Performance metrics for the cached store
#[derive(Debug, Default)]
pub struct CacheMetrics {
    hits: AtomicU64,
    misses: AtomicU64,
    read_bytes: AtomicU64,
    write_bytes: AtomicU64,
}

impl Clone for CacheMetrics {
    fn clone(&self) -> Self {
        Self {
            hits: AtomicU64::new(self.hits.load(Ordering::Relaxed)),
            misses: AtomicU64::new(self.misses.load(Ordering::Relaxed)),
            read_bytes: AtomicU64::new(self.read_bytes.load(Ordering::Relaxed)),
            write_bytes: AtomicU64::new(self.write_bytes.load(Ordering::Relaxed)),
        }
    }
}

impl CacheMetrics {
    /// Record a cache hit
    fn record_hit(&self, bytes: usize) {
        self.hits.fetch_add(1, Ordering::Relaxed);
        self.read_bytes.fetch_add(bytes as u64, Ordering::Relaxed);
    }

    /// Record a cache miss
    fn record_miss(&self) {
        self.misses.fetch_add(1, Ordering::Relaxed);
    }

    /// Record bytes written to cache
    fn record_write(&self, bytes: usize) {
        self.write_bytes.fetch_add(bytes as u64, Ordering::Relaxed);
    }

    /// Get cache hit rate
    pub fn hit_rate(&self) -> f64 {
        let hits = self.hits.load(Ordering::Relaxed) as f64;
        let misses = self.misses.load(Ordering::Relaxed) as f64;
        let total = hits + misses;
        if total > 0.0 { hits / total } else { 0.0 }
    }

    /// Get total read bytes
    pub fn read_bytes(&self) -> u64 {
        self.read_bytes.load(Ordering::Relaxed)
    }

    /// Get total write bytes
    pub fn write_bytes(&self) -> u64 {
        self.write_bytes.load(Ordering::Relaxed)
    }
}

/// Configuration for the cached store
#[derive(Debug, Clone)]
pub struct CacheConfig {
    /// Maximum number of items in the cache
    pub capacity: usize,
    /// Enable read-ahead for sequential access patterns
    pub read_ahead: bool,
    /// Number of items to prefetch when read-ahead is enabled
    pub read_ahead_size: usize,
    /// Enable compression for cached values
    pub enable_compression: bool,
}

impl Default for CacheConfig {
    fn default() -> Self {
        Self {
            capacity: 10_000, // Default to 10,000 items
            read_ahead: true,
            read_ahead_size: 100, // Prefetch next 100 items
            enable_compression: true,
        }
    }
}

/// A storage wrapper that adds an LRU cache in front of another storage implementation
pub struct CachedStore<S> {
    inner: S,
    cache: Arc<RwLock<LruCache<Vec<u8>, Vec<u8>>>>,
    metrics: Arc<CacheMetrics>,
    config: CacheConfig,
    // For read-ahead functionality
    last_keys: RwLock<VecDeque<Vec<u8>>>,
}

impl<S> CachedStore<S> {
    /// Create a new cached storage wrapper with default configuration
    pub fn new(inner: S) -> Self {
        let config = CacheConfig::default();
        let cache = Arc::new(RwLock::new(LruCache::new(
            std::num::NonZeroUsize::new(config.capacity.max(1)).unwrap(),
        )));
        
        Self {
            inner,
            cache,
            metrics: Arc::new(CacheMetrics::default()),
            config,
            last_keys: RwLock::new(VecDeque::with_capacity(100)),
        }
    }
    
    /// Create a new cached storage wrapper with custom configuration
    pub fn with_config(inner: S, config: CacheConfig) -> Self {
        // Ensure capacity is at least 1 to create a valid NonZeroUsize
        let capacity = std::num::NonZeroUsize::new(config.capacity.max(1)).unwrap();
        let cache = Arc::new(RwLock::new(LruCache::new(capacity)));
        let metrics = Arc::new(CacheMetrics::default());
        
        Self {
            inner,
            cache,
            metrics,
            config,
            last_keys: RwLock::new(VecDeque::with_capacity(100)),
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
    
    /// Invalidate the cache for a specific key
    pub fn invalidate(&self, key: &[u8]) {
        let mut cache = self.cache.write();
        cache.pop(&key.to_vec());
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
    fn update_read_ahead_keys(&self, key: &[u8]) {
        if !self.config.read_ahead {
            return;
        }

        let mut last_keys = self.last_keys.write();
        
        // Add the current key to the history
        last_keys.push_back(key.to_vec());
        
        // Keep only the last N keys
        while last_keys.len() > 10 {
            last_keys.pop_front();
        }
    }

    /// Prefetch keys that are likely to be accessed next
    fn prefetch_keys(&self, prefix: &[u8]) {
        if !self.config.read_ahead {
            return;
        }

        // In a real implementation, we would analyze the access pattern
        // and prefetch keys that are likely to be accessed next.
        // This is a simplified version that just prefetches sequential keys.
        
        // Example: If the key is "key123", prefetch "key124", "key125", etc.
        // This is just a placeholder - you'd want to implement a more sophisticated
        // prefetching strategy based on your access patterns.
    }
}

impl<S> Storage for CachedStore<S>
where
    S: Storage + 'static,
    for<'a> <S as Storage>::Batch<'a>: WriteBatch + Clone + 'static,
{
    type Batch<'a> = CachedBatch<<S as Storage>::Batch<'a>> where Self: 'a;
    
    fn open<P: AsRef<std::path::Path>>(path: P) -> Result<Self> {
        let inner = S::open(path)?;
        Ok(Self::new(inner))
    }
    
    fn get<T: DeserializeOwned + Serialize>(&self, key: &[u8]) -> Result<Option<T>> {
        // Check cache first
        let cache = self.cache.read();
        if let Some(cached) = cache.get(key) {
            self.metrics.record_hit(cached.len());
            return deserialize(cached).map(Some);
        }
        
        // Cache miss, get from storage
        self.metrics.record_miss();
        if let Some(value) = self.inner.get(key).map_err(|e| KnowledgeGraphError::StorageError(e.to_string()))? {
            // Store the raw bytes in the cache
            let bytes = bincode::serialize(&value).map_err(|e| KnowledgeGraphError::BincodeError(e.to_string()))?;
            self.metrics.record_write(bytes.len());
            
            // Update cache
            self.cache.write().put(key.to_vec(), bytes);
            
            // Update read-ahead keys
            self.update_read_ahead_keys(key);
            
            Ok(Some(value))
        } else {
            Ok(None)
        }
    }
    
    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        // Serialize the value
        let serialized = serialize(value)?;
        
        // Update storage
        self.inner.put(key, value)?;
        
        // Update cache
        let mut cache = self.cache.write();
        cache.put(key.to_vec(), serialized);
        
        // Update metrics
        self.metrics.record_write(key.len() + std::mem::size_of_val(&value));
        
        Ok(())
    }
    
    fn delete(&self, key: &[u8]) -> Result<()> {
        self.inner.delete(key)?;
        self.cache.write().pop(key);
        Ok(())
    }
    
    fn exists(&self, key: &[u8]) -> Result<bool> {
        // Check cache first
        if self.cache.read().contains(key) {
            return Ok(true);
        }
        
        // Fall back to storage
        self.inner.exists(key)
    }
    
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        // For now, just forward to the inner storage
        // TODO: Consider caching iteration results
        self.inner.iter_prefix(prefix)
    }
    
    fn batch(&self) -> Self::Batch<'_> {
        CachedBatch {
            inner: self.inner.batch(),
            cache: self.cache.clone(),
            metrics: self.metrics.clone(),
            pending_puts: HashMap::new(),
            pending_deletes: HashSet::new(),
        }
    }
}

#[derive(Debug)]
/// A batch of operations that will be applied atomically to the storage
/// and updates the cache accordingly.
///
/// This struct wraps an inner batch and a cache, ensuring that cache updates
/// happen atomically with batch operations. It implements the `WriteBatch`
/// trait to provide a consistent interface with other batch types.
///
/// # Type Parameters
/// - `B`: The inner batch type that implements `WriteBatch`
pub struct CachedBatch<B> {
    inner: B,
    cache: Arc<RwLock<LruCache<Vec<u8>, Vec<u8>>>>,
    metrics: Arc<CacheMetrics>,
    pending_puts: HashMap<Vec<u8>, Vec<u8>>,
    pending_deletes: HashSet<Vec<u8>>,
}

impl<B> Clone for CachedBatch<B>
where
    B: Clone,
{
    fn clone(&self) -> Self {
        Self {
            inner: self.inner.clone(),
            cache: self.cache.clone(),
            metrics: self.metrics.clone(),
            pending_puts: self.pending_puts.clone(),
            pending_deletes: self.pending_deletes.clone(),
        }
    }
}

impl<B> WriteBatch for CachedBatch<B>
where
    B: WriteBatch + Clone + 'static,
    B: std::any::Any,
{
    fn put(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.pending_puts.insert(key.to_vec(), value.to_vec());
        self.inner.put(key, value)
    }
    
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        // Store the serialized value in pending_puts
        self.pending_puts.insert(key.to_vec(), value.to_vec());
        
        // Forward to inner batch
        self.inner.put_serialized(key, value)
    }
    
    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.pending_puts.remove(key);
        self.pending_deletes.insert(key.to_vec());
        self.inner.delete(key)
    }
    
    fn clear(&mut self) {
        self.pending_puts.clear();
        self.pending_deletes.clear();
        self.inner.clear();
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    
    fn commit(self) -> Result<()> {
        // Commit the inner batch first
        self.inner.commit()?;
        
        // Then update cache with pending operations
        let mut cache = self.cache.write();
        
        // Apply all pending puts
        for (key, value) in self.pending_puts {
            cache.put(key, value);
        }
        
        // Apply all pending deletes
        for key in self.pending_deletes {
            cache.pop(&key);
        }
        
        // Update metrics
        let bytes_written: usize = self.pending_puts.values().map(|v| v.len()).sum();
        self.metrics.record_write(bytes_written);
        
        Ok(())
    }
}

impl<S> WriteBatchExt for CachedStore<S>
where
    S: Storage + WriteBatchExt + 'static,
    for<'a> <S as Storage>::Batch<'a>: WriteBatch + Clone + 'static,
    for<'a> <S as WriteBatchExt>::BatchType<'a>: WriteBatch + 'static,
{
    type BatchType<'a> = CachedBatch<<S as Storage>::Batch<'a>> where Self: 'a;
    
    fn create_batch(&self) -> Self::BatchType<'_> {
        // Create a new batch from the inner storage
        CachedBatch {
            inner: self.inner.batch(),
            cache: self.cache.clone(),
            metrics: self.metrics.clone(),
            pending_puts: HashMap::new(),
            pending_deletes: HashSet::new(),
        }
    }
    
    fn commit(batch: Box<dyn WriteBatch>) -> Result<()> {
        // Downcast the batch to our concrete type
        if let Some(batch) = batch.as_any().downcast_ref::<CachedBatch<<S as Storage>::Batch<'_>>>() {
            // Clone the batch to avoid moving it
            let batch = batch.clone();
            
            // Update cache with pending operations
            {
                let mut cache = batch.cache.write();
                for (key, value) in &batch.pending_puts {
                    cache.put(key.clone(), value.clone());
                }
                
                for key in &batch.pending_deletes {
                    cache.pop(key);
                }
            }
            
            // Commit the inner batch
            let inner_batch = Box::new(batch.inner);
            <S as Storage>::commit(inner_batch)
        } else {
            Err(KnowledgeGraphError::StorageError("Invalid batch type".into()))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::sled_store::SledStore;
    use tempfile::tempdir;
    
    #[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
    struct TestValue {
        data: String,
        count: u64,
    }
    
    #[test]
    fn test_cached_store() -> Result<()> {
        let temp_dir = tempdir()?;
        
        // Create a new CachedStore with default config
        let inner = SledStore::open(temp_dir.path())?;
        let cache = CachedStore::new(inner);
        
        // Test put and get
        let key = b"test_key";
        let value = TestValue {
            data: "test data".to_string(),
            count: 42,
        };
        
        // Put should cache the value
        cache.put(key, &value)?;
        
        // Get should hit the cache
        let cached: Option<TestValue> = cache.get(key)?;
        assert_eq!(cached, Some(value.clone()));
        
        // Verify metrics
        assert!(cache.metrics().hit_rate() > 0.0);
        
        // Test delete
        cache.delete(key)?;
        let deleted: Option<TestValue> = cache.get(key)?;
        assert_eq!(deleted, None);
        
        // Test batch operations
        {
            let mut batch = <CachedStore<_> as Storage>::batch(&cache);
            batch.put_serialized(b"key1", b"value1")?;
            batch.put_serialized(b"key2", b"value2")?;
            batch.delete(b"key1")?;
            Box::new(batch).commit()?;
        }
        
        // Verify batch operations
        assert_eq!(cache.get::<Vec<u8>>(b"key1")?, None);
        assert_eq!(cache.get::<Vec<u8>>(b"key2")?, Some(b"value2".to_vec()));
        
        // Test cache invalidation
        cache.invalidate(b"key2");
        
        // Test clear cache
        cache.clear_cache();
        
        // Test with custom configuration
        let inner = SledStore::open(temp_dir.path())?;
        let config = CacheConfig {
            capacity: 100,
            read_ahead: true,
            read_ahead_size: 10,
            enable_compression: true,
        };
        let _cache = CachedStore::with_config(inner, config);
        
        Ok(())
    }
    
    #[test]
    fn test_metrics() -> Result<()> {
        let temp_dir = tempdir()?;
        let inner = SledStore::open(temp_dir.path())?;
        let cache = CachedStore::new(inner);
        
        // Initial metrics should be zero
        assert_eq!(cache.metrics().hit_rate(), 0.0);
        assert_eq!(cache.metrics().read_bytes(), 0);
        assert_eq!(cache.metrics().write_bytes(), 0);
        
        // Add some data
        cache.put(b"key1", &"value1".to_string())?;
        
        // Read should be a miss first, then hit
        let _: Option<String> = cache.get(b"key1")?; // Miss
        let _: Option<String> = cache.get(b"key1")?; // Hit
        
        // Check metrics
        assert!(cache.metrics().hit_rate() > 0.0);
        assert!(cache.metrics().read_bytes() > 0);
        assert!(cache.metrics().write_bytes() > 0);
        
        Ok(())
    }
}
