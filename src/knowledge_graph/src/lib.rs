//! # Maya Knowledge Graph
//! 
//! A high-performance, embedded knowledge graph for MAYA's intelligent coding assistant.
//! 
//! ## Features
//! - High-performance embedded storage using Sled
//! - Type-safe Rust API
//! - ACID-compliant transactions
//! - Query builder for complex graph traversals
//! - Efficient indexing and querying

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
        let graph = KnowledgeGraph::with_storage(store);

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
