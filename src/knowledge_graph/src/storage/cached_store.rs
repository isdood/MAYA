//! Cached storage implementation for the knowledge graph

use std::sync::Arc;
use std::any::Any;
use std::fmt;
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
        self.cache.remove(&key.to_vec());
        Ok(())
    }
    
    /// Clear the entire cache
    pub fn clear_cache(&self) -> Result<()> {
        self.cache.clear()
    }
}

impl<S> Storage for CachedStore<S>
where
    S: Storage + WriteBatchExt + 'static,
    S::Batch: WriteBatch + 'static,
    <S as Storage>::Batch: 'static,
{
    type Batch = CachedBatch<'static, <S as Storage>::Batch>;
    
    fn open<P: AsRef<std::path::Path>>(path: P) -> Result<Self> {
        let inner = S::open(path)?;
        Ok(Self::new(inner, 1000)) // Default cache size of 1000
    }

    fn get<T: serde::de::DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>> {
        // Try to get from cache first
        if let Some(cached) = self.cache.get(&key.to_vec()) {
            trace!("Cache hit for key: {:?}", key);
            return bincode::deserialize(&cached)
                .map_err(|e| crate::error::KnowledgeGraphError::from(format!("Deserialization error: {}", e)));
        }
        
        debug!("Cache miss for key: {:?}", key);
        let value = self.inner.get(key)?;
        
        // Cache the result if found
        if let Some(ref value_bytes) = value {
            if let Ok(serialized) = bincode::serialize(value_bytes) {
                let _ = self.cache.put(key.to_vec(), serialized);
            }
        }
        
        Ok(value)
    }
    
    fn put<T: serde::Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        // Invalidate cache
        let _ = self.cache.remove(&key.to_vec());
        
        // Update storage
        self.inner.put(key, value)
    }
    
    fn delete(&self, key: &[u8]) -> Result<()> {
        // Invalidate cache
        let _ = self.cache.remove(&key.to_vec());
        
        // Update storage
        self.inner.delete(key)
    }
    
    fn exists(&self, key: &[u8]) -> Result<bool> {
        // Try cache first
        if self.cache.get(&key.to_vec()).is_some() {
            return Ok(true);
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
            inner: self.inner.batch(),
            cache: &self.cache,
        }
    }
}

#[derive(Debug, Clone)]
pub struct CachedBatch<B> {
    inner: B,
    cache: Arc<LruCacheWrapper<Vec<u8>, Vec<u8>>>,
}

impl<B> WriteBatch for CachedBatch<B>
where
    B: WriteBatch + 'static,
{
    fn put(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.inner.put_serialized(key, value)
    }
    
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.inner.put_serialized(key, value)
    }
    
    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.inner.delete(key)
    }
    
    fn clear(&mut self) {
        self.inner.clear()
    }
    
    fn as_any(&self) -> &dyn Any {
        self.inner.as_any()
    }
    
    fn commit(self: Box<Self>) -> Result<()> {
        // Commit the inner batch directly
        self.inner.commit()
    }
    
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.inner.put_serialized(key, value)
    }
}

impl<S> WriteBatchExt for CachedStore<S>
where
    S: Storage + WriteBatchExt + 'static,
    S::Batch: WriteBatch + 'static,
    <S as Storage>::Batch: 'static,
{
    type Batch = CachedBatch<'static, <S as Storage>::Batch>;
    
    fn batch(&self) -> Self::Batch {
        CachedBatch {
            inner: <S as WriteBatchExt>::batch(&self.inner),
            cache: self.cache.clone(),
        }
    }
    
    fn commit(batch: Box<dyn WriteBatch>) -> Result<()> {
        // Downcast to our concrete type if possible
        if let Some(batch) = batch.as_any().downcast_ref::<CachedBatch<S::Batch>>() {
            // Extract inner batch and commit it
            let inner = batch.inner.clone();
            <S as WriteBatchExt>::commit(Box::new(inner))
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
        
        // Test put and get with String
        let value1 = TestValue { data: "value1".to_string() };
        cache.put(b"key1", &value1)?;
        assert_eq!(cache.get::<TestValue>(b"key1")?, Some(value1.clone()));
        
        // Test cache hit
        assert_eq!(cache.get::<TestValue>(b"key1")?, Some(value1));
        
        // Test delete
        cache.delete(b"key1")?;
        assert!(cache.get::<TestValue>(b"key1")?.is_none());
        
        // Test cache invalidation
        let value2 = TestValue { data: "value2".to_string() };
        cache.put(b"key2", &value2)?;
        cache.invalidate(b"key2")?;
        assert_eq!(cache.get::<TestValue>(b"key2")?, Some(value2)); // Should refill cache
        
        // Test batch operations
        let mut batch = cache.batch();
        let value3 = TestValue { data: "value3".to_string() };
        let value4 = TestValue { data: "value4".to_string() };
        
        batch.put(b"key3", &value3)?;
        batch.put(b"key4", &value4)?;
        batch.delete(b"key2")?;
        
        // Commit the batch
        let batch = Box::new(batch);
        batch.commit()?;
        
        // Verify batch operations
        assert_eq!(cache.get::<TestValue>(b"key3")?, Some(value3));
        assert_eq!(cache.get::<TestValue>(b"key4")?, Some(value4));
        assert!(cache.get::<TestValue>(b"key2")?.is_none());
        
        // Test clear cache
        cache.clear_cache()?;
        
        Ok(())
    }
}
