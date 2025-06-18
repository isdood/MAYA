//! Caching layer for the knowledge graph

use std::sync::{Arc, RwLock, RwLockWriteGuard, RwLockReadGuard};
use lru::LruCache;
use std::hash::Hash;
use std::num::NonZeroUsize;
use std::fmt;
use std::ops::Deref;
use std::fmt::Debug;
use std::cmp::Eq;
use std::any::Any;

/// A thread-safe LRU cache wrapper
pub struct LruCacheWrapper<K, V> 
where
    K: Hash + Eq + Clone + Send + Sync + 'static,
    V: Clone + Send + Sync + 'static,
{
    cache: RwLock<LruCache<K, Arc<V>>>,
}

impl<K, V> Debug for LruCacheWrapper<K, V> 
where
    K: Hash + Eq + Clone + Debug + Send + Sync + 'static,
    V: Clone + Debug + Send + Sync + 'static,
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LruCacheWrapper")
         .field("cache", &self.cache)
         .finish()
    }
}

impl<K, V> LruCacheWrapper<K, V>
where
    K: Eq + Hash + Clone + Send + Sync + 'static,
    V: Clone + Send + Sync + 'static,
{
    /// Create a new LRU cache with the given capacity
    pub fn new(capacity: usize) -> Self {
        let cache = LruCache::new(
            NonZeroUsize::new(capacity).unwrap_or_else(|| NonZeroUsize::new(1000).unwrap())
        );
        
        Self {
            cache: RwLock::new(cache),
        }
    }
    
    /// Get a write lock on the cache
    fn write(&self) -> Result<RwLockWriteGuard<'_, LruCache<K, Arc<V>>>> {
        self.cache.write().map_err(|_| {
            std::io::Error::new(
                std::io::ErrorKind::Other,
                "Failed to acquire write lock on cache",
            )
        })
    }
    
    /// Get a read lock on the cache
    fn read(&self) -> Result<RwLockReadGuard<'_, LruCache<K, Arc<V>>>> {
        self.cache.read().map_err(|_| {
            std::io::Error::new(
                std::io::ErrorKind::Other,
                "Failed to acquire read lock on cache",
            )
        })
    }

    /// Get a value from the cache
    pub fn get(&self, key: &K) -> Option<Arc<V>> {
        let cache = self.read().ok()?;
        cache.peek(key).map(Arc::clone)
    }

    /// Insert a value into the cache
    pub fn put(&self, key: K, value: V) -> Result<()> {
        let mut cache = self.write()?;
        cache.put(key, Arc::new(value));
        Ok(())
    }

    /// Remove a value from the cache
    pub fn remove(&self, key: &K) -> Option<Arc<V>> {
        self.write().ok()?.pop(key)
    }

    /// Clear the cache
    pub fn clear(&self) -> Result<()> {
        let mut cache = self.write()?;
        cache.clear();
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lru_cache_basic() {
        let cache = LruCacheWrapper::new(2);
        
        // Test insert and get
        cache.put("key1", "value1");
        assert_eq!(cache.get(&"key1").as_deref(), Some(&"value1"));
        
        // Test eviction
        cache.put("key2", "value2");
        cache.put("key3", "value3");
        
        // key1 should be evicted
        assert!(cache.get(&"key1").is_none());
        assert_eq!(cache.get(&"key2").as_deref(), Some(&"value2"));
        assert_eq!(cache.get(&"key3").as_deref(), Some(&"value3"));
        
        // Test remove
        cache.remove(&"key2");
        assert!(cache.get(&"key2").is_none());
        
        // Test clear
        cache.clear();
        assert!(cache.get(&"key3").is_none());
    }
}
