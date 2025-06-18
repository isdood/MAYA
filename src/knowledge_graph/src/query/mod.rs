//! Query interface for the knowledge graph
//!
//! Provides a fluent API for querying the knowledge graph.

use std::marker::PhantomData;
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
    for<'b> <S as Storage>::Batch<'b>: WriteBatch + 'static,
    for<'b> <S as WriteBatchExt>::Batch<'b>: WriteBatch + 'static,
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
    for<'b> <S as Storage>::Batch<'b>: WriteBatch + 'static,
    for<'b> <S as WriteBatchExt>::Batch<'b>: WriteBatch + 'static,
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

    /// Filter nodes by label (alias for with_node_type)
    pub fn with_label(self, label: &'a str) -> Self {
        self.with_node_type(label)
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
        let mut edges = Vec::new();
        
        // Apply node filters if any
        if !self.node_filters.is_empty() {
            nodes.retain(|node| self.node_filters.iter().all(|f| f(node)));
        }
        
        // If we have edge filters, we need to process edges
        if !self.edge_filters.is_empty() {
            // For each node, get its edges and apply edge filters
            let mut filtered_nodes = Vec::new();
            
            for node in nodes {
                // Get all edges where this node is the source
                let node_edges = self.graph.query_edges_from(node.id)?;
                
                // Apply edge filters
                let filtered_edges: Vec<_> = node_edges
                    .into_iter()
                    .filter(|edge| self.edge_filters.iter().all(|f| f(edge)))
                    .collect();
                
                // If we found matching edges, include the node and edges in the result
                if !filtered_edges.is_empty() {
                    filtered_nodes.push(node.clone());
                    edges.extend(filtered_edges);
                }
            }
            
            nodes = filtered_nodes;
        }
        
        // Apply offset and limit to nodes
        let start = std::cmp::min(self.offset, nodes.len());
        let end = match self.limit {
            Some(limit) => std::cmp::min(start + limit, nodes.len()),
            None => nodes.len(),
        };
        
        let nodes = nodes.into_iter().skip(start).take(end - start).collect();
        
        Ok(QueryResult { nodes, edges })
    }
}

/// Extension trait for KnowledgeGraph to support fluent queries
pub trait QueryExt<S>
where
    S: Storage<Batch = <S as WriteBatchExt>::Batch> + WriteBatchExt,
    <S as Storage>::Batch: WriteBatch + 'static,
    <S as WriteBatchExt>::Batch: WriteBatch + 'static,
    for<'b> &'b S: 'b,
{
    /// Start building a query
    fn query(&self) -> QueryBuilder<S>;
}

impl<S> QueryExt<S> for KnowledgeGraph<S>
where
    S: Storage + WriteBatchExt,
    for<'a> <S as Storage>::Batch<'a>: WriteBatch + 'static,
    for<'a> <S as WriteBatchExt>::Batch<'a>: WriteBatch + 'static,
    for<'a> &'a S: 'a,
{
    fn query(&self) -> QueryBuilder<S> {
        QueryBuilder::new(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile;
    use crate::storage::SledStore;

    #[test]
    fn test_query_builder() -> Result<()> {
        let dir = tempfile::tempdir()?;
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
            .with_label("type1")
            .execute()?;
            
        assert_eq!(result.nodes.len(), 2);
        assert!(result.nodes.iter().all(|n| n.label == "type1"));
        
        // Test with limit and offset
        let result = QueryBuilder::new(&graph)
            .with_label("type1")
            .limit(1)
            .offset(1)
            .execute()?;
            
        assert_eq!(result.nodes.len(), 1);
        assert_eq!(result.nodes[0].label, "type1");
        
        Ok(())
    }
}
