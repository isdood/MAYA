use std::sync::Arc;
use parking_lot::RwLock;
use serde::{Serialize, de::DeserializeOwned};
use std::path::Path;
use std::collections::HashMap;
use std::time::{Instant, Duration};
use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;
use crate::storage::{Storage, WriteBatch, WriteBatchExt, Result, KnowledgeGraphError};
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

    /// Update operation statistics
    fn update_stats<F, R>(&self, is_read: bool, f: F) -> R
    where
        F: FnOnce() -> R,
    {
        let start = Instant::now();
        let result = f();
        let latency = start.elapsed();

        let mut stats = self.stats.write();
        if is_read {
            stats.add_read(latency);
        } else {
            stats.add_write(latency);
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
    type Batch = HybridBatch;

    fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let primary = SledStore::open(path)?;
        let cache = CachedStore::new(primary.clone());
        HybridStore::with_config(primary, cache, HybridConfig::default())
    }

    fn get<T: DeserializeOwned + Serialize>(&self, key: &[u8]) -> Result<Option<T>> {
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
                        match self.primary.get(key)? {
                            Some(value) => {
                                // Update cache for next time
                                if let Err(e) = self.cache.put(key, &value) {
                                    log::warn!("Failed to update cache: {}", e);
                                }
                                self.key_routing.write().insert(key.to_vec(), true);
                                Ok(Some(value))
                            },
                            None => Ok(None),
                        }
                    },
                    Err(e) => {
                        // Fallback to primary on cache error
                        log::warn!("Cache error: {}, falling back to primary", e);
                        self.primary.get(key)
                    },
                }
            } else {
                // Read from primary only
                self.key_routing.write().insert(key.to_vec(), false);
                self.primary.get(key)
            }
        })
    }
    
    fn open<P: AsRef<Path>>(_path: P) -> Result<Self> {
        Err(KnowledgeGraphError::StorageError("Use HybridStore::new() instead".to_string()))
    }
    
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        // For now, just forward to the primary storage
        // In a more advanced implementation, we might want to check the routing table
        // and potentially fetch some items from the cache
        self.primary.iter_prefix(prefix)
    }
    
    fn exists(&self, key: &[u8]) -> Result<bool> {
        if self.route_read(key) {
            match self.cache.get_raw(key) {
                Ok(Some(_)) => return Ok(true),
                Ok(None) => {}
                Err(e) => log::warn!("Cache error in exists: {}", e),
            }
        }
        self.primary.exists(key)
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
                        match self.primary.get_raw(key)? {
                            Some(value) => {
                                // Update cache for next time
                                if let Err(e) = self.cache.put_serialized(key, &value) {
                                    log::warn!("Failed to update cache: {}", e);
                                }
                                self.key_routing.write().insert(key.to_vec(), true);
                                Ok(Some(value))
                            },
                            None => Ok(None),
                        }
                    },
                    Err(e) => {
                        // Fallback to primary on cache error
                        log::warn!("Cache error: {}, falling back to primary", e);
                        self.primary.get_raw(key)
                    },
                }
            } else {
                // Read from primary only
                self.key_routing.write().insert(key.to_vec(), false);
                self.primary.get_raw(key)
            }
        })
    }

    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        self.update_stats(false, || {
            // Write to both backends for consistency
            self.primary.put(key, value)?;
            if let Err(e) = self.cache.put(key, value) {
                log::warn!("Failed to update cache: {}", e);
            }
            self.key_routing.write().insert(key.to_vec(), true);
            Ok(())
        })
    }

    fn delete(&self, key: &[u8]) -> Result<()> {
        self.update_stats(false, || {
            // Delete from both backends
            self.primary.delete(key)?;
            if let Err(e) = self.cache.delete(key) {
                log::warn!("Failed to delete from cache: {}", e);
            }
            self.key_routing.write().remove(key);
            Ok(())
        })
    }

    fn exists(&self, key: &[u8]) -> Result<bool> {
        self.update_stats(true, || {
            if self.route_read(key) {
                match self.cache.exists(key) {
                    Ok(true) => Ok(true),
                    _ => self.primary.exists(key),
                }
            } else {
                self.primary.exists(key)
            }
        })
    }
}

impl WriteBatchExt for HybridStore {
    type BatchType<'a> = HybridBatch where Self: 'a;

    fn batch(&self) -> Self::BatchType<'_> {
        HybridBatch {
            primary_batch: self.primary.batch(),
            cache_batch: self.cache.batch(),
            key_routing: self.key_routing.clone(),
        }
    }
    
    fn create_batch(&self) -> Self::BatchType<'_> {
        self.batch()
    }
    
    fn put_serialized(&self, key: &[u8], value: &[u8]) -> Result<()> {
        self.primary.put_serialized(key, value)?;
        if let Err(e) = self.cache.put_serialized(key, value) {
            log::warn!("Failed to update cache: {}", e);
        }
        self.key_routing.write().insert(key.to_vec(), true);
        Ok(())
    }

    fn delete_serialized(&self, key: &[u8]) -> Result<()> {
        self.primary.delete_serialized(key)?;
        if let Err(e) = self.cache.delete_serialized(key) {
            log::warn!("Failed to delete from cache: {}", e);
        }
        self.key_routing.write().remove(key);
        Ok(())
    }
}

/// Batch implementation for HybridStore
pub struct HybridBatch {
    primary_batch: <SledStore as WriteBatchExt>::BatchType<'_>,
    cache_batch: <CachedStore<SledStore> as WriteBatchExt>::BatchType<'_>,
    key_routing: Arc<RwLock<HashMap<Vec<u8>, bool>>>,
}

impl WriteBatch for HybridBatch {
    fn put<T: Serialize>(&mut self, key: &[u8], value: &T) -> Result<()> {
        // Serialize the value first
        let bytes = bincode::serialize(value).map_err(KnowledgeGraphError::from)?;
        self.put_serialized(key, &bytes)
    }
    
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        // Put in primary batch
        self.primary_batch.put_serialized(key, value)?;
        
        // Try to put in cache batch
        if let Err(e) = self.cache_batch.put_serialized(key, value) {
            log::warn!("Failed to update cache in batch: {}", e);
        }
        
        // Update routing
        self.key_routing.write().insert(key.to_vec(), true);
        Ok(())
    }

    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.delete_serialized(key)
    }
    
    fn delete_serialized(&mut self, key: &[u8]) -> Result<()> {
        // Delete from primary
        self.primary_batch.delete_serialized(key)?;
        
        // Try to delete from cache
        if let Err(e) = self.cache_batch.delete_serialized(key) {
            log::warn!("Failed to delete from cache in batch: {}", e);
        }
        
        // Update routing
        self.key_routing.write().remove(key);
        Ok(())
    }

    fn commit(self) -> Result<()> {
        // Commit primary first
        self.primary_batch.commit()?;
        
        // Then commit cache
        if let Err(e) = self.cache_batch.commit() {
            log::error!("Failed to commit cache batch: {}", e);
            return Err(KnowledgeGraphError::StorageError("Failed to commit cache batch".into()));
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_hybrid_store_basic() {
        let temp_dir = tempdir().unwrap();
        let primary = SledStore::open(temp_dir.path()).unwrap();
        let cache = CachedStore::new(primary.clone());
        let hybrid = HybridStore::new(primary, cache);

        // Test basic operations
        hybrid.put(b"key1", &42u64).unwrap();
        assert_eq!(hybrid.get::<u64>(b"key1").unwrap(), Some(42));
        
        // Test delete
        hybrid.delete(b"key1").unwrap();
        assert_eq!(hybrid.get::<u64>(b"key1").unwrap(), None);
        
        // Test batch operations
        let mut batch = hybrid.batch();
        batch.put(b"batch1", &100u64).unwrap();
        batch.put(b"batch2", &200u64).unwrap();
        batch.commit().unwrap();
        
        assert_eq!(hybrid.get::<u64>(b"batch1").unwrap(), Some(100));
        assert_eq!(hybrid.get::<u64>(b"batch2").unwrap(), Some(200));
    }
}
