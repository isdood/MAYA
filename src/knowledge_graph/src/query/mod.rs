@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 20:54:24",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/knowledge_graph/src/query/mod.rs",
    "type": "rs",
    "hash": "6bb030b16ba60e1be346b3d38e2463f458c0a2c4"
  }
}
@pattern_meta@

//! Query interface for the knowledge graph
//!
//! Provides a fluent API for querying the knowledge graph.

use std::marker::PhantomData;
use super::graph::{self, KnowledgeGraph};
use crate::error::Result;
use crate::models::{Node, Edge};
use crate::storage::{Storage, WriteBatch, WriteBatchExt};
use serde_json::Value;

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
        // Optimization: If only a label filter is present, use the label index
        let mut nodes = if self.node_filters.len() == 1 {
            // Try to detect if the filter is a label filter
            // This is a heuristic: if with_label/with_node_type was called, it is always the first filter
            if let Some(label) = self.extract_label_filter() {
                // Use the helper function from the graph module
                let node_ids = graph::get_node_ids_by_label(&self.graph, &label)?;
                let mut result_nodes = Vec::new();
                for node_id in node_ids {
                    if let Some(node) = self.graph.get_node(node_id)? {
                        result_nodes.push(node);
                    }
                }
                result_nodes
            } else {
                self.graph.get_nodes()?
            }
        } else {
            self.graph.get_nodes()?
        };
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

    /// Try to extract the label from the node_filters if it was set by with_label/with_node_type
    fn extract_label_filter(&self) -> Option<String> {
        // This is a heuristic: we know with_label/with_node_type pushes a filter that checks node.label == label
        // We can't extract the label directly from the closure, so we could store the label in a field when with_label is called
        // For now, this is a placeholder for future improvement
        None
    }
}

/// Extension trait for KnowledgeGraph to support fluent queries
pub trait QueryExt<S>
where
    S: Storage + WriteBatchExt,
    for<'a> <S as Storage>::Batch<'a>: WriteBatch + 'static,
    for<'a> &'a S: 'a,
{
    /// Start building a query
    fn query(&self) -> QueryBuilder<S>;
}

impl<S> QueryExt<S> for KnowledgeGraph<S>
where
    S: Storage + WriteBatchExt,
    for<'a> <S as Storage>::Batch<'a>: WriteBatch + 'static,
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
        let graph = KnowledgeGraph::new(store);
        
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

    #[test]
    fn test_label_index_integration() -> Result<()> {
        let dir = tempfile::tempdir()?;
        let store = SledStore::open(dir.path())?;
        let graph = KnowledgeGraph::new(store);

        // Add nodes with different labels
        let node_a1 = Node::new("Alpha");
        let node_a2 = Node::new("Alpha");
        let node_b1 = Node::new("Beta");
        let node_b2 = Node::new("Beta");
        let node_c = Node::new("Gamma");

        graph.add_node(node_a1.clone())?;
        graph.add_node(node_a2.clone())?;
        graph.add_node(node_b1.clone())?;
        graph.add_node(node_b2.clone())?;
        graph.add_node(node_c.clone())?;

        // Query by label using QueryBuilder
        let result_alpha = QueryBuilder::new(&graph)
            .with_label("Alpha")
            .execute()?;
        assert_eq!(result_alpha.nodes.len(), 2);
        assert!(result_alpha.nodes.iter().all(|n| n.label == "Alpha"));

        let result_beta = QueryBuilder::new(&graph)
            .with_label("Beta")
            .execute()?;
        assert_eq!(result_beta.nodes.len(), 2);
        assert!(result_beta.nodes.iter().all(|n| n.label == "Beta"));

        let result_gamma = QueryBuilder::new(&graph)
            .with_label("Gamma")
            .execute()?;
        assert_eq!(result_gamma.nodes.len(), 1);
        assert_eq!(result_gamma.nodes[0].label, "Gamma");

        // Optionally, check the label index directly
        use crate::graph::get_node_ids_by_label;
        let alpha_ids = get_node_ids_by_label(&graph, "Alpha")?;
        assert!(alpha_ids.contains(&node_a1.id));
        assert!(alpha_ids.contains(&node_a2.id));
        assert_eq!(alpha_ids.len(), 2);

        let beta_ids = get_node_ids_by_label(&graph, "Beta")?;
        assert!(beta_ids.contains(&node_b1.id));
        assert!(beta_ids.contains(&node_b2.id));
        assert_eq!(beta_ids.len(), 2);

        let gamma_ids = get_node_ids_by_label(&graph, "Gamma")?;
        assert!(gamma_ids.contains(&node_c.id));
        assert_eq!(gamma_ids.len(), 1);

        Ok(())
    }
}
