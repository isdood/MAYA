//! Test utilities for the knowledge graph

use std::path::Path;
use tempfile::TempDir;
use uuid::Uuid;

use maya_knowledge_graph::{
    KnowledgeGraph, Node, Edge, Property, PropertyValue,
    storage::{SledStore, Storage}
};
use serde_json::Number;

/// Type alias for test graph
pub type TestGraph = KnowledgeGraph<SledStore>;

/// Create a test node with random properties
pub fn create_test_node(label: &str) -> Node {
    let mut node = Node::new(label);
    node.properties.push(Property::new("name", PropertyValue::String(format!("Test {}", Uuid::new_v4()))));
    node.properties.push(Property::new("value", PropertyValue::Number(Number::from(rand::random::<u32>() % 100))));
    node.created_at = chrono::Utc::now();
    node.updated_at = chrono::Utc::now();
    node
}

/// Create a test edge
pub fn create_test_edge(label: &str, source: Uuid, target: Uuid) -> Edge {
    Edge {
        id: Uuid::new_v4(),
        label: label.to_string(),
        source,
        target,
        properties: vec![
            Property::new("weight", PropertyValue::Number(Number::from_f64(rand::random::<f32>() as f64 * 10.0).unwrap())),
        ],
        created_at: chrono::Utc::now(),
    }
}

/// Create a test graph with sample data
pub fn create_test_graph() -> (TestGraph, Vec<Node>, Vec<Edge>) {
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let graph = KnowledgeGraph::open(temp_dir.path()).expect("Failed to create graph");
    
    // Create some test nodes
    let node1 = create_test_node("Person");
    let node2 = create_test_node("Person");
    let node3 = create_test_node("Location");
    
    // Clone nodes before moving them into the graph
    let node1_clone = node1.clone();
    let node2_clone = node2.clone();
    let node3_clone = node3.clone();
    
    // Add nodes to graph
    graph.add_node(node1).expect("Failed to add node1");
    graph.add_node(node2).expect("Failed to add node2");
    graph.add_node(node3).expect("Failed to add node3");
    
    // Create some test edges
    let edge1 = create_test_edge("KNOWS", node1_clone.id, node2_clone.id);
    let edge2 = create_test_edge("VISITED", node1_clone.id, node3_clone.id);
    
    // Add edges to graph
    graph.add_edge(&edge1).expect("Failed to add edge1");
    graph.add_edge(&edge2).expect("Failed to add edge2");
    
    (graph, vec![node1_clone, node2_clone, node3_clone], vec![edge1, edge2])
}

/// Assert that two nodes are equal, ignoring timestamps
pub fn assert_nodes_eq(a: &Node, b: &Node) {
    assert_eq!(a.id, b.id, "Node IDs don't match");
    assert_eq!(a.label, b.label, "Node labels don't match");
    assert_eq!(a.properties, b.properties, "Node properties don't match");
}

/// Assert that two edges are equal, ignoring timestamps
pub fn assert_edges_eq(a: &Edge, b: &Edge) {
    assert_eq!(a.id, b.id, "Edge IDs don't match");
    assert_eq!(a.label, b.label, "Edge labels don't match");
    assert_eq!(a.source, b.source, "Edge sources don't match");
    assert_eq!(a.target, b.target, "Edge targets don't match");
    assert_eq!(a.properties, b.properties, "Edge properties don't match");
}
