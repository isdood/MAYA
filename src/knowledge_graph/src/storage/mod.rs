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
pub mod cached_store;
pub mod hybrid_store;
pub mod prefetch;

// Re-export prefetch types
pub use prefetch::{PrefetchConfig, PrefetchExt, PrefetchingIterator};

// Re-export public types
pub use sled_store::SledStore;
pub use cached_store::CachedStore;
pub use hybrid_store::{HybridStore, HybridConfig};

use std::collections::HashMap;
use std::sync::{Arc, RwLock};

use bincode;
use serde::de::DeserializeOwned;
use serde::Serialize;

use crate::error::KnowledgeGraphError;

/// Type alias for Result<T, KnowledgeGraphError>
pub type Result<T> = std::result::Result<T, KnowledgeGraphError>;

// Bincode error handling is handled by the From<BincodeError> implementation in error.rs

/// Trait for key-value storage operations
/// A storage backend that supports prefetching
#[async_trait::async_trait]
pub trait Storage: Send + Sync + 'static {
    /// The batch type for this storage backend
    type Batch<'a>: WriteBatch + 'a where Self: 'a;
    
    /// Get a value by key
    fn get<T: DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>>;
    
    /// Put a key-value pair
    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()>;
    
    /// Delete a key
    fn delete(&self, key: &[u8]) -> Result<()>;
    
    /// Check if a key exists
    fn exists(&self, key: &[u8]) -> Result<bool>;
    
    /// Get a raw byte value by key
    fn get_raw(&self, key: &[u8]) -> Result<Option<Vec<u8>>>;
    
    /// Put a raw byte value by key
    fn put_raw(&self, key: &[u8], value: &[u8]) -> Result<()>;
    
    /// Iterate over key-value pairs with a prefix
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a>;
    
    /// Create a new batch
    fn create_batch(&self) -> Self::Batch<'_>;
}

/// Trait for generic batch operations
pub trait GenericWriteBatch {
    /// Add a put operation to the batch
    fn put<T: Serialize>(&mut self, key: &[u8], value: &T) -> Result<()>;
    
    /// Delete a key from the batch
    fn delete(&mut self, key: &[u8]) -> Result<()>;
}

/// Trait for batch operations
pub trait WriteBatch: std::fmt::Debug + Send + 'static {
    /// Add a put operation with pre-serialized value to the batch
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()>;
    
    /// Add a delete operation with pre-serialized key to the batch
    fn delete_serialized(&mut self, key: &[u8]) -> Result<()>;
    
    /// Clear all operations in the batch
    fn clear(&mut self);
    
    /// Commit the batch
    fn commit(self) -> Result<()>;
    
    /// Get a reference to the underlying batch as `Any`
    fn as_any(&self) -> &dyn std::any::Any;
    
    /// Get a mutable reference to the underlying batch as `Any`
    fn as_mut_any(&mut self) -> &mut dyn std::any::Any;
}

/// Blanket implementation of GenericWriteBatch for any type that implements WriteBatch
impl<T: WriteBatch> GenericWriteBatch for T {
    fn put<S: Serialize>(&mut self, key: &[u8], value: &S) -> Result<()> {
        let bytes = bincode::serialize(value).map_err(KnowledgeGraphError::from)?;
        self.put_serialized(key, &bytes)
    }
    
    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.delete_serialized(key)
    }
}

/// Extension trait for batch operations
pub trait WriteBatchExt: Storage {
    /// Put a serializable value into the batch
    fn put_serialized<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = serialize(value)?;
        let mut batch = self.create_batch();
        batch.put_serialized(key, &bytes)?;
        batch.commit()
    }
    
    /// Delete a key from the batch
    fn delete_serialized(&self, key: &[u8]) -> Result<()> {
        let mut batch = self.create_batch();
        batch.delete_serialized(key)?;
        batch.commit()
    }
}

/// Serialize a value to bytes using bincode
pub fn serialize<T: Serialize>(value: &T) -> Result<Vec<u8>> {
    bincode::serialize(value).map_err(KnowledgeGraphError::from)
}

/// Deserialize a value from bytes using bincode
pub fn deserialize<T: DeserializeOwned>(bytes: &[u8]) -> Result<T> {
    bincode::deserialize(bytes).map_err(KnowledgeGraphError::from)
}

/// Deserialize a value from JSON bytes
pub fn deserialize_json<T: DeserializeOwned>(bytes: &[u8]) -> Result<T> {
    serde_json::from_slice(bytes).map_err(KnowledgeGraphError::from)
}
