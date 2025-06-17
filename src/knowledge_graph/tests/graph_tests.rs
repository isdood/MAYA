//! Tests for the graph operations

use super::test_utils::*;
use maya_knowledge_graph::prelude::*;
use serde_json::json;

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
    assert_eq!(person_nodes.len(), 2);
    assert!(person_nodes.iter().all(|n| n.label == "Person"));
    
    // Find location nodes
    let location_nodes = graph.query()
        .with_label("Location")
        .execute()?;
    
    // Should be 1 location node
    assert_eq!(location_nodes.len(), 1);
    assert_eq!(location_nodes[0].label, "Location");
    
    Ok(())
}

#[test]
fn test_query_with_property() -> Result<()> {
    let (graph, nodes, _) = create_test_graph();
    
    // Add a node with a specific property
    let special_node = Node::new("Special")
        .with_property("unique_key", "special_value".into());
    graph.add_node(&special_node)?;
    
    // Query for it
    let results = graph.query()
        .with_property("unique_key", "special_value".into())
        .execute()?;
    
    // Should find exactly one node
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, special_node.id);
    
    Ok(())
}

#[test]
fn test_transaction() -> Result<()> {
    let dir = tempfile::tempdir()?;
    let graph = KnowledgeGraph::open(dir.path())?;
    
    // Create some test data
    let node1 = create_test_node("Test");
    let node2 = create_test_node("Test");
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
        tx.add_node(&create_test_node("Should not exist"))?;
        Err(KnowledgeGraphError::ValidationError("Test error".into()))
    });
    
    assert!(result.is_err());
    
    // Verify the node wasn't added
    let count = graph.query()
        .with_label("Should not exist")
        .execute()?
        .len();
    
    assert_eq!(count, 0);
    
    Ok(())
}

#[test]
fn test_pagination() -> Result<()> {
    let dir = tempfile::tempdir()?;
    let graph = KnowledgeGraph::open(dir.path())?;
    
    // Add multiple test nodes
    for i in 0..10 {
        let node = Node::new("PaginationTest")
            .with_property("index", i.into());
        graph.add_node(&node)?;
    }
    
    // Test limit
    let limited = graph.query()
        .with_label("PaginationTest")
        .limit(3)
        .execute()?;
    assert_eq!(limited.len(), 3);
    
    // Test offset
    let offset = graph.query()
        .with_label("PaginationTest")
        .limit(3)
        .offset(3)
        .execute()?;
    assert_eq!(offset.len(), 3);
    
    // Verify different results
    let limited_ids: Vec<_> = limited.iter().map(|n| n.id).collect();
    let offset_ids: Vec<_> = offset.iter().map(|n| n.id).collect();
    
    for id in &limited_ids {
        assert!(!offset_ids.contains(id), "Overlap between limited and offset results");
    }
    
    // Test getting all with pagination
    let all = graph.query()
        .with_label("PaginationTest")
        .limit(10)
        .execute()?;
    assert_eq!(all.len(), 10);
    
    Ok(())
}
