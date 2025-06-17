//! Data models for the knowledge graph

mod node;
mod edge;
mod property;

// Re-exports
pub use node::Node;
pub use edge::Edge;
pub use property::Property;

use serde::{Serialize, Deserialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

/// Common trait for all graph elements
pub trait GraphElement: Serialize + for<'de> Deserialize<'de> + std::fmt::Debug + Send + Sync {
    /// Get the unique identifier of the element
    fn id(&self) -> Uuid;
    
    /// Get the timestamp when the element was created
    fn created_at(&self) -> DateTime<Utc>;
}

/// Type alias for property values
pub type PropertyValue = serde_json::Value;
