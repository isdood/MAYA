use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};
use std::path::Path;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use parking_lot::RwLock;
use serde::{Serialize, de::DeserializeOwned};

use crate::error::KnowledgeGraphError;
use crate::storage::{
    GenericWriteBatch, PrefetchExt, Result, Storage, WriteBatch, WriteBatchExt,
    prefetch::{PrefetchConfig, PrefetchingIterator},
};

// Re-export PrefetchConfig for public use
pub use crate::storage::prefetch::PrefetchConfig;

/// Adapter to convert PrefetchingIterator's Item type to match Storage's iterator
struct PrefetchingIteratorAdapter<I>(I);

impl<I, K, V> Iterator for PrefetchingIteratorAdapter<I>
where
    I: Iterator<Item = Result<(K, V)>>,
    K: 'static,
    V: 'static,
{
    type Item = (K, V);
    
    fn next(&mut self) -> Option<Self::Item> {
        match self.0.next() {
            Some(Ok(item)) => Some(item),
            Some(Err(_)) => None, // Skip errors
            None => None,
        }
    }
}
use crate::storage::sled_store::SledStore;
use crate::storage::cached_store::CachedStore;

/// Configuration for the hybrid storage system
#[derive(Clone, Debug)]
pub struct HybridConfig {
    /// Initial read/write ratio threshold for using CachedStore (0.0 to 1.0)
    pub initial_read_ratio_threshold: f64,
    /// Minimum number of operations before considering adaptive routing
    pub min_operations_for_adaptive: usize,
    /// Window size for tracking operation statistics
    pub stats_window_size: usize,
    /// How often to rebalance (in operations)
    pub rebalance_interval: usize,
}

impl Default for HybridConfig {
    fn default() -> Self {
        Self {
            initial_read_ratio_threshold: 0.7, // 70% reads
            min_operations_for_adaptive: 1000,
            stats_window_size: 10000,
            rebalance_interval: 1000,
        }
    }
}

/// Tracks operation statistics for adaptive routing
#[derive(Default, Clone, Debug)]
struct OperationStats {
    reads: usize,
    writes: usize,
    read_latency_ns: u128,
    write_latency_ns: u128,
}

impl OperationStats {
    fn add_read(&mut self, latency: Duration) {
        self.reads += 1;
        self.read_latency_ns += latency.as_nanos();
    }

    fn add_write(&mut self, latency: Duration) {
        self.writes += 1;
        self.write_latency_ns += latency.as_nanos();
    }

    fn total_operations(&self) -> usize {
        self.reads + self.writes
    }

    fn read_ratio(&self) -> f64 {
        let total = self.total_operations() as f64;
        if total == 0.0 { 0.0 } else { self.reads as f64 / total }
    }

    fn avg_read_latency_ns(&self) -> u128 {
        if self.reads == 0 { 0 } else { self.read_latency_ns / self.reads as u128 }
    }

    fn avg_write_latency_ns(&self) -> u128 {
        if self.writes == 0 { 0 } else { self.write_latency_ns / self.writes as u128 }
    }
}

/// Hybrid storage that routes requests between SledStore and CachedStore
pub struct HybridStore {
    primary: Arc<SledStore>,
    cache: Arc<CachedStore<SledStore>>,
    config: HybridConfig,
    stats: RwLock<OperationStats>,
    operation_count: std::sync::atomic::AtomicUsize,
    key_routing: RwLock<HashMap<Vec<u8>, bool>>, // true if key is in cache
}

impl HybridStore {
    /// Create a new HybridStore with default configuration
    pub fn new<P: AsRef<Path>>(path: P) -> Result<Self> {
        let primary = SledStore::open(path.as_ref())?;
        let cache = CachedStore::new(primary.clone());
        Self::with_config(primary, cache, HybridConfig::default())
    }

    /// Create a new HybridStore with custom configuration
    pub fn with_config(primary: SledStore, cache: CachedStore<SledStore>, config: HybridConfig) -> Result<Self> {
        Ok(Self {
            primary: Arc::new(primary),
            cache: Arc::new(cache),
            config,
            stats: RwLock::new(OperationStats::default()),
            operation_count: std::sync::atomic::AtomicUsize::new(0),
            key_routing: RwLock::new(HashMap::new()),
        })
    }

    /// Determine which backend to use for a read operation
    fn route_read(&self, key: &[u8]) -> bool {
        // Check if we have a specific routing for this key
        if let Some(cached) = self.key_routing.read().get(key) {
            return *cached;
        }

        // Use adaptive routing based on read ratio
        let stats = self.stats.read();
        if stats.total_operations() < self.config.min_operations_for_adaptive {
            // Not enough data, use initial threshold
            return self.config.initial_read_ratio_threshold > 0.5;
        }

        // If read ratio is high, prefer cache
        stats.read_ratio() > self.config.initial_read_ratio_threshold
    }

    fn should_use_cache(&self, is_read: bool) -> bool {
        // If we don't have enough data yet, use the initial strategy
        let stats = match self.stats.read() {
            Ok(stats) => stats,
            Err(_) => return is_read && self.config.initial_read_ratio_threshold > 0.0,
        };
        
        let total_ops = stats.total_operations();
        if total_ops < self.config.min_operations_for_adaptive {
            return is_read && self.config.initial_read_ratio_threshold > 0.0;
        }
        
        // If we have enough data, use the adaptive strategy
        let ratio = stats.read_ratio();
        if is_read {
            ratio > self.config.initial_read_ratio_threshold
        } else {
            // For writes, we want to ensure we're not overwhelming the cache
            ratio > self.config.initial_read_ratio_threshold * 0.8
        }
    }

    /// Update operation statistics
    fn update_stats<F, R>(&self, is_read: bool, f: F) -> R
    where
        F: FnOnce() -> R,
    {
        let start = Instant::now();
        let result = f();
        let elapsed = start.elapsed();
        
        // Update stats
        let mut stats = self.stats.write().unwrap();
        if is_read {
            stats.add_read(elapsed);
        } else {
            stats.add_write(elapsed);
        }
        
        // Periodically rebalance
        let op_count = self.operation_count.fetch_add(1, std::sync::atomic::Ordering::Relaxed) + 1;
        if op_count % self.config.rebalance_interval == 0 {
            self.rebalance();
        }

        result
    }

    /// Rebalance keys between primary and cache based on access patterns
    fn rebalance(&self) {
        // This is a simplified version - in a real implementation, you would:
        // 1. Analyze access patterns
        // 2. Identify hot/cold keys
        // 3. Move data between backends
        // 4. Update routing table
        
        // For now, we'll just clear the routing table to force re-evaluation
        // of routing decisions based on the latest stats
        self.key_routing.write().clear();
    }

    /// Get a consistent hash of a key for sharding
    fn key_shard(&self, key: &[u8]) -> u64 {
        let mut hasher = DefaultHasher::new();
        key.hash(&mut hasher);
        hasher.finish()
    }
}

impl Storage for HybridStore {
    type Batch<'a> = HybridBatch where Self: 'a;
    
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        // Use prefetching for better performance on sequential scans
        let config = PrefetchConfig {
            prefetch_size: 64,         // Prefetch 64 items ahead
            max_buffers: 4,            // Keep up to 4 prefetch buffers
            buffer_size: 256,          // 256 items per buffer
            prefetch_timeout_ms: 50,   // 50ms timeout
        };
        
        // Create a prefetching iterator
        match self.iter_prefix_prefetch(prefix, config) {
            Ok(iter) => {
                // Convert the PrefetchingIterator into a Box<dyn Iterator>
                let adapter = PrefetchingIteratorAdapter(iter);
                Box::new(adapter)
            },
            Err(e) => {
                // Fall back to non-prefetching iterator if prefetching fails
                log::warn!("Failed to create prefetching iterator: {}. Falling back to standard iterator", e);
                self.primary.iter_prefix(prefix)
            }
        }
    }
    
    fn create_batch(&self) -> Self::Batch<'_> {
        let primary_batch = Box::new(self.primary.create_batch());
        let cache_batch = Box::new(self.cache.create_batch());
        let key_routing = Arc::clone(&self.key_routing);
        
        HybridBatch {
            primary_batch,
            cache_batch,
            key_routing,
        }
    }
    
    fn get<T: DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>> {
        self.update_stats(true, || {
            if self.route_read(key) {
                // Try cache first
                match self.cache.get(key) {
                    Ok(Some(value)) => {
                        // Cache hit
                        self.key_routing.write().insert(key.to_vec(), true);
                        Ok(Some(value))
                    },
                    Ok(None) => {
                        // Cache miss, try primary
                        match self.primary.get(key) {
                            Ok(Some(value)) => {
                                // Update cache for next time
                                if let Err(e) = self.cache.put(key, &value) {
                                    log::warn!("Failed to update cache: {}", e);
                                }
                                self.key_routing.write().insert(key.to_vec(), true);
                                Ok(Some(value))
                            },
                            Ok(None) => Ok(None),
                            Err(e) => Err(e.into())
                        }
                    },
                    Err(e) => {
                        // Fallback to primary on cache error
                        log::warn!("Cache error: {}, falling back to primary", e);
                        self.primary.get(key).map_err(Into::into)
                    },
                }
            } else {
                // Read from primary only
                self.key_routing.write().insert(key.to_vec(), false);
                self.primary.get(key).map_err(Into::into)
            }
        })
    }

    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        self.update_stats(false, || {
            let value = bincode::serialize(value)
                .map_err(|e| KnowledgeGraphError::SerializationError(e.into()))?;
            
            let use_cache = self.should_use_cache(false);
            
            if use_cache {
                if let Err(e) = self.cache.put(key, &value) {
                    log::warn!("Failed to write to cache: {}", e);
    fn delete(&self, key: &[u8]) -> Result<()> {
        self.update_stats(false, || {
            // Delete from primary
            self.primary.delete(key)?;
            
            // Invalidate cache asynchronously
            let cache = self.cache.clone();
            let key = key.to_vec();
            
            // Spawn a blocking task to invalidate the cache
            std::thread::spawn(move || {
                if let Err(e) = cache.delete_serialized(&key) {
                    log::warn!("Failed to invalidate cache: {}", e);
                }
            });
            
            // Update key routing
            self.key_routing.write().remove(&key);
            
            Ok(())
        })
    }

    fn exists(&self, key: &[u8]) -> Result<bool> {
        self.update_stats(true, || {
            if self.route_read(key) {
                match self.cache.exists(key) {
                    Ok(true) => Ok(true),
                    Ok(false) => self.primary.exists(key),
                    Err(e) => {
                        log::warn!("Cache error in exists: {}", e);
                        self.primary.exists(key)
                    }
                }
            } else {
                self.primary.exists(key)
            }
        })
    }

    fn get_raw(&self, key: &[u8]) -> Result<Option<Vec<u8>>> {
        self.update_stats(true, || {
            if self.route_read(key) {
                // Try cache first
                match self.cache.get_raw(key) {
                    Ok(Some(value)) => {
                        // Cache hit
                        self.key_routing.write().insert(key.to_vec(), true);
                        Ok(Some(value))
                    },
                    Ok(None) => {
                        // Cache miss, try primary
                        match self.primary.get_raw(key) {
                            Ok(Some(value)) => {
                                // Update cache for next time
                                if let Err(e) = self.cache.put_serialized(key, &value) {
                                    log::warn!("Failed to update cache: {}", e);
                                }
                                self.key_routing.write().insert(key.to_vec(), true);
                                Ok(Some(value))
                            },
                            Ok(None) => Ok(None),
                            Err(e) => Err(e.into())
                        }
                    },
                    Err(e) => {
                        // Fallback to primary on cache error
                        log::warn!("Cache error: {}, falling back to primary", e);
                        self.primary.get_raw(key).map_err(Into::into)
                    },
                }
            } else {
                // Read from primary only
                self.key_routing.write().insert(key.to_vec(), false);
                self.primary.get_raw(key).map_err(Into::into)
            }
        })
    }
}

impl WriteBatchExt for HybridStore {
    type BatchType<'a> = HybridBatch where Self: 'a;
    
    fn create_batch(&self) -> Self::BatchType<'_> {
        HybridBatch::new(
            Box::new(self.primary.create_batch()) as Box<dyn WriteBatch + Send + Sync>,
            Box::new(self.cache.create_batch()) as Box<dyn WriteBatch + Send + Sync>,
            self.key_routing.clone(),
        )
    }
    
    fn put_serialized<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = bincode::serialize(value).map_err(KnowledgeGraphError::from)?;
        self.primary.put_serialized(key, &bytes)?;
        match self.cache.put_serialized(key, &bytes) {
            Ok(_) => {}
            Err(e) => log::warn!("Failed to update cache in put_serialized: {}", e),
        }
        self.key_routing.write().insert(key.to_vec(), true);
        Ok(())
    }
    
    fn delete_serialized(&self, key: &[u8]) -> Result<()> {
        self.primary.delete_serialized(key)?;
        if let Err(e) = self.cache.delete_serialized(key) {
            log::warn!("Failed to delete from cache in delete_serialized: {}", e);
        }
        self.key_routing.write().remove(key);
        Ok(())
    }
    

}

/// Batch implementation for HybridStore
#[derive(Debug)]
pub struct HybridBatch {
    primary_batch: Box<dyn WriteBatch + Send + Sync>,
    cache_batch: Box<dyn WriteBatch + Send + Sync>,
    key_routing: Arc<RwLock<HashMap<Vec<u8>, bool>>>,
}

impl HybridBatch {
    /// Create a new HybridBatch
    pub fn new(
        primary_batch: Box<dyn WriteBatch + Send + Sync>,
        cache_batch: Box<dyn WriteBatch + Send + Sync>,
        key_routing: Arc<RwLock<HashMap<Vec<u8>, bool>>>,
    ) -> Self {
        Self {
            primary_batch,
            cache_batch,
            key_routing,
        }
    }
}

impl WriteBatch for HybridBatch {
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        // Update primary first
        self.primary_batch.put_serialized(key, value)?;
        
        // Then update cache batch and routing
        self.cache_batch.put_serialized(key, value)?;
        self.key_routing.write().insert(key.to_vec(), true);
        
        Ok(())
    }
    
    fn delete_serialized(&mut self, key: &[u8]) -> Result<()> {
        // Delete from both batches
        self.primary_batch.delete_serialized(key)?;
        
        // Update cache batch and routing
        self.cache_batch.delete_serialized(key)?;
        self.key_routing.write().remove(key);
        
        Ok(())
    }
    
    fn clear(&mut self) {
        self.primary_batch.clear();
        self.cache_batch.clear();
    }
    
    fn commit(self) -> Result<()> {
        // Commit primary batch first
        let primary_result = {
            let batch = Box::into_raw(Box::new(self.primary_batch));
            let result = unsafe { (*batch).commit() };
            let _ = unsafe { Box::from_raw(batch) }; // Drop the box
            result
        };
        
        // Then commit cache batch
        let cache_result = {
            let batch = Box::into_raw(Box::new(self.cache_batch));
            let result = unsafe { (*batch).commit() };
            let _ = unsafe { Box::from_raw(batch) }; // Drop the box
            result
        };
        
        // Return primary result (more critical)
        primary_result?;
        cache_result?;
        
        Ok(())
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    
    fn as_mut_any(&mut self) -> &mut dyn std::any::Any {
        self
    }
}

// Implement GenericWriteBatch for HybridBatch
impl GenericWriteBatch for HybridBatch {
    type Error = crate::error::KnowledgeGraphError;
    
    fn put<T: Serialize>(&mut self, key: &[u8], value: &T) -> std::result::Result<(), Self::Error> {
        let bytes = bincode::serialize(value).map_err(|e| crate::error::KnowledgeGraphError::BincodeError(e.to_string()))?;
        self.put_serialized(key, &bytes)
    }
    
    fn delete(&mut self, key: &[u8]) -> std::result::Result<(), Self::Error> {
        self.delete_serialized(key)
    }
    
    fn clear(&mut self) {
        WriteBatch::clear(self)
    }
    
    fn commit(self) -> std::result::Result<(), Self::Error> {
        WriteBatch::commit(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    use crate::storage::{GenericWriteBatch, Storage};
    use crate::storage::sled_store::SledStore;
    use crate::storage::cached_store::CachedStore;
    
    #[test]
    fn test_hybrid_store_basic() {
        let temp_dir = tempdir().unwrap();
        let primary = SledStore::open(temp_dir.path()).unwrap();
        let cache = CachedStore::new(primary.clone());
        
        // Create a new HybridStore with the primary and cache
        let hybrid = HybridStore::with_config(
            primary,
            cache,
            HybridConfig::default(),
        ).unwrap();

        // Test basic operations
        hybrid.put(b"key1", &42u64).unwrap();
        assert_eq!(hybrid.get::<u64>(b"key1").unwrap(), Some(42));
        
        // Test delete
        hybrid.delete(b"key1").unwrap();
        assert_eq!(hybrid.get::<u64>(b"key1").unwrap(), None);
        
        // Test batch operations
        let mut batch = hybrid.create_batch();
        batch.put(b"batch1", &100u64).unwrap();
        batch.put(b"batch2", &200u64).unwrap();
        batch.commit().unwrap();
        
        assert_eq!(hybrid.get::<u64>(b"batch1").unwrap(), Some(100));
        assert_eq!(hybrid.get::<u64>(b"batch2").unwrap(), Some(200));
    }
}
