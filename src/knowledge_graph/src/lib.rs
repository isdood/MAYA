//! # Maya Knowledge Graph
//! 
//! A high-performance, embedded knowledge graph for MAYA's intelligent coding assistant.
//! 
//! ## Features
//! - High-performance embedded storage using RocksDB
//! - Type-safe Rust API
//! - ACID-compliant transactions
//! - Query builder for complex graph traversals
//! - Efficient indexing and querying

#![warn(missing_docs)]
#![warn(rustdoc::missing_crate_level_docs)]
#![cfg_attr(test, allow(dead_code))] // Allow dead code in tests

pub mod error;
pub mod graph;
pub mod models;
pub mod storage;
pub mod query;

// Re-exports
pub use error::{Result, KnowledgeGraphError};
pub use graph::KnowledgeGraph;
pub use models::*;
pub use query::QueryExt;
pub use storage::SledStore as Storage;

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
        QueryExt,
        Storage,
        Node,
        Edge,
        Property,
    };
}

// Re-export serialization functions for internal use
pub(crate) use storage::{serialize, deserialize};

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_basic_graph_operations() -> Result<()> {
        let dir = tempdir()?;
        let graph = KnowledgeGraph::open(dir.path())?;
        
        // Test node creation
        let node = Node::new("TestNode")
            .with_property("test", "value".into());
            
        graph.add_node(&node)?;
        
        // Test retrieval
        let retrieved = graph.get_node(node.id)?
            .ok_or_else(|| KnowledgeGraphError::NodeNotFound(node.id.to_string()))?;
            
        assert_eq!(node.id, retrieved.id);
        assert_eq!(node.label, retrieved.label);
        assert_eq!(node.properties, retrieved.properties);
        
        Ok(())
    }
}
