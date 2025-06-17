//! Error types for the knowledge graph

use std::error::Error as StdError;
use std::fmt;
use serde_json::Error as JsonError;

/// Error type for the knowledge graph
#[derive(Debug)]
pub enum KnowledgeGraphError {
    /// JSON serialization/deserialization error
    SerializationError(JsonError),
    
    /// I/O error
    IoError(std::io::Error),
    
    /// Sled database error
    SledError(sled::Error),
    
    /// Transaction error
    TransactionError(String),
    
    /// Node not found error
    NodeNotFound(String),
    
    /// Edge not found error
    EdgeNotFound(String),
    
    /// Duplicate node error
    DuplicateNode(String),
    
    /// Duplicate edge error
    DuplicateEdge(String),
    
    /// Other error
    Other(String),
}

impl fmt::Display for KnowledgeGraphError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::SerializationError(e) => write!(f, "Serialization error: {}", e),
            Self::IoError(e) => write!(f, "I/O error: {}", e),
            Self::SledError(e) => write!(f, "Database error: {}", e),
            Self::TransactionError(msg) => write!(f, "Transaction error: {}", msg),
            Self::NodeNotFound(msg) => write!(f, "Node not found: {}", msg),
            Self::EdgeNotFound(msg) => write!(f, "Edge not found: {}", msg),
            Self::DuplicateNode(msg) => write!(f, "Duplicate node: {}", msg),
            Self::DuplicateEdge(msg) => write!(f, "Duplicate edge: {}", msg),
            Self::Other(msg) => write!(f, "Error: {}", msg),
        }
    }
}

impl StdError for KnowledgeGraphError {
    fn source(&self) -> Option<&(dyn StdError + 'static)> {
        match self {
            Self::SerializationError(e) => Some(e),
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
        Self::IoError(err)
    }
}

impl From<sled::Error> for KnowledgeGraphError {
    fn from(err: sled::Error) -> Self {
        Self::SledError(err)
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

impl From<&str> for KnowledgeGraphError {
    fn from(err: &str) -> Self {
        Self::Other(err.to_string())
    }
}

/// Type alias for Result<T, KnowledgeGraphError>
pub type Result<T> = std::result::Result<T, KnowledgeGraphError>;

// Helper for formatting errors
pub(crate) fn format_error<T: std::error::Error>(error: T) -> KnowledgeGraphError {
    KnowledgeGraphError::Other(error.to_string())
}

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
