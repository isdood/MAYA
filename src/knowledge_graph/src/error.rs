//! Error types for the knowledge graph

use std::fmt;
use std::error::Error as StdError;
use serde_json::Error as JsonError;
use thiserror::Error;

/// Error type for the knowledge graph
#[derive(Debug, Error)]
pub enum KnowledgeGraphError {
    /// JSON serialization/deserialization error
    #[error("JSON error: {0}")]
    JsonError(#[from] JsonError),
    
    /// I/O error
    #[error("I/O error: {0}")]
    IoError(#[from] std::io::Error),
    
    /// Sled database error
    #[error("Database error: {0}")]
    SledError(#[from] sled::Error),
    
    /// Transaction error
    #[error("Transaction error: {0}")]
    TransactionError(String),
    
    /// Other error
    #[error("Error: {0}")]
    Other(String),
}

impl From<sled::transaction::TransactionError> for KnowledgeGraphError {
    fn from(err: sled::transaction::TransactionError) -> Self {
        KnowledgeGraphError::TransactionError(format!("{:?}", err))
    }
}

impl fmt::Display for KnowledgeGraphError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::JsonError(e) => write!(f, "JSON error: {}", e),
            Self::IoError(e) => write!(f, "I/O error: {}", e),
            Self::SledError(e) => write!(f, "Database error: {}", e),
            Self::TransactionError(msg) => write!(f, "Transaction error: {}", msg),
            Self::Other(msg) => write!(f, "Error: {}", msg),
            _ => write!(f, "Unknown error"),
        }
    }
}

impl StdError for KnowledgeGraphError {
    fn source(&self) -> Option<&(dyn StdError + 'static)> {
        match self {
            Self::JsonError(e) => Some(e),
            Self::IoError(e) => Some(e),
            Self::SledError(e) => Some(e),
            Self::Other(_) => None,
        }
    }
}

impl From<JsonError> for KnowledgeGraphError {
    fn from(err: JsonError) -> Self {
        Self::JsonError(err)
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
