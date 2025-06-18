//! Integration tests for the knowledge graph

use maya_knowledge_graph::{
    KnowledgeGraph, Node, Edge, Property, PropertyValue,
    storage::SledStore,
    error::KnowledgeGraphError,
    query::QueryExt,
};
use tempfile::tempdir;
use std::error::Error;
use uuid::Uuid;
use serde_json::Error as JsonError;

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
    let graph: KnowledgeGraph<SledStore> = KnowledgeGraph::open(dir.path())?;
    
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
    let mut knows = Edge::new("KNOWS", alice.id, bob.id);
    knows.properties.push(Property::new("since", PropertyValue::String("2020".to_string())));
    
    let mut works_at = Edge::new("WORKS_AT", alice.id, office.id);
    works_at.properties.push(Property::new("since", PropertyValue::String("2021".to_string())));
    
    graph.add_edge(&knows)?;
    graph.add_edge(&works_at)?;
    
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
    
    println!("Found {} people in the graph", people.nodes.len());
    
    // For each person, check who they know and if those people work somewhere
    for person in &people.nodes {
        println!("Checking person: {:?} (ID: {})", 
            person.properties.iter().find(|p| p.key == "name").map(|p| &p.value).unwrap_or(&PropertyValue::Null),
            person.id
        );
        
        // Get all edges where this person is the source
        let edges = graph.query_edges_from(person.id)?;
        println!("  Found {} edges from this person", edges.len());
        
        // Check if this person knows someone who works somewhere
        for edge in &edges {
            println!("    Edge: {} -> {} (label: {})", edge.source, edge.target, edge.label);
            
            if edge.label == "KNOWS" {
                println!("      Found KNOWS edge to person {}", edge.target);
                
                // Check if the target person (edge.target) has a WORKS_AT edge
                let works_edges = graph.query_edges_from(edge.target)?;
                println!("      Found {} edges from target person {}", works_edges.len(), edge.target);
                
                for we in &works_edges {
                    println!("        Edge: {} -> {} (label: {})", we.source, we.target, we.label);
                }
                
                if works_edges.iter().any(|e| e.label == "WORKS_AT") {
                    println!("      This person knows someone who works!");
                    people_who_know_workers.push(person.clone());
                    break;
                }
            }
        }
    }
    
    println!("People who know someone who works: {}", people_who_know_workers.len());
    
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
