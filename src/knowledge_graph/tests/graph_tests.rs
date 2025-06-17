//! Tests for the graph operations

use maya_knowledge_graph::{
    KnowledgeGraph, Node, Edge, Property, PropertyValue,
    storage::{SledStore, Storage, WriteBatchExt},
    error::Result,
    query::QueryExt,
};
use tempfile::tempdir;
use uuid::Uuid;
use serde_json::Error as JsonError;

// Helper function to create a test node
fn create_test_node(label: &str, name: &str, age: i32) -> Node {
    let mut node = Node::new(label);
    node.properties.push(Property::new("name", PropertyValue::String(name.to_string())));
    node.properties.push(Property::new("age", PropertyValue::Number(age.into())));
    node
}

// Helper function to create a test edge
fn create_test_edge(rel_type: &str, from: Uuid, to: Uuid) -> Edge {
    Edge::new(rel_type, from, to)
}

// Helper function to assert node equality
fn assert_nodes_eq(expected: &Node, actual: &Node) {
    assert_eq!(expected.id, actual.id);
    assert_eq!(expected.label, actual.label);
    assert_eq!(expected.properties, actual.properties);
}

// Helper function to assert edge equality
fn assert_edges_eq(expected: &Edge, actual: &Edge) {
    assert_eq!(expected.id, actual.id);
    assert_eq!(expected.label, actual.label);
    assert_eq!(expected.source, actual.source);
    assert_eq!(expected.target, actual.target);
    assert_eq!(expected.properties, actual.properties);
}

// Helper function to create a test graph
fn create_test_graph() -> (KnowledgeGraph<SledStore>, Vec<Node>, Vec<Edge>) {
    let dir = tempfile::tempdir().unwrap();
    let graph = KnowledgeGraph::open(dir.path()).unwrap();
    
    // Create test nodes
    let node1 = create_test_node("Person", "Alice", 30);
    let node2 = create_test_node("Person", "Bob", 25);
    let node3 = create_test_node("Location", "Office", 50);
    
    // Add nodes to graph
    graph.add_node(node1.clone()).unwrap();
    graph.add_node(node2.clone()).unwrap();
    graph.add_node(node3.clone()).unwrap();
    
    // Create test edges
    let edge1 = create_test_edge("WORKS_AT", node1.id, node3.id);
    let edge2 = create_test_edge("WORKS_AT", node2.id, node3.id);
    
    // Add edges to graph
    graph.add_edge(&edge1).unwrap();
    graph.add_edge(&edge2).unwrap();
    
    (graph, vec![node1, node2, node3], vec![edge1, edge2])
}

#[test]
fn test_add_and_retrieve_node() -> Result<()> {
    let (graph, nodes, _) = create_test_graph();
    
    // Test retrieving each node
    for node in &nodes {
        let retrieved = graph.get_node(node.id)?.expect("Node not found");
        assert_nodes_eq(node, &retrieved);
    }
    
    // Test non-existent node
    assert!(graph.get_node(Uuid::new_v4())?.is_none());
    
    Ok(())
}

#[test]
fn test_add_and_retrieve_edge() -> Result<()> {
    let (graph, nodes, edges) = create_test_graph();
    
    // Test retrieving each edge
    for edge in &edges {
        let retrieved = graph.get_edge(edge.id)?.expect("Edge not found");
        assert_edges_eq(edge, &retrieved);
    }
    
    // Test non-existent edge
    assert!(graph.get_edge(Uuid::new_v4())?.is_none());
    
    Ok(())
}

#[test]
fn test_find_nodes_by_label() -> Result<()> {
    let (graph, nodes, _) = create_test_graph();
    
    // Find all person nodes
    let person_nodes = graph.query()
        .with_label("Person")
        .execute()?;
    
    // Should be 2 person nodes (from test_utils)
    assert_eq!(person_nodes.nodes.len(), 2);
    assert!(person_nodes.nodes.iter().all(|n| n.label == "Person"));
    
    // Find location nodes
    let location_nodes = graph.query()
        .with_label("Location")
        .execute()?;
    
    // Should be 1 location node
    assert_eq!(location_nodes.nodes.len(), 1);
    assert_eq!(location_nodes.nodes[0].label, "Location");
    
    Ok(())
}

#[test]
fn test_query_with_property() -> Result<()> {
    let (graph, nodes, _) = create_test_graph();
    
    // Add a node with a specific property
    let special_node = Node::new("Special")
        .with_property("unique_key", "special_value");
    graph.add_node(special_node.clone())?;
    
    // Query for it
    let results = graph.query()
        .with_property("unique_key", "special_value".into())
        .execute()?;
    
    // Should find exactly one node
    assert_eq!(results.nodes.len(), 1);
    assert_eq!(results.nodes[0].id, special_node.id);
    
    Ok(())
}

#[test]
fn test_transaction() -> Result<()> {
    let dir = tempfile::tempdir()?;
    let graph = KnowledgeGraph::open(dir.path())?;
    
    // Create some test data with proper parameters
    let node1 = create_test_node("Test", "Node 1", 30);
    let node2 = create_test_node("Test", "Node 2", 25);
    let edge = create_test_edge("RELATES_TO", node1.id, node2.id);
    
    // Execute in a transaction
    graph.transaction(|tx| {
        tx.add_node(&node1)?;
        tx.add_node(&node2)?;
        tx.add_edge(&edge)?;
        Ok(())
    })?;
    
    // Verify everything was added
    assert!(graph.get_node(node1.id)?.is_some());
    assert!(graph.get_node(node2.id)?.is_some());
    assert!(graph.get_edge(edge.id)?.is_some());
    
    // Test rollback on error
    let result = graph.transaction(|tx| {
        let bad_node = create_test_node("Should not exist", "Bad Node", 0);
        tx.add_node(&bad_node)?;
        Err(JsonError::custom("Test error"))
    });
    
    assert!(result.is_err());
    
    // Verify the node wasn't added
    let results = graph.query()
        .with_label("Should not exist")
        .execute()?;
    assert_eq!(results.nodes.len(), 0);
    
    Ok(())
}

#[test]
fn test_pagination() -> Result<()> {
    let dir = tempfile::tempdir()?;
    let graph = KnowledgeGraph::open(dir.path())?;
    
    // Add multiple test nodes
    for i in 0..10 {
        let mut node = Node::new("PaginationTest");
        node.properties.push(Property::new("index", PropertyValue::Number(i.into())));
        graph.add_node(node)?;
    }
    
    // Test limit
    let limited = graph.query()
        .with_label("PaginationTest")
        .limit(3)
        .execute()?;
    assert_eq!(limited.nodes.len(), 3);
    
    // Test offset
    let offset = graph.query()
        .with_label("PaginationTest")
        .limit(3)
        .offset(3)
        .execute()?;
    assert_eq!(offset.nodes.len(), 3);
    
    // Verify different results
    let limited_ids: Vec<_> = limited.nodes.iter().map(|n| n.id).collect();
    let offset_ids: Vec<_> = offset.nodes.iter().map(|n| n.id).collect();
    
    for id in &limited_ids {
        assert!(!offset_ids.contains(id), "Overlap between limited and offset results");
    }
    
    // Test getting all with pagination
    let all = graph.query()
        .with_label("PaginationTest")
        .limit(10)
        .execute()?;
    assert_eq!(all.nodes.len(), 10);
    
    Ok(())
}
