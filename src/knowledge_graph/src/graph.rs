//! Main knowledge graph implementation

use std::path::Path;
use std::sync::Arc;
use uuid::Uuid;
use serde::{Serialize, de::DeserializeOwned};
use log::{info, error};

use crate::{
    error::{Result, KnowledgeGraphError},
    models::{Node, Edge, Property},
    storage::{Storage, RocksDBStore},
};

/// Main knowledge graph structure
pub struct KnowledgeGraph<S: Storage> {
    storage: S,
}

impl KnowledgeGraph<RocksDBStore> {
    /// Create or open a knowledge graph at the given path
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let storage = RocksDBStore::open(path)?;
        info!("Opened knowledge graph database");
        Ok(Self { storage })
    }
}

impl<S: Storage> KnowledgeGraph<S> {
    /// Create a new knowledge graph with a custom storage backend
    pub fn with_storage(storage: S) -> Self {
        Self { storage }
    }

    /// Add a node to the graph
    pub fn add_node(&self, node: &Node) -> Result<()> {
        let node_key = node_key(node.id);
        self.storage.put(&node_key, node)?;
        info!("Added node: {} ({})", node.id, node.label);
        Ok(())
    }

    /// Get a node by ID
    pub fn get_node(&self, id: Uuid) -> Result<Option<Node>> {
        let key = node_key(id);
        self.storage.get(&key)
    }

    /// Add an edge between two nodes
    pub fn add_edge(&self, edge: &Edge) -> Result<()> {
        // Verify nodes exist
        if !self.storage.exists(&node_key(edge.source))? {
            return Err(KnowledgeGraphError::NodeNotFound(edge.source.to_string()));
        }
        if !self.storage.exists(&node_key(edge.target))? {
            return Err(KnowledgeGraphError::NodeNotFound(edge.target.to_string()));
        }

        let edge_key = edge_key(edge.id);
        self.storage.put(&edge_key, edge)?;
        
        info!("Added edge: {} -[{}]-> {}", 
            edge.source, edge.label, edge.target);
            
        Ok(())
    }

    /// Get an edge by ID
    pub fn get_edge(&self, id: Uuid) -> Result<Option<Edge>> {
        let key = edge_key(id);
        self.storage.get(&key)
    }

    /// Find nodes by label and properties
    pub fn find_nodes_by_label(&self, label: &str) -> Result<Vec<Node>> {
        // In a real implementation, this would use an index
        // For now, we'll do a full scan (not efficient for large graphs)
        let prefix = b"node:";
        let mut nodes = Vec::new();
        
        for (_, value) in self.storage.iter_prefix(prefix) {
            if let Ok(node) = deserialize::<Node>(&value) {
                if node.label == label {
                    nodes.push(node);
                }
            }
        }
        
        Ok(nodes)
    }

    /// Execute a transaction
    pub fn transaction<F, T>(&self, f: F) -> Result<T>
    where
        F: FnOnce(&mut Transaction<S>) -> Result<T>,
    {
        let mut tx = Transaction::new(&self.storage);
        let result = f(&mut tx)?;
        tx.commit()?;
        Ok(result)
    }
}

/// A transaction for atomic operations
pub struct Transaction<'a, S: Storage> {
    storage: &'a S,
    batch: Box<dyn WriteBatch>,
}

impl<'a, S: Storage> Transaction<'a, S> {
    fn new(storage: &'a S) -> Self {
        Self {
            storage,
            batch: storage.batch(),
        }
    }

    /// Add a node within the transaction
    pub fn add_node(&mut self, node: &Node) -> Result<()> {
        let node_key = node_key(node.id);
        self.batch.put(&node_key, node)
    }

    /// Add an edge within the transaction
    pub fn add_edge(&mut self, edge: &Edge) -> Result<()> {
        let edge_key = edge_key(edge.id);
        self.batch.put(&edge_key, edge)
    }

    /// Commit the transaction
    pub fn commit(self) -> Result<()> {
        self.batch.commit()
    }
}

// Helper functions for key generation
fn node_key(id: Uuid) -> Vec<u8> {
    let mut key = b"node:".to_vec();
    key.extend_from_slice(id.as_bytes());
    key
}

fn edge_key(id: Uuid) -> Vec<u8> {
    let mut key = b"edge:".to_vec();
    key.extend_from_slice(id.as_bytes());
    key
}

// Re-export serialization functions
use crate::storage::{serialize, deserialize};
use crate::storage::WriteBatch;
