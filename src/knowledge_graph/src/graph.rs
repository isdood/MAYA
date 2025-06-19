//! Core knowledge graph implementation
//!
//! This module contains the main [`KnowledgeGraph`] type and related functionality
//! for creating, querying, and modifying a knowledge graph.
//!
//! # Examples
//!
//! ```no_run
//! use maya_knowledge_graph::prelude::*;
//! use uuid::Uuid;
//! use tempfile::tempdir;
//!
//! # fn main() -> Result<(), Box<dyn std::error::Error>> {
//! // Create a temporary directory for the database
//! let temp_dir = tempdir()?;
//! 
//! // Open or create a new knowledge graph
//! let graph = KnowledgeGraph::open(temp_dir.path())?;
//! 
//! // Create and add nodes
//! let alice_id = Uuid::new_v4();
//! let bob_id = Uuid::new_v4();
//! 
//! let alice = Node::new("Person")
//!     .with_id(alice_id)
//!     .with_property("name", "Alice");
//! 
//! let bob = Node::new("Person")
//!     .with_id(bob_id)
//!     .with_property("name", "Bob");
//! 
//! // Add nodes to the graph
//! graph.add_node(alice)?;
//! graph.add_node(bob)?;
//! 
//! // Create a relationship
//! let edge = Edge::new("KNOWS", alice_id, bob_id)
//!     .with_property("since", 2020);
//! 
//! graph.add_edge(&edge)?;
//! 
//! // Query the graph
//! let alice_node = graph.get_node(alice_id)?.expect("Alice not found");
//! let relationships = graph.query_edges_from(alice_id)?;
//! 
//! println!("Node: {:?}", alice_node);
//! println!("Relationships: {:?}", relationships);
//! # Ok(())
//! # }

use std::path::Path;
use uuid::Uuid;
use log::info;

use crate::{
    error::{Result, KnowledgeGraphError},
    models::{Node, Edge},
    storage::{Storage, WriteBatch, WriteBatchExt},
};

/// A high-performance, thread-safe knowledge graph implementation.
///
/// The `KnowledgeGraph` provides methods for creating, reading, updating, and deleting
/// nodes and edges in a property graph. It supports transactions, batch operations,
/// and efficient querying of graph data.
///
/// # Type Parameters
/// - `S`: The storage backend implementing the [`Storage`] trait.
///
/// # Examples
///
/// ```no_run
/// use maya_knowledge_graph::prelude::*;
/// use tempfile::tempdir;
///
/// # fn main() -> Result<(), Box<dyn std::error::Error>> {
/// // Create a temporary directory for the database
/// let temp_dir = tempdir()?;
/// 
/// // Open or create a new knowledge graph
/// let graph = KnowledgeGraph::open(temp_dir.path())?;
/// 
/// // Use the graph...
/// # Ok(())
/// # }
/// ```
///
/// # Concurrency
///
/// The `KnowledgeGraph` is designed to be used concurrently from multiple threads.
/// It uses interior mutability to allow shared access to the underlying storage.
/// For batch operations, use the [`transaction`] method to ensure atomicity.
///
/// # Error Handling
///
/// Most methods return a `Result<T, KnowledgeGraphError>` where `T` is the success type.
/// Common errors include:
/// - `NodeNotFound`: A referenced node does not exist
/// - `DuplicateNode`: Attempted to add a node with an existing ID
/// - `StorageError`: An error occurred in the underlying storage
/// - `SerializationError`: Failed to serialize or deserialize data
#[derive(Debug)]
pub struct KnowledgeGraph<S: Storage> {
    storage: S,
}

impl<S> KnowledgeGraph<S> 
where
    S: Storage + WriteBatchExt,
    for<'a> <S as Storage>::Batch<'a>: WriteBatch + 'static,
    for<'a> <S as WriteBatchExt>::BatchType<'a>: WriteBatch + 'static,
    for<'a> &'a S: 'a,
{
    /// Create a new knowledge graph with a custom storage backend
    pub fn new(storage: S) -> Self {
        Self { storage }
    }

    /// Add a node to the graph
    ///
    /// Also updates the label index for fast label-based queries.
    pub fn add_node(&self, node: Node) -> Result<()> {
        let key = node_key(node.id);
        
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
        Box::new(batch).commit()?;
        
        // Update label index
        add_node_to_label_index(&self.storage, &node.label, node.id)?;
        Ok(())
    }

    /// Get a node by ID
    pub fn get_node(&self, id: Uuid) -> Result<Option<Node>> {
        let key = node_key(id);
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
        let source_key = node_key(edge.source);
        let target_key = node_key(edge.target);
        
        if !self.storage.exists(&source_key)? {
            return Err(KnowledgeGraphError::NodeNotFound(edge.source.to_string()));
        }
        
        if !self.storage.exists(&target_key)? {
            return Err(KnowledgeGraphError::NodeNotFound(edge.target.to_string()));
        }
        
        // Add edge to storage using batch for atomicity
        let batch = <S as Storage>::batch(&self.storage);
        let key = edge_key(edge.id);
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
        let mut nodes = Vec::new();
        
        for node in self.get_nodes()? {
            if node.label == label {
                nodes.push(node);
            }
        }
        
        Ok(nodes)
    }
    
    /// Find all edges originating from a specific node
    pub fn query_edges_from(&self, node_id: Uuid) -> Result<Vec<Edge>> {
        let prefix = b"edge:";
        let mut edges = Vec::new();
        
        for result in self.storage.iter_prefix(prefix) {
            let value = result.1; // Extract the owned Vec<u8>
            if let Ok(edge) = serde_json::from_slice::<Edge>(&value) {
                if edge.source == node_id {
                    edges.push(edge);
                }
            }
        }
        
        Ok(edges)
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
    for<'b> <S as Storage>::Batch<'b>: WriteBatch + 'static,
    for<'b> <S as WriteBatchExt>::BatchType<'b>: WriteBatch + 'static,
{
    batch: <S as Storage>::Batch<'a>,
    _marker: std::marker::PhantomData<&'a S>,
}

impl<'a, S> Transaction<'a, S> 
where
    S: Storage + WriteBatchExt,
    for<'b> <S as Storage>::Batch<'b>: WriteBatch + 'static,
    for<'b> <S as WriteBatchExt>::BatchType<'b>: WriteBatch + 'static,
{
    fn new(storage: &'a S) -> Self {
        let batch = <S as Storage>::batch(storage);
        Self {
            batch,
            _marker: std::marker::PhantomData,
        }
    }

    /// Add a node within the transaction
    pub fn add_node(&mut self, node: &Node) -> Result<()> {
        let node_key = node_key(node.id);
        let value = serde_json::to_vec(node)?;
        self.batch.put_serialized(&node_key, &value)
    }

    /// Add an edge within the transaction
    pub fn add_edge(&mut self, edge: &Edge) -> Result<()> {
        let edge_key = edge_key(edge.id);
        let value = serde_json::to_vec(edge)?;
        self.batch.put_serialized(&edge_key, &value)
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

// Serialization functions are used through the Storage trait

// Label index helper functions
use uuid::Uuid;

/// Key format for label index: "label_index:<label>"
fn label_index_key(label: &str) -> Vec<u8> {
    let mut key = b"label_index:".to_vec();
    key.extend_from_slice(label.as_bytes());
    key
}

/// Add a node ID to the label index
fn add_node_to_label_index<S: Storage>(storage: &S, label: &str, node_id: Uuid) -> Result<()> {
    let key = label_index_key(label);
    let mut node_ids: Vec<Uuid> = storage.get(&key)?.unwrap_or_default();
    if !node_ids.contains(&node_id) {
        node_ids.push(node_id);
        storage.put(&key, &node_ids)?;
    }
    Ok(())
}

/// Remove a node ID from the label index
fn remove_node_from_label_index<S: Storage>(storage: &S, label: &str, node_id: Uuid) -> Result<()> {
    let key = label_index_key(label);
    let mut node_ids: Vec<Uuid> = storage.get(&key)?.unwrap_or_default();
    let original_len = node_ids.len();
    node_ids.retain(|id| id != &node_id);
    if node_ids.is_empty() {
        storage.delete(&key)?;
    } else if node_ids.len() != original_len {
        storage.put(&key, &node_ids)?;
    }
    Ok(())
}

/// Get all node IDs for a given label
pub(crate) fn get_node_ids_by_label<S: Storage>(storage: &S, label: &str) -> Result<Vec<Uuid>> {
    let key = label_index_key(label);
    Ok(storage.get(&key)?.unwrap_or_default())
}
