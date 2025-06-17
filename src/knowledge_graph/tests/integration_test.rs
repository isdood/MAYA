//! Integration tests for the knowledge graph

use maya_knowledge_graph::{
    storage::WriteBatchExt,
    query::QueryExt,
    KnowledgeGraph, Node, Edge, PropertyValue
};
use tempfile::tempdir;
use uuid::Uuid;

fn create_test_node(label: &str, name: &str, age: i32) -> Node {
    let mut node = Node::new(label);
    node.properties.insert("name".to_string(), PropertyValue::String(name.to_string()));
    node.properties.insert("age".to_string(), PropertyValue::Number(age.into()));
    node
}

fn create_location_node(name: &str, capacity: i32) -> Node {
    let mut node = Node::new("Location");
    node.properties.insert("name".to_string(), PropertyValue::String(name.to_string()));
    node.properties.insert("capacity".to_string(), PropertyValue::Number(capacity.into()));
    node
}

#[test]
fn test_end_to_end_workflow() -> Result<()> {
    // Setup
    let dir = tempdir()?;
    let graph = KnowledgeGraph::open(dir.path())?;
    
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
    let knows = Edge::new("KNOWS", alice.id, bob.id)
        .with_property("since", "2020".into());
    
    let works_at = Edge::new("WORKS_AT", alice.id, office.id)
        .with_property("since", "2021".into());
    
    graph.add_edge(&knows)?;
    graph.add_edge(&works_at)?;
    
    // Query 1: Find all people Alice knows
    let alice_friends: Vec<Node> = graph.query()
        .with_label("Person")
        .execute()?
        .into_iter()
        .filter(|node| node.id != alice.id)
        .collect();
    
    assert_eq!(alice_friends.len(), 1);
    assert_eq!(alice_friends[0].properties[0].value, "Bob".into());
    
    // Query 2: Find where Alice works
    let alice_workplaces: Vec<Node> = graph.query()
        .with_label("Location")
        .execute()?;
    
    assert_eq!(alice_workplaces.len(), 1);
    assert_eq!(alice_workplaces[0].properties[0].value, "Office".into());
    
    // Query 3: Find people who know someone who works at a location
    let mut people_who_know_workers = Vec::new();
    
    let people: Vec<Node> = graph.query()
        .with_label("Person")
        .execute()?;
    
    for person in people {
        // Find who this person knows
        let known_people: Vec<Edge> = graph.query()
            .with_label("KNOWS")
            .execute()?;
            
        for edge in known_people {
            if edge.source == person.id {
                // Check if the known person works somewhere
                let workplaces: Vec<Edge> = graph.query()
                    .with_label("WORKS_AT")
                    .execute()?;
                    
                if workplaces.iter().any(|e| e.source == edge.target) {
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
fn test_persistence() -> Result<()> {
    // Create and populate a graph
    let dir = tempfile::tempdir()?;
    let path = dir.path();
    
    {
        let graph = KnowledgeGraph::open(path)?;
        let node = Node::new("Test")
            .with_property("persistent", true.into());
        graph.add_node(&node)?;
    }
    
    // Reopen the graph
    let graph = KnowledgeGraph::open(path)?;
    
    // The node should still be there
    let nodes = graph.query()
        .with_label("Test")
        .with_property("persistent", true.into())
        .execute()?;
    
    assert_eq!(nodes.len(), 1);
    
    Ok(())
}
