//! Main knowledge graph implementation

use std::path::Path;
use std::sync::Arc;
use uuid::Uuid;
use serde::{Serialize, de::DeserializeOwned};
use log::{info, error};

use crate::{
    error::{Result, KnowledgeGraphError},
    models::{Node, Edge, Property},
    storage::{Storage, WriteBatch, WriteBatchExt},
};

/// Main knowledge graph structure
pub struct KnowledgeGraph<S: Storage> {
    storage: S,
}

impl<S> KnowledgeGraph<S> 
where
    S: Storage + WriteBatchExt<Batch = <S as Storage>::Batch>,
    <S as Storage>::Batch: WriteBatch + 'static,
    for<'a> &'a S: 'a,
{
    /// Create or open a knowledge graph at the given path
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self>
    where
        S: Sized,
    {
        let storage = S::open(path)?;
        info!("Opened knowledge graph database");
        Ok(Self { storage })
    }
    
    /// Create a new knowledge graph with a custom storage backend
    pub fn with_storage(storage: S) -> Self {
        Self { storage }
    }

    /// Add a node to the graph
    pub fn add_node(&self, node: Node) -> Result<()> {
        let key = format!("node:{}", node.id).into_bytes();
        
        // Check if node already exists
        if self.storage.exists(&key)? {
            return Err(KnowledgeGraphError::DuplicateNode(node.id.to_string()));
        }
        
        // Add node to storage using batch for atomicity
        let batch = <S as Storage>::batch(&self.storage);
        let value = serde_json::to_vec(&node)
            .map_err(KnowledgeGraphError::SerializationError)?;
        
        let mut batch = batch;
        batch.put_serialized(&key, &value)?;
        Box::new(batch).commit()
    }

    /// Get a node by ID
    pub fn get_node(&self, id: Uuid) -> Result<Option<Node>> {
        let key = format!("node:{}", id).into_bytes();
        self.storage.get(&key)
    }
    
    /// Get all nodes in the graph
    pub fn get_nodes(&self) -> Result<Vec<Node>> {
        let prefix = b"node:";
        let mut nodes = Vec::new();
        
        for result in self.storage.iter_prefix(prefix) {
            let value = result.1; // Extract the owned Vec<u8>
            match serde_json::from_slice::<Node>(&value) {
                Ok(node) => nodes.push(node),
                Err(e) => return Err(KnowledgeGraphError::SerializationError(e)),
            }
        }
        
        Ok(nodes)
    }

    /// Add an edge between two nodes
    pub fn add_edge(&self, edge: &Edge) -> Result<()> {
        // Verify source and target nodes exist
        let source_key = format!("node:{}", edge.source).into_bytes();
        let target_key = format!("node:{}", edge.target).into_bytes();
        
        if !self.storage.exists(&source_key)? {
            return Err(KnowledgeGraphError::NodeNotFound(edge.source.to_string()));
        }
        
        if !self.storage.exists(&target_key)? {
            return Err(KnowledgeGraphError::NodeNotFound(edge.target.to_string()));
        }
        
        // Add edge to storage using batch for atomicity
        let batch = <S as Storage>::batch(&self.storage);
        let key = format!("edge:{}:{}", edge.source, edge.id).into_bytes();
        let value = serde_json::to_vec(edge)
            .map_err(KnowledgeGraphError::SerializationError)?;
            
        let mut batch = batch;
        batch.put_serialized(&key, &value)?;
        
        // Add edge to source node's outgoing edges
        let source_edges_key = format!("node_edges:{}:outgoing", edge.source).into_bytes();
        let mut source_edges: Vec<Uuid> = self.storage.get(&source_edges_key)?.unwrap_or_default();
        source_edges.push(edge.id);
        let source_edges_value = serde_json::to_vec(&source_edges)
            .map_err(KnowledgeGraphError::SerializationError)?;
            
        batch.put_serialized(&source_edges_key, &source_edges_value)?;
        
        // Add edge to target node's incoming edges
        let target_edges_key = format!("node_edges:{}:incoming", edge.target).into_bytes();
        let mut target_edges: Vec<Uuid> = self.storage.get(&target_edges_key)?.unwrap_or_default();
        target_edges.push(edge.id);
        let target_edges_value = serde_json::to_vec(&target_edges)
            .map_err(KnowledgeGraphError::SerializationError)?;
            
        batch.put_serialized(&target_edges_key, &target_edges_value)?;
        
        // Commit the batch
        Box::new(batch).commit()
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

    /// Create a new transaction
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
pub struct Transaction<'a, S> 
where
    S: Storage + WriteBatchExt,
    <S as Storage>::Batch: WriteBatch + 'static,
    <S as WriteBatchExt>::Batch: WriteBatch + 'static,
{
    storage: &'a S,
    batch: Option<Box<dyn WriteBatch>>,
}

impl<'a, S> Transaction<'a, S> 
where
    S: Storage + WriteBatchExt<Batch = <S as Storage>::Batch>,
    <S as Storage>::Batch: WriteBatch + 'static,
{
    fn new(storage: &'a S) -> Self {
        let batch = <S as Storage>::batch(storage);
        Self {
            storage,
            batch: Some(Box::new(batch) as Box<dyn WriteBatch>),
        }
    }

    /// Add a node within the transaction
    pub fn add_node(&mut self, node: &Node) -> Result<()> {
        let node_key = node_key(node.id);
        let value = serde_json::to_vec(node)
            .map_err(KnowledgeGraphError::SerializationError)?;
        self.batch.as_mut().unwrap().put_serialized(&node_key, &value)
    }

    /// Add an edge within the transaction
    pub fn add_edge(&mut self, edge: &Edge) -> Result<()> {
        let edge_key = edge_key(edge.id);
        let value = serde_json::to_vec(edge)
            .map_err(KnowledgeGraphError::SerializationError)?;
        self.batch.as_mut().unwrap().put_serialized(&edge_key, &value)
    }

    /// Commit the transaction
    pub fn commit(self) -> Result<()> {
        if let Some(batch) = self.batch {
            batch.commit()
        } else {
            Err(KnowledgeGraphError::Other("Transaction already committed".to_string()))
        }
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
