
//! # Maya Knowledge Graph
//! 
//! A high-performance, embedded knowledge graph for MAYA's intelligent coding assistant,
//! providing a flexible and efficient way to store, query, and analyze interconnected data.
//!
//! ## Features
//! - **High-performance storage**: Built on Sled for embedded key-value storage
//! - **Type-safe Rust API**: Compile-time checked operations and queries
//! - **ACID transactions**: Atomic, consistent, isolated, and durable operations
//! - **Query builder**: Construct complex graph traversals with a fluent API
//! - **Efficient indexing**: Fast lookups and traversals
//! - **Thread-safe**: Designed for concurrent access
//! - **Extensible storage**: Pluggable storage backends
//! - **JSON serialization**: Easy integration with existing systems
//!
//! ## Quick Start
//!
//! ```no_run
//! use maya_knowledge_graph::prelude::*;
//! use uuid::Uuid;
//! use serde_json::json;
//!
//! fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     // Create a temporary directory for the database
//!     let temp_dir = tempfile::tempdir()?;
//!     
//!     // Open or create a new knowledge graph
//!     let graph = KnowledgeGraph::open(temp_dir.path())?;
//!     
//!     // Create and add a node
//!     let node_id = Uuid::new_v4();
//!     let node = Node::new("Person")
//!         .with_id(node_id)
//!         .with_property("name", "Alice")
//!         .with_property("age", 30);
//!     
//!     graph.add_node(node)?;
//!     
//!     // Retrieve the node
//!     let retrieved = graph.get_node(node_id)?.expect("Node not found");
//!     println!("Retrieved node: {:?}", retrieved);
//!     
//!     Ok(())
//! }
//! ```
//!
//! ## Architecture
//!
//! The knowledge graph consists of:
//! - **Nodes**: Represent entities with a type and properties
//! - **Edges**: Represent relationships between nodes with a type and properties
//! - **Properties**: Key-value pairs attached to nodes and edges
//! - **Indexes**: For efficient querying of nodes and edges
//! - **Storage**: Pluggable storage backends (Sled by default)
//!
//! ## Error Handling
//!
//! All operations return a `Result<T, KnowledgeGraphError>` where `T` is the success type.
//! Common errors include:
//! - `NodeNotFound`: Referenced node does not exist
//! - `DuplicateNode`: Attempted to add a node with an existing ID
//! - `SerializationError`: Failed to serialize/deserialize data
//! - `StorageError`: Underlying storage error
//!
//! ## Concurrency
//!
//! The knowledge graph is designed for concurrent access. Multiple readers and a single writer
//! can operate on the graph simultaneously. For batch operations, use transactions to ensure
//! atomicity.
//!
//! ## Performance Considerations
//! - Use transactions for bulk operations
//! - Prefer batch operations when possible
//! - Consider using indexes for frequently queried properties
//! - Use the query builder for complex traversals
//!
//! ## Examples
//!
//! See the `examples/` directory for complete usage examples.
//!
//! ## License
//!
//! This project is proprietary and confidential. Unauthorized use is prohibited.

#![warn(missing_docs)]
#![warn(rustdoc::missing_crate_level_docs)]
#![cfg_attr(test, allow(dead_code))] // Allow dead code in tests

pub mod cache;
pub mod error;
pub mod graph;
pub mod models;
pub mod query;
pub mod storage;

// Re-exports
pub use error::{Result, KnowledgeGraphError};
pub use graph::KnowledgeGraph;
pub use models::*;
pub use query::{QueryBuilder, QueryResult};
pub use storage::SledStore;

/// Prelude module for convenient imports
pub mod prelude {
    //! A 'prelude' for users of the `maya_knowledge_graph` crate.
    //!
    //! This prelude is similar to the standard library's prelude in that you'll
    //! almost always want to import its entire contents, but unlike the standard
    //! library's prelude you'll have to do so manually:
    //!
    //! ```
    //! use maya_knowledge_graph::prelude::*;
    //! ```
    
    pub use crate::{
        KnowledgeGraph,
        QueryBuilder,
        QueryResult,
        SledStore,
        Node,
        Edge,
        Property,
        Result,
        KnowledgeGraphError,
    };
}

// Re-export serialization functions for internal use
// Re-export storage types

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile;

    #[test]
    fn test_basic_graph_operations() -> Result<()> {
        let dir = tempfile::tempdir()?;
        let store = SledStore::open(dir.path())?;
        let graph = KnowledgeGraph::new(store);

        // Create and add a node
        let mut node = Node::new("TestNode");
        node.properties.push(Property::new("name", serde_json::json!("Test Node")));
        graph.add_node(node.clone())?;

        // Retrieve the node
        let retrieved = graph.get_node(node.id)?.unwrap();
        assert_eq!(retrieved.id, node.id);
        assert_eq!(retrieved.label, "TestNode");
        assert_eq!(retrieved.properties[0].key, "name");
        assert_eq!(retrieved.properties[0].value, serde_json::json!("Test Node"));

        Ok(())
    }
}
