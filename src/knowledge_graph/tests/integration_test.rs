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
    
    let people = graph.query()
        .with_label("Person")
        .execute()?;
    
    for person in people.nodes {
        // Find who this person knows
        let known_people = graph.query()
            .with_label("KNOWS")
            .execute()?;
            
        for edge in known_people.edges {
            if edge.source == person.id {
                // Check if the known person works somewhere
                let workplaces = graph.query()
                    .with_label("WORKS_AT")
                    .execute()?;
                    
                if workplaces.edges.iter().any(|e| e.source == edge.target) {
                    people_who_know_workers.push(person.clone());
                    break;
                }
            }
        }
    }
    
    // Alice knows Bob, who works at the office
    assert_eq!(people_who_know_workers.len(), 1);
    assert_eq!(people_who_know_workers[0].id, alice.id);
    
    Ok(())
}

#[test]
fn test_persistence() -> Result<(), Box<dyn Error>> {
    // Test basic graph operations
    let dir = tempdir()?;
    let path = dir.path();
    
    let graph: KnowledgeGraph<SledStore> = KnowledgeGraph::open(path)?;
    let mut node = Node::new("Test");
    node.properties.push(Property::new("persistent", PropertyValue::Bool(true)));
    graph.add_node(node)?;
    
    // Reopen the graph
    let graph: KnowledgeGraph<SledStore> = KnowledgeGraph::open(path)?;
    
    // The node should still be there
    let nodes = graph.query()
        .with_label("Test")
        .with_property("persistent", PropertyValue::Bool(true))
        .execute()?;
    
    assert_eq!(nodes.nodes.len(), 1);
    
    Ok(())
}
