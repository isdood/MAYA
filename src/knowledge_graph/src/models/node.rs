
//! Node model for the knowledge graph

use super::*;
use serde::{Serialize, Deserialize};

/// A node in the knowledge graph
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Node {
    /// Unique identifier
    pub id: Uuid,
    
    /// Node type/label
    pub label: String,
    
    /// Node properties
    pub properties: Vec<Property>,
    
    /// Creation timestamp
    pub created_at: DateTime<Utc>,
    
    /// Last update timestamp
    pub updated_at: DateTime<Utc>,
}

impl Node {
    /// Create a new node with the given label
    pub fn new(label: &str) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            label: label.to_string(),
            properties: Vec::new(),
            created_at: now,
            updated_at: now,
        }
    }
    
    /// Add a property to the node
    pub fn with_property(mut self, key: &str, value: impl Into<PropertyValue>) -> Self {
        self.properties.push(Property::new(key, value.into()));
        self
    }
    
    /// Get a property by key
    pub fn get_property(&self, key: &str) -> Option<&PropertyValue> {
        self.properties
            .iter()
            .find(|p| p.key == key)
            .map(|p| &p.value)
    }
    
    /// Check if the node has a property with the given key
    pub fn has_property(&self, key: &str) -> bool {
        self.properties.iter().any(|p| p.key == key)
    }
    
    /// Update a property or add it if it doesn't exist
    pub fn set_property(&mut self, key: &str, value: impl Into<PropertyValue>) {
        let value = value.into();
        if let Some(prop) = self.properties.iter_mut().find(|p| p.key == key) {
            prop.value = value;
        } else {
            self.properties.push(Property::new(key, value));
        }
        self.updated_at = Utc::now();
    }
    
    /// Remove a property by key
    pub fn remove_property(&mut self, key: &str) -> Option<Property> {
        let pos = self.properties.iter().position(|p| p.key == key)?;
        Some(self.properties.remove(pos))
    }
}

impl GraphElement for Node {
    fn id(&self) -> Uuid {
        self.id
    }
    
    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    
    #[test]
    fn test_node_creation() {
        let node = Node::new("TestNode");
        
        assert_eq!(node.label, "TestNode");
        assert!(!node.id.is_nil());
        assert!(node.properties.is_empty());
    }
    
    #[test]
    fn test_node_properties() {
        let mut node = Node::new("TestNode")
            .with_property("name", "test")
            .with_property("value", 42);
            
        assert_eq!(node.properties.len(), 2);
        assert_eq!(node.get_property("name"), Some(&json!("test")));
        assert_eq!(node.get_property("nonexistent"), None);
        
        node.set_property("name", "updated");
        assert_eq!(node.get_property("name"), Some(&json!("updated")));
        
        node.set_property("new", true);
        assert_eq!(node.get_property("new"), Some(&json!(true)));
        
        assert!(node.remove_property("name").is_some());
        assert_eq!(node.properties.len(), 2);
    }
}
