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
pub use hybrid_store::{HybridStore, HybridConfig};

// Re-export public types
pub use sled_store::SledStore;
pub use cached_store::CachedStore;
pub use hybrid_store::{HybridStore, HybridConfig, HybridBatch};

use serde::{Serialize, de::DeserializeOwned};
use thiserror::Error;
use std::fmt;

impl From<sled::Error> for KnowledgeGraphError {
    fn from(err: sled::Error) -> Self {
        KnowledgeGraphError::StorageError(err.to_string())
    }
}

impl From<std::io::Error> for KnowledgeGraphError {
    fn from(err: std::io::Error) -> Self {
        KnowledgeGraphError::StorageError(err.to_string())
    }
}

impl From<bincode::Error> for KnowledgeGraphError {
    fn from(err: bincode::Error) -> Self {
        KnowledgeGraphError::BincodeError(err.to_string())
    }
}

impl From<serde_json::Error> for KnowledgeGraphError {
    fn from(err: serde_json::Error) -> Self {
        KnowledgeGraphError::JsonError(err)
    }
}

use std::fmt;

#[derive(Debug, thiserror::Error)]
pub enum KnowledgeGraphError {
    #[error("Storage error: {0}")]
    StorageError(String),
    
    #[error("I/O error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),
    
    #[error("Sled error: {0}")]
    SledError(#[from] sled::Error),
    
    #[error("Serialization error: {0}")]
    SerializationError(String),
    
    #[error("Bincode error: {0}")]
    BincodeError(String),
    
    #[error("Key not found")]
    KeyNotFound,
    
    #[error("Invalid argument: {0}")]
    InvalidArgument(String),
}

impl From<Box<bincode::ErrorKind>> for KnowledgeGraphError {
    fn from(err: Box<bincode::ErrorKind>) -> Self {
        KnowledgeGraphError::BincodeError(err.to_string())
    }
}



impl From<error::KnowledgeGraphError> for KnowledgeGraphError {
    fn from(err: error::KnowledgeGraphError) -> Self {
        match err {
            error::KnowledgeGraphError::StorageError(s) => KnowledgeGraphError::StorageError(s),
            error::KnowledgeGraphError::IoError(e) => KnowledgeGraphError::IoError(e),
            error::KnowledgeGraphError::JsonError(e) => KnowledgeGraphError::JsonError(e),
            error::KnowledgeGraphError::SledError(e) => KnowledgeGraphError::SledError(e),
            error::KnowledgeGraphError::SerializationError(s) => KnowledgeGraphError::SerializationError(s),
            error::KnowledgeGraphError::BincodeError(s) => KnowledgeGraphError::BincodeError(s),
            error::KnowledgeGraphError::KeyNotFound => KnowledgeGraphError::KeyNotFound,
            error::KnowledgeGraphError::InvalidArgument(s) => KnowledgeGraphError::InvalidArgument(s),
        }
    }
}

pub type Result<T> = std::result::Result<T, KnowledgeGraphError>;

/// Trait for key-value storage operations
pub trait Storage: Send + Sync + 'static {
    /// Get a value by key
    fn get<T: DeserializeOwned + Serialize>(&self, key: &[u8]) -> Result<Option<T>>;
    
    /// Insert or update a value
    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()>;
    
    /// Delete a value by key
    fn delete(&self, key: &[u8]) -> Result<()>;
    
    /// Check if a key exists in the storage
    fn exists(&self, key: &[u8]) -> Result<bool>;
    
    /// Get raw bytes from storage without deserialization
    fn get_raw(&self, key: &[u8]) -> Result<Option<Vec<u8>>>;
}

/// Extension trait for storage backends that support batch operations
pub trait WriteBatchExt: Storage {
    type Batch: WriteBatch;
    
    /// Create a new write batch
    fn batch(&self) -> Self::Batch;
}

/// Trait for batch operations
pub trait WriteBatch: std::fmt::Debug + Send + 'static {
    /// Add a put operation to the batch
    fn put<T: Serialize>(&mut self, key: &[u8], value: &T) -> Result<()>;
    
    /// Add a put operation with pre-serialized value to the batch
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()>;
    
    /// Add a delete operation to the batch
    fn delete(&mut self, key: &[u8]) -> Result<()>;
    
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

/// Extension trait for batch operations
pub trait WriteBatchExt: Storage {
    /// The batch type for this storage backend
    type BatchType<'a>: WriteBatch + 'static where Self: 'a;
    
    /// Create a new batch
    fn create_batch(&self) -> Self::BatchType<'_>;
    
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
    }}

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
