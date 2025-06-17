//! Query interface for the knowledge graph
//!
//! Provides a fluent API for querying the knowledge graph.

use std::collections::HashMap;
use uuid::Uuid;
use serde_json::Value;

use crate::{
    error::Result,
    models::{Node, Edge},
    graph::KnowledgeGraph,
    storage::Storage,
};

/// A builder for graph queries
pub struct QueryBuilder<'a, S: Storage> {
    graph: &'a KnowledgeGraph<S>,
    node_filters: Vec<Box<dyn Fn(&Node) -> bool + 'static>>,
    edge_filters: Vec<Box<dyn Fn(&Edge) -> bool + 'static>>,
    limit: Option<usize>,
    offset: usize,
}

impl<'a, S: Storage> QueryBuilder<'a, S> {
    /// Create a new query builder
    pub fn new(graph: &'a KnowledgeGraph<S>) -> Self {
        Self {
            graph,
            node_filters: Vec::new(),
            edge_filters: Vec::new(),
            limit: None,
            offset: 0,
        }
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

    /// Execute the query and return matching nodes
    pub fn execute(&self) -> Result<Vec<Node>> {
        // In a real implementation, this would use indices for efficient querying
        // For now, we'll do a full scan (not efficient for large graphs)
        let prefix = b"node:";
        let mut results = Vec::new();
        
        for (_, value) in self.graph.storage.iter_prefix(prefix) {
            if let Ok(node) = serde_json::from_slice::<Node>(&value) {
                if self.node_filters.iter().all(|f| f(&node)) {
                    results.push(node);
                }
            }
            
            // Apply limit if set
            if let Some(limit) = self.limit {
                if results.len() >= limit + self.offset {
                    break;
                }
            }
        }
        
        // Apply offset and limit
        let start = std::cmp::min(self.offset, results.len());
        let end = self.limit.map_or(results.len(), |l| std::cmp::min(start + l, results.len()));
        
        Ok(results.into_iter().skip(start).take(end - start).collect())
    }
}

/// Extension trait for KnowledgeGraph to support fluent queries
pub trait QueryExt<S: Storage> {
    /// Start building a new query
    fn query(&self) -> QueryBuilder<S>;
}

impl<S: Storage> QueryExt<S> for KnowledgeGraph<S> {
    fn query(&self) -> QueryBuilder<S> {
        QueryBuilder::new(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::Property;
    use tempfile::tempdir;

    #[test]
    fn test_query_builder() -> Result<()> {
        let dir = tempdir()?;
        let graph = KnowledgeGraph::open(dir.path())?;
        
        // Add some test nodes
        let node1 = Node::new("Person")
            .with_property("name", "Alice".into())
            .with_property("age", 30.into());
            
        let node2 = Node::new("Person")
            .with_property("name", "Bob".into())
            .with_property("age", 25.into());
            
        let node3 = Node::new("Location")
            .with_property("name", "Office".into())
            .with_property("capacity", 50.into());
        
        graph.add_node(&node1)?;
        graph.add_node(&node2)?;
        graph.add_node(&node3)?;
        
        // Test querying
        let results = graph.query()
            .with_label("Person")
            .with_property("age", 30.into())
            .execute()?;
            
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].properties[0].value, "Alice".into());
        
        Ok(())
    }
}
