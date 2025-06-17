//! Storage module for the knowledge graph
//! 
//! Provides a key-value storage abstraction using RocksDB with JSON serialization.

mod rocksdb_store;

pub use rocksdb_store::RocksDBStore;

use serde::{Serialize, de::DeserializeOwned};
use crate::error::Result;

/// Trait defining the storage operations for the knowledge graph
pub trait Storage: Send + Sync + 'static {
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
    fn batch(&self) -> Box<dyn WriteBatch>;
}

/// Trait for batch operations
pub trait WriteBatch {
    /// Add a put operation to the batch
    fn put<T: Serialize>(&mut self, key: &[u8], value: &T) -> Result<()>;
    
    /// Add a delete operation to the batch
    fn delete(&mut self, key: &[u8]) -> Result<()>;
    
    /// Commit the batch
    fn commit(self: Box<Self>) -> Result<()>;
}

/// Serialize a value to JSON bytes
fn serialize<T: Serialize>(value: &T) -> Result<Vec<u8>> {
    serde_json::to_vec(value).map_err(Into::into)
}

/// Deserialize a value from JSON bytes
fn deserialize<T: DeserializeOwned>(bytes: &[u8]) -> Result<T> {
    serde_json::from_slice(bytes).map_err(Into::into)
}
