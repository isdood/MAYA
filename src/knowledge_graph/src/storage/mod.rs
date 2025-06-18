//! Storage abstraction layer for the knowledge graph.
//!
//! This module defines the [`Storage`] trait and related types that provide a
//! key-value storage abstraction for the knowledge graph. It includes a default
//! implementation using [Sled](https://github.com/spacejam/sled), but can be
//! implemented for other storage backends as needed.
//!
//! # Features
//! - Generic key-value storage interface
//! - Support for transactions and batch operations
//! - JSON serialization/deserialization
//! - Pluggable storage backends
//! - Thread-safe by design
//!
//! # Examples
//!
//! ## Using the default Sled backend
//!
//! ```no_run
//! use maya_knowledge_graph::prelude::*;
//! use maya_knowledge_graph::storage::SledStore;
//! use tempfile::tempdir;
//!
//! # fn main() -> Result<(), Box<dyn std::error::Error>> {
//! // Create a temporary directory for the database
//! let temp_dir = tempdir()?;
//!
//! // Open or create a new Sled-backed storage
//! let store = SledStore::open(temp_dir.path())?;
//!
//! // Store and retrieve a value
//! store.put_serialized(b"key", &"value")?;
//! let value: Option<String> = store.get(b"key")?;
//! assert_eq!(value, Some("value".to_string()));
//! # Ok(())
//! # }
//! ```
//!
//! ## Implementing a custom storage backend
//!
//! ```no_run
//! use maya_knowledge_graph::storage::{Storage, WriteBatch};
//! use std::path::Path;
//! use std::collections::HashMap;
//! use std::sync::{Arc, RwLock};
//! use maya_knowledge_graph::error::Result;
//!
//! #[derive(Debug, Default)]
//! struct MemoryStore {
//!     data: Arc<RwLock<HashMap<Vec<u8>, Vec<u8>>>>,
//! }
//!
//! #[derive(Debug, Default)]
//! struct MemoryBatch {
//!     ops: Vec<BatchOp>,
//! }
//!
//! #[derive(Debug)]
//! enum BatchOp {
//!     Put(Vec<u8>, Vec<u8>),
//!     Delete(Vec<u8>),
//! }
//!
//! impl Storage for MemoryStore {
//!     type Batch = MemoryBatch;
//!
//!     fn open<P: AsRef<Path>>(_path: P) -> Result<Self> {
//!         Ok(Self::default())
//!     }
//!
//!     // Implement required methods...
//!     # fn get<T: serde::de::DeserializeOwned>(&self, _key: &[u8]) -> Result<Option<T>> { todo!() }
//!     # fn put<T: serde::Serialize>(&self, _key: &[u8], _value: &T) -> Result<()> { todo!() }
//!     # fn delete(&self, _key: &[u8]) -> Result<()> { todo!() }
//!     # fn exists(&self, _key: &[u8]) -> Result<bool> { todo!() }
//!     # fn iter_prefix(&self, _prefix: &[u8]) -> std::boxed::Box<dyn Iterator<Item = (std::vec::Vec<u8>, std::vec::Vec<u8>)> + '_> { todo!() }
//!     # fn batch(&self) -> Self::Batch { todo!() }
//! }
//! ```

// Make modules public for benchmarks
pub mod sled_store;
// Temporarily disable RocksDB for benchmarking
// pub mod rocksdb_store;
mod cached_store;

// Re-export public types
pub use sled_store::SledStore;
pub use cached_store::{CachedStore, CachedBatch, CacheConfig, CacheMetrics};

use serde::{Serialize, de::DeserializeOwned};
use std::path::Path;
use crate::error::Result;

/// Trait defining the storage operations for the knowledge graph
pub trait Storage: Send + Sync + 'static {
    /// The batch type for this storage backend
    type Batch<'a>: WriteBatch + 'static where Self: 'a;
    
    /// Create or open a database at the given path
    fn open<P: AsRef<Path>>(path: P) -> Result<Self> where Self: Sized;
    
    /// Get a value by key
    fn get<T: DeserializeOwned + Serialize>(&self, key: &[u8]) -> Result<Option<T>>;
    
    /// Insert or update a key-value pair
    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()>;
    
    /// Delete a key-value pair
    fn delete(&self, key: &[u8]) -> Result<()>;
    
    /// Check if a key exists
    fn exists(&self, key: &[u8]) -> Result<bool>;
    
    /// Get an iterator over all key-value pairs with a given prefix
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a>;
    
    /// Create a batch of operations
    fn batch(&self) -> Self::Batch<'_>;
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
    
    /// Commit the batch to storage
    fn commit(self) -> Result<()>;
}

/// Extension trait for batch operations
pub trait WriteBatchExt: Storage {
    /// The batch type for this storage backend
    type BatchType<'a>: WriteBatch + 'static where Self: 'a;
    
    /// Create a new batch
    fn create_batch(&self) -> Self::BatchType<'_>;
    
    /// Commit a boxed batch
    fn commit(batch: Box<dyn WriteBatch>) -> Result<()>;
    
    /// Put a serializable value into the batch
    fn put_serialized<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = serialize(value)?;
        let mut batch = self.create_batch();
        batch.put_serialized(key, &bytes)?;
        Box::new(batch).commit()
    }
    
    /// Delete a key from the batch
    fn delete_serialized(&self, key: &[u8]) -> Result<()> {
        let mut batch = self.create_batch();
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
