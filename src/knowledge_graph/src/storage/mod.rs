//! Storage module for the knowledge graph
//! 
//! Provides a key-value storage abstraction using Sled with JSON serialization.

mod sled_store;

pub use sled_store::SledStore;

use serde::{Serialize, de::DeserializeOwned};
use std::path::Path;
use crate::error::Result;

/// Trait defining the storage operations for the knowledge graph
pub trait Storage: Send + Sync + 'static {
    /// The batch type for this storage backend
    type Batch: WriteBatch + 'static;
    
    /// Create or open a database at the given path
    fn open<P: AsRef<Path>>(path: P) -> Result<Self> where Self: Sized;
    
    /// Get a value by key
    fn get<T: DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>>;
    
    /// Insert or update a key-value pair
    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()>;
    
    /// Delete a key-value pair
    fn delete(&self, key: &[u8]) -> Result<()>;
    
    /// Check if a key exists
    fn exists(&self, key: &[u8]) -> Result<bool>;
    
    /// Get an iterator over all key-value pairs with a given prefix
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a>;
    
    /// Create a batch of operations
    fn batch(&self) -> Self::Batch;
}

/// Trait for batch operations
pub trait WriteBatch: Send + 'static {
    /// Add a put operation to the batch with pre-serialized value
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()>;
    
    /// Add a delete operation to the batch
    fn delete(&mut self, key: &[u8]) -> Result<()>;
    
    /// Commit the batch
    fn commit(self: Box<Self>) -> Result<()>;
}

/// Extension trait for batch operations
pub trait WriteBatchExt: Send + 'static {
    /// The batch type for this storage backend
    type Batch: WriteBatch;
    
    /// Create a new batch
    fn batch(&self) -> Self::Batch;
    
    /// Put a serializable value into the batch
    fn put_serialized<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = serialize(value)?;
        let mut batch = self.batch();
        batch.put_serialized(key, &bytes)?;
        batch.commit()
    }
    
    /// Delete a key from the batch
    fn delete_serialized(&self, key: &[u8]) -> Result<()> {
        let mut batch = self.batch();
        batch.delete(key)?;
        batch.commit()
    }
}

// Implement WriteBatchExt for all types that implement WriteBatch
impl<T: WriteBatch + ?Sized> WriteBatchExt for T {
    type Batch = T;
    fn batch(&self) -> Self::Batch {
        self
    }
}

/// Serialize a value to JSON bytes
pub(crate) fn serialize<T: Serialize>(value: &T) -> Result<Vec<u8>> {
    serde_json::to_vec(value).map_err(Into::into)
}

/// Deserialize a value from JSON bytes
pub(crate) fn deserialize<T: DeserializeOwned>(bytes: &[u8]) -> Result<T> {
    serde_json::from_slice(bytes).map_err(Into::into)
}
