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
pub trait WriteBatch: std::fmt::Debug + Send + 'static {
    /// Add a key-value pair to the batch
    fn put(&mut self, key: &[u8], value: &[u8]) -> Result<()>;
    
    /// Add a delete operation to the batch
    fn delete(&mut self, key: &[u8]) -> Result<()>;
    
    /// Add a serialized key-value pair to the batch
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()>;
    
    /// Clear all operations in the batch
    fn clear(&mut self) {}
    
    /// Get a reference to the batch as Any for downcasting
    fn as_any(&self) -> &dyn std::any::Any {
        unimplemented!("as_any must be implemented for WriteBatch")
    }
    
    /// Commit the batch
    fn commit(self: Box<Self>) -> Result<()>;
}

/// Extension trait for batch operations
pub trait WriteBatchExt: Send + 'static {
    /// The batch type for this storage backend
    type Batch: WriteBatch + 'static;
    
    /// Create a new batch
    fn batch(&self) -> Self::Batch;
    
    /// Commit a boxed batch
    fn commit(batch: Box<dyn WriteBatch>) -> Result<()>;
    
    /// Put a serializable value into the batch
    fn put_serialized<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = serialize(value)?;
        let mut batch = self.batch();
        batch.put_serialized(key, &bytes)?;
        Box::new(batch).commit()
    }
    
    /// Delete a key from the batch
    fn delete_serialized(&self, key: &[u8]) -> Result<()> {
        let mut batch = self.batch();
        batch.delete(key)?;
        Box::new(batch).commit()
    }
}

// Note: Specific implementations of WriteBatchExt are provided by each storage backend
// to avoid conflicts with the blanket implementation

/// Serialize a value to JSON bytes
pub(crate) fn serialize<T: Serialize>(value: &T) -> Result<Vec<u8>> {
    serde_json::to_vec(value).map_err(Into::into)
}

/// Deserialize a value from JSON bytes
pub(crate) fn deserialize<T: DeserializeOwned>(bytes: &[u8]) -> Result<T> {
    serde_json::from_slice(bytes).map_err(Into::into)
}
