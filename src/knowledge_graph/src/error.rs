//! Error types for the knowledge graph

use std::error::Error as StdError;
use std::fmt;
use serde_json::Error as JsonError;
use bincode::Error as BincodeError;
use std::sync::Arc;

/// Error type for the knowledge graph
#[derive(Debug)]
pub enum KnowledgeGraphError {
    /// I/O error
    IoError(Arc<std::io::Error>),
    
    /// Storage error
    StorageError(String),
    
    /// JSON serialization/deserialization error
    SerializationError(JsonError),
    
    /// Bincode serialization/deserialization error
    BincodeError(String),
    
    /// Node not found
    NodeNotFound(String),
    
    /// Edge not found
    EdgeNotFound(String),
    
    /// Duplicate node
    DuplicateNode(String),
    
    /// Duplicate edge
    DuplicateEdge(String),
    
    /// Invalid operation
    InvalidOperation(String),
    
    /// Query error
    QueryError(String),
    
    /// Transaction error
    TransactionError(String),
    
    /// Sled database error
    SledError(sled::Error),
    
    /// Other error
    Other(String),
}

impl fmt::Display for KnowledgeGraphError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::IoError(e) => write!(f, "I/O error: {}", e),
            Self::StorageError(msg) => write!(f, "Storage error: {}", msg),
            KnowledgeGraphError::SerializationError(ref e) => write!(f, "JSON serialization error: {}", e),
            KnowledgeGraphError::BincodeError(ref e) => write!(f, "Bincode error: {}", e),
            Self::NodeNotFound(id) => write!(f, "Node not found: {}", id),
            Self::EdgeNotFound(id) => write!(f, "Edge not found: {}", id),
            Self::DuplicateNode(id) => write!(f, "Duplicate node: {}", id),
            Self::DuplicateEdge(id) => write!(f, "Duplicate edge: {}", id),
            Self::InvalidOperation(msg) => write!(f, "Invalid operation: {}", msg),
            Self::QueryError(msg) => write!(f, "Query error: {}", msg),
            Self::TransactionError(msg) => write!(f, "Transaction error: {}", msg),
            Self::SledError(e) => write!(f, "Sled error: {}", e),
            Self::Other(msg) => write!(f, "Error: {}", msg),
        }
    }
}

impl StdError for KnowledgeGraphError {
    fn source(&self) -> Option<&(dyn StdError + 'static)> {
        match self {
            KnowledgeGraphError::SerializationError(ref e) => Some(e),
            KnowledgeGraphError::BincodeError(_) => None,
            Self::IoError(e) => Some(e),
            Self::SledError(e) => Some(e),
            _ => None,
        }
    }
}

impl From<JsonError> for KnowledgeGraphError {
    fn from(err: JsonError) -> Self {
        Self::SerializationError(err)
    }
}

impl From<std::io::Error> for KnowledgeGraphError {
    fn from(err: std::io::Error) -> Self {
        Self::IoError(Arc::new(err))
    }
}

impl From<sled::Error> for KnowledgeGraphError {
    fn from(err: sled::Error) -> Self {
        Self::StorageError(err.to_string())
    }
}

impl From<sled::transaction::TransactionError> for KnowledgeGraphError {
    fn from(err: sled::transaction::TransactionError) -> Self {
        Self::TransactionError(format!("{:?}", err))
    }
}

impl From<String> for KnowledgeGraphError {
    fn from(err: String) -> Self {
        Self::Other(err)
    }
}

impl From<BincodeError> for KnowledgeGraphError {
    fn from(err: BincodeError) -> Self {
        KnowledgeGraphError::BincodeError(err.to_string())
    }
}

impl From<&str> for KnowledgeGraphError {
    fn from(err: &str) -> Self {
        Self::Other(err.to_string())
    }
}

/// Type alias for Result<T, KnowledgeGraphError>
pub type Result<T> = std::result::Result<T, KnowledgeGraphError>;

#[cfg(test)]
mod tests {
    use super::*;
    use std::io;

    #[test]
    fn test_error_conversion() {
        // Test IO error conversion
        let io_err = io::Error::new(io::ErrorKind::NotFound, "file not found");
        let kg_err: KnowledgeGraphError = io_err.into();
        assert!(matches!(kg_err, KnowledgeGraphError::IoError(_)));
        
        // Test JSON error conversion
        let json_err = serde_json::from_str::<serde_json::Value>("{invalid}").unwrap_err();
        let kg_err: KnowledgeGraphError = json_err.into();
        assert!(matches!(kg_err, KnowledgeGraphError::SerializationError(_)));
    }
}
