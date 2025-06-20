
//! Integration tests for the knowledge graph

use maya_knowledge_graph::{
    KnowledgeGraph, Node, Edge, Property, PropertyValue,
    storage::SledStore,
    query::QueryExt,
};
use tempfile::tempdir;
use std::error::Error;

fn create_test_node(label: &str, name: &str, age: i32) -> Node {
    let mut node = Node::new(label);
    node.properties.push(Property::new("name", PropertyValue::String(name.to_string())));
    node.properties.push(Property::new("age", PropertyValue::Number(age.into())));
    node
}

fn create_location_node(name: &str, capacity: i32) -> Node {
    let mut node = Node::new("Location");
    node.properties.push(Property::new("name", PropertyValue::String(name.to_string())));
    node.properties.push(Property::new("capacity", PropertyValue::Number(capacity.into())));
    node
}

#[test]
fn test_end_to_end_workflow() -> Result<(), Box<dyn Error>> {
    // Create a test graph with explicit type
    let dir = tempdir()?;
    let store = SledStore::open(dir.path())?;
    let graph = KnowledgeGraph::new(store);
    
    // Create some nodes
    let alice = create_test_node("Person", "Alice", 30);
    let bob = create_test_node("Person", "Bob", 25);
    let office = create_location_node("Office", 50);
    
    // Add nodes in a transaction
    graph.transaction(|tx| {
        tx.add_node(&alice)?;
        tx.add_node(&bob)?;
        tx.add_node(&office)?;
        Ok(())
    })?;
    
    // Add relationships
    let mut alice_knows_bob = Edge::new("KNOWS", alice.id, bob.id);
    alice_knows_bob.properties.push(Property::new("since", PropertyValue::String("2020".to_string())));
    
    // Alice works at the office
    let mut alice_works_at = Edge::new("WORKS_AT", alice.id, office.id);
    alice_works_at.properties.push(Property::new("since", PropertyValue::String("2021".to_string())));
    
    // Bob also works at the office
    let mut bob_works_at = Edge::new("WORKS_AT", bob.id, office.id);
    bob_works_at.properties.push(Property::new("since", PropertyValue::String("2020".to_string())));
    
    // Add all edges
    graph.add_edge(&alice_knows_bob)?;
    graph.add_edge(&alice_works_at)?;
    graph.add_edge(&bob_works_at)?;
    
    // Query 1: Find all people Alice knows
    let alice_friends = graph.query()
        .with_label("Person")
        .execute()?;
    
    let alice_friends: Vec<_> = alice_friends.nodes.into_iter()
        .filter(|node| node.id != alice.id)
        .collect();
    
    assert_eq!(alice_friends.len(), 1);
    let name_prop = alice_friends[0].properties.iter().find(|p| p.key == "name").unwrap();
    assert_eq!(name_prop.value, PropertyValue::String("Bob".to_string()));
    
    // Query 2: Find where Alice works
    let alice_workplaces = graph.query()
        .with_label("Location")
        .execute()?;
    
    assert_eq!(alice_workplaces.nodes.len(), 1);
    let name_prop = alice_workplaces.nodes[0].properties.iter().find(|p| p.key == "name").unwrap();
    assert_eq!(name_prop.value, PropertyValue::String("Office".to_string()));
    
    // Query 3: Find people who know someone who works at a location
    let mut people_who_know_workers = Vec::new();
    
    // First, get all people
    let people = graph.query()
        .with_label("Person")
        .execute()?;
    
    // For each person, check who they know and if those people work somewhere
    for person in &people.nodes {
        // Get all edges where this person is the source
        let edges = graph.query_edges_from(person.id)?;
        
        // Check if this person knows someone who works somewhere
        for edge in &edges {
            if edge.label == "KNOWS" {
                // Check if the target person (edge.target) has a WORKS_AT edge
                let works_edges = graph.query_edges_from(edge.target)?;
                
                if works_edges.iter().any(|e| e.label == "WORKS_AT") {
                    people_who_know_workers.push(person.clone());
                    break;
                }
            }
        }
    }
    
    // Alice knows Bob, who works at the office
    assert_eq!(people_who_know_workers.len(), 1, "Expected 1 person who knows someone who works, found {}", people_who_know_workers.len());
    if !people_who_know_workers.is_empty() {
        assert_eq!(people_who_know_workers[0].id, alice.id, "Expected Alice to be the one who knows someone who works");
    }
    
    Ok(())
}

#[test]
fn test_persistence() -> Result<(), Box<dyn Error>> {
    // Use a unique temporary directory for this test
    let temp_dir = tempfile::Builder::new()
        .prefix("maya_test_")
        .tempdir()?;
    let db_path = temp_dir.path().join("test_db");
    
    // Create and populate the first graph
    {
        let graph = KnowledgeGraph::<SledStore>::open(&db_path)?;
        let mut node = Node::new("test");
        node.properties.push(Property::new("name", PropertyValue::String("test".to_string())));
        graph.add_node(node)?;
    }
    
    // Ensure the graph is dropped and all files are closed
    std::thread::sleep(std::time::Duration::from_millis(100));
    
    // Reopen and verify
    let graph = KnowledgeGraph::<SledStore>::open(&db_path)?;
    let nodes: Vec<Node> = graph.query()
        .with_node_type("test")
        .execute()?
        .nodes;
        
    assert_eq!(nodes.len(), 1, "Expected 1 node, found {}", nodes.len());
    assert_eq!(nodes[0].label, "test");
    
    // Explicitly drop the graph before the temp_dir goes out of scope
    drop(graph);
    
    Ok(())
}
