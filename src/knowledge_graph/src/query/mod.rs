//! Query interface for the knowledge graph
//!
//! Provides a fluent API for querying the knowledge graph.

use std::collections::HashMap;
use std::marker::PhantomData;
use uuid::Uuid;
use serde_json::Value;

use crate::{
    error::Result,
    models::{Node, Edge},
    storage::{Storage, WriteBatch, WriteBatchExt},
    KnowledgeGraph,
};

/// Result of a query execution
#[derive(Debug)]
pub struct QueryResult {
    /// Matching nodes
    pub nodes: Vec<Node>,
    /// Matching edges
    pub edges: Vec<Edge>,
}

/// Builder for constructing graph queries
pub struct QueryBuilder<'a, S>
where
    S: Storage + WriteBatchExt,
    S::Batch: WriteBatch + 'static,
    for<'b> &'b S: 'b,
{
    graph: &'a KnowledgeGraph<S>,
    node_filters: Vec<Box<dyn Fn(&Node) -> bool + 'a>>,
    edge_filters: Vec<Box<dyn Fn(&Edge) -> bool + 'static>>,
    limit: Option<usize>,
    offset: usize,
    _marker: PhantomData<S>,
}

impl<'a, S> QueryBuilder<'a, S>
where
    S: Storage + WriteBatchExt,
    S::Batch: WriteBatch + 'static,
    for<'b> &'b S: 'b,
{
    /// Create a new query builder
    pub fn new(graph: &'a KnowledgeGraph<S>) -> Self {
        Self {
            graph,
            node_filters: Vec::new(),
            edge_filters: Vec::new(),
            limit: None,
            offset: 0,
            _marker: PhantomData,
        }
    }

    /// Filter nodes by label
    pub fn with_node_type(mut self, node_type: &'a str) -> Self {
        let node_type = node_type.to_string();
        self.node_filters.push(Box::new(move |node: &Node| node.label == node_type));
        self
    }

    /// Filter nodes by label
    pub fn with_label(mut self, label: &'static str) -> Self {
        self.node_filters.push(Box::new(move |node: &Node| node.label == label));
        self
    }

    /// Filter nodes by property
    pub fn with_property<T: Into<String>>(mut self, key: T, value: Value) -> Self {
        let key = key.into();
        self.node_filters.push(Box::new(move |node: &Node| {
            node.properties.iter().any(|p| p.key == key && p.value == value)
        }));
        self
    }

    /// Set the maximum number of results to return
    pub fn limit(mut self, limit: usize) -> Self {
        self.limit = Some(limit);
        self
    }

    /// Set the number of results to skip
    pub fn offset(mut self, offset: usize) -> Self {
        self.offset = offset;
        self
    }

    /// Execute the query and return the matching nodes and edges
    pub fn execute(self) -> Result<QueryResult> {
        // Start with all nodes if no filters
        let mut nodes = self.graph.get_nodes()?;
        
        // Apply filters if any
        if !self.node_filters.is_empty() {
            nodes.retain(|node| self.node_filters.iter().all(|f| f(node)));
        }
        
        // Apply offset and limit
        let start = std::cmp::min(self.offset, nodes.len());
        let end = match self.limit {
            Some(limit) => std::cmp::min(start + limit, nodes.len()),
            None => nodes.len(),
        };
        
        let nodes = nodes.into_iter().skip(start).take(end - start).collect();
        
        // TODO: Apply edge filters and construct result
        
        Ok(QueryResult {
            nodes,
            edges: Vec::new(),
        })
    }
}

/// Extension trait for KnowledgeGraph to support fluent queries
pub trait QueryExt<S>
where
    S: Storage + WriteBatchExt,
    S::Batch: WriteBatch + 'static,
    for<'b> &'b S: 'b,
{
    /// Start building a query
    fn query(&self) -> QueryBuilder<S>;
}

impl<S> QueryExt<S> for KnowledgeGraph<S>
where
    S: Storage + WriteBatchExt,
    S::Batch: WriteBatch + 'static,
    for<'b> &'b S: 'b,
{
    fn query(&self) -> QueryBuilder<S> {
        QueryBuilder::new(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    use crate::storage::SledStore;

    #[test]
    fn test_query_builder() -> Result<()> {
        let dir = tempdir()?;
        let store = SledStore::open(dir.path())?;
        let graph = KnowledgeGraph::with_storage(store);
        
        // Add test data
        let node1 = Node::new("type1".into());
        let node2 = Node::new("type2".into());
        let node3 = Node::new("type1".into());
        
        graph.add_node(node1)?;
        graph.add_node(node2)?;
        graph.add_node(node3)?;
        
        // Test filtering by node type
        let result = QueryBuilder::new(&graph)
            .with_node_type("type1")
            .execute()?;
            
        assert_eq!(result.nodes.len(), 2);
        assert!(result.nodes.iter().all(|n| n.node_type == "type1"));
        
        // Test with limit and offset
        let result = QueryBuilder::new(&graph)
            .with_node_type("type1")
            .limit(1)
            .offset(1)
            .execute()?;
            
        assert_eq!(result.nodes.len(), 1);
        assert_eq!(result.nodes[0].node_type, "type1");
        
        Ok(())
    }
}
