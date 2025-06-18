//! Cached storage implementation for the knowledge graph

use std::sync::Arc;
use std::any::Any;
use log::{debug, trace};

use bincode;
use crate::cache::LruCacheWrapper;
use crate::error::Result;
use super::{Storage, WriteBatch, WriteBatchExt};

/// A storage wrapper that adds an LRU cache in front of another storage implementation
pub struct CachedStore<S> {
    inner: S,
    cache: Arc<LruCacheWrapper<Vec<u8>, Vec<u8>>>,
}

impl<S> CachedStore<S> {
    /// Create a new cached storage wrapper
    pub fn new(inner: S, cache_capacity: usize) -> Self {
        Self {
            inner,
            cache: Arc::new(LruCacheWrapper::new(cache_capacity)),
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
    pub fn invalidate(&self, key: &[u8]) -> Result<()> {
        let _ = self.cache.remove(&key.to_vec());
        Ok(())
    }
    
    /// Clear the entire cache
    pub fn clear_cache(&self) -> Result<()> {
        self.cache.clear()
            .map_err(|e| crate::error::KnowledgeGraphError::from(e.to_string()))
    }
}

impl<S> Storage for CachedStore<S>
where
    S: Storage + WriteBatchExt + 'static,
    <S as Storage>::Batch: WriteBatch + WriteBatchExt + 'static + Clone,
{
    type Batch = CachedBatch<<S as Storage>::Batch>;
    
    fn open<P: AsRef<std::path::Path>>(path: P) -> Result<Self> {
        let inner = S::open(path)?;
        Ok(Self::new(inner, 1000)) // Default cache size of 1000
    }

    fn get<T: serde::de::DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>> {
        // Try to get from cache first
        match self.cache.get(&key.to_vec()) {
            Ok(Some(cached)) => {
                trace!("Cache hit for key: {:?}", key);
                match bincode::deserialize(&cached) {
                    Ok(value) => return Ok(Some(value)),
                    Err(e) => {
                        log::warn!("Cache deserialization error: {}", e);
                        // Continue to try from storage
                    }
                }
            }
            Err(e) => {
                log::warn!("Cache get error: {}", e);
                // Continue to try from storage
            }
            _ => {}
        }
        
        debug!("Cache miss for key: {:?}", key);
        let value = self.inner.get(key)?;
        
        // Note: We don't cache the value here because we can't guarantee that T is serializable
        // The value will be cached when it's written using put()
        // This is a trade-off to maintain the trait bounds
        
        Ok(value)
    }
    
    fn put<T: serde::Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        // Store in underlying storage first
        self.inner.put(key, value)?;
        
        // Update cache with serialized value
        match bincode::serialize(value) {
            Ok(serialized) => {
                if let Err(e) = self.cache.put(key.to_vec(), serialized) {
                    log::warn!("Failed to update cache: {}", e);
                }
            }
            Err(e) => {
                log::warn!("Failed to serialize value for caching: {}", e);
                // Invalidate cache entry if we can't serialize the new value
                let _ = self.cache.remove(&key.to_vec());
            }
        }
        
        Ok(())
    }
    
    fn delete(&self, key: &[u8]) -> Result<()> {
        // Invalidate cache
        if let Err(e) = self.cache.remove(&key.to_vec()) {
            log::warn!("Failed to invalidate cache on delete: {}", e);
        }
        
        // Delete from underlying storage
        self.inner.delete(key)
    }
    
    fn exists(&self, key: &[u8]) -> Result<bool> {
        // Check cache first
        match self.cache.get(&key.to_vec()) {
            Ok(Some(_)) => return Ok(true),
            Err(e) => log::warn!("Cache get error in exists: {}", e),
            _ => {}
        }
        
        // Fall back to storage
        self.inner.exists(key)
    }
    
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        // For iteration, we don't use the cache as it's more complex to handle
        // and iteration is typically done over larger datasets
        self.inner.iter_prefix(prefix)
    }
    
    fn batch(&self) -> Self::Batch {
        CachedBatch {
            inner: <S as Storage>::batch(&self.inner),
            cache: self.cache.clone(),
        }
    }
}

#[derive(Debug, Clone)]
/// A batch of operations that will be applied atomically to the storage
/// and updates the cache accordingly.
/// 
/// This struct wraps an inner batch and a cache, ensuring that cache invalidation
/// happens atomically with the batch operations. It implements the `WriteBatch`
/// trait to provide a consistent interface with other batch types.
/// 
/// # Type Parameters
/// - `B`: The inner batch type that implements `WriteBatch`
pub struct CachedBatch<B> {
    inner: B,
    cache: Arc<LruCacheWrapper<Vec<u8>, Vec<u8>>>,
}

impl<B> WriteBatch for CachedBatch<B>
where
    B: WriteBatch + WriteBatchExt + 'static,
    B: std::any::Any + Clone,
{
    fn put(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.put_serialized(key, value)
    }
    
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        // Invalidate cache on put
        if let Err(e) = self.cache.remove(&key.to_vec()) {
            log::warn!("Failed to remove key from cache: {}", e);
        }
        // Clone the value to ensure it's owned
        let value = value.to_vec();
        self.inner.put_serialized(key, &value)
    }
    
    fn delete(&mut self, key: &[u8]) -> Result<()> {
        // Invalidate cache on delete
        if let Err(e) = self.cache.remove(&key.to_vec()) {
            log::warn!("Failed to remove key from cache: {}", e);
        }
        self.inner.delete(key)
    }
    
    fn clear(&mut self) {
        self.inner.clear();
    }
    
    fn as_any(&self) -> &dyn Any {
        self
    }
    
    fn commit(self: Box<Self>) -> Result<()> {
        // Convert to Box<dyn WriteBatch> and forward to WriteBatchExt::commit
        let inner = Box::new(self.inner);
        <B as WriteBatchExt>::commit(inner)
    }
}

impl<S> WriteBatchExt for CachedStore<S>
where
    S: Storage + WriteBatchExt + 'static,
    <S as Storage>::Batch: WriteBatch + WriteBatchExt + 'static + Clone,
{
    type Batch = CachedBatch<<S as Storage>::Batch>;
    
    fn batch(&self) -> Self::Batch {
        CachedBatch {
            inner: <S as Storage>::batch(&self.inner),
            cache: self.cache.clone(),
        }
    }
    
    fn commit(batch: Box<dyn WriteBatch>) -> Result<()> {
        // Downcast to our concrete type if possible
        if let Some(batch) = batch.as_any().downcast_ref::<CachedBatch<<S as Storage>::Batch>>() {
            // Extract inner batch and commit it
            let inner = Box::new(batch.inner.clone());
            <S as WriteBatchExt>::commit(inner)
        } else {
            // Otherwise forward to inner implementation
            <S as WriteBatchExt>::commit(batch)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::sled_store::SledStore;
    use tempfile::tempdir;
    use serde::{Serialize, Deserialize};
    
    #[derive(Debug, Serialize, Deserialize, PartialEq, Clone)]
    struct TestValue {
        data: String,
    }
    
    #[test]
    fn test_cached_store() -> Result<()> {
        let dir = tempdir()?;
        let inner = SledStore::open(dir.path())?;
        let cache = CachedStore::new(inner, 100);
        
        // Test basic put and get with String
        let key = b"test_key";
        let value = "test_value";
        
        // Put a value
        cache.put(key, &value.to_string())?;
        
        // Get it back
        let retrieved: Option<String> = cache.get(key)?;
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap(), value);
        
        // Test cache hit
        let cached: Option<String> = cache.get(key)?;
        assert!(cached.is_some());
        assert_eq!(cached.unwrap(), value);
        
        // Test delete
        cache.delete(key)?;
        assert!(cache.get::<String>(key)?.is_none());
        
        // Test clear cache
        cache.put(key, &value.to_string())?;
        cache.clear_cache()?;
        
        // After clearing cache, value should still be in storage
        assert!(cache.get::<String>(key)?.is_some());
        
        // Test cache invalidation
        let key2 = b"test_key2";
        let value2 = "test_value2";
        
        cache.put(key2, &value2.to_string())?;
        cache.invalidate(key2)?;
        
        // Should refill cache from storage
        let refilled: Option<String> = cache.get(key2)?;
        assert!(refilled.is_some());
        assert_eq!(refilled.unwrap(), value2);
        
        // Test batch operations
        let key3 = b"batch_key1";
        let value3 = "batch_value1";
        let key4 = b"batch_key2";
        let value4 = "batch_value2";
        
        // Create and execute a batch
        let mut batch = <CachedStore<_> as Storage>::batch(&cache);
        batch.put(key3, value3.as_bytes())?;
        batch.put_serialized(key4, value4.as_bytes())?;
        batch.delete(key2)?;
        
        // Commit the batch
        let batch = Box::new(batch);
        <CachedStore<SledStore> as WriteBatchExt>::commit(batch)?;
        
        // Verify batch operations
        let stored3: Option<Vec<u8>> = cache.get(key3)?;
        assert_eq!(stored3.as_deref(), Some(value3.as_bytes()));
        
        let stored4: Option<Vec<u8>> = cache.get(key4)?;
        assert_eq!(stored4.as_deref(), Some(value4.as_bytes()));
        
        assert!(cache.get::<String>(key2)?.is_none());
        
        Ok(())
    }
}
