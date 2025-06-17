//! Edge model for the knowledge graph

use super::*;
use serde::{Serialize, Deserialize};

/// A directed edge between two nodes in the knowledge graph
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Edge {
    /// Unique identifier
    pub id: Uuid,
    
    /// Edge type/label
    pub label: String,
    
    /// Source node ID
    pub source: Uuid,
    
    /// Target node ID
    pub target: Uuid,
    
    /// Edge properties
    pub properties: Vec<Property>,
    
    /// Creation timestamp
    pub created_at: DateTime<Utc>,
}

impl Edge {
    /// Create a new edge between two nodes
    pub fn new(label: &str, source: Uuid, target: Uuid) -> Self {
        Self {
            id: Uuid::new_v4(),
            label: label.to_string(),
            source,
            target,
            properties: Vec::new(),
            created_at: Utc::now(),
        }
    }
    
    /// Add a property to the edge
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
    
    /// Check if the edge has a property with the given key
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
    }
    
    /// Remove a property by key
    pub fn remove_property(&mut self, key: &str) -> Option<Property> {
        let pos = self.properties.iter().position(|p| p.key == key)?;
        Some(self.properties.remove(pos))
    }
}

impl GraphElement for Edge {
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
    fn test_edge_creation() {
        let source = Uuid::new_v4();
        let target = Uuid::new_v4();
        let edge = Edge::new("TEST", source, target);
        
        assert_eq!(edge.label, "TEST");
        assert_eq!(edge.source, source);
        assert_eq!(edge.target, target);
        assert!(!edge.id.is_nil());
        assert!(edge.properties.is_empty());
    }
    
    #[test]
    fn test_edge_properties() {
        let source = Uuid::new_v4();
        let target = Uuid::new_v4();
        let mut edge = Edge::new("TEST", source, target)
            .with_property("weight", 1.0)
            .with_property("type", "test");
            
        assert_eq!(edge.properties.len(), 2);
        assert_eq!(edge.get_property("weight"), Some(&json!(1.0)));
        assert_eq!(edge.get_property("nonexistent"), None);
        
        edge.set_property("weight", 2.0);
        assert_eq!(edge.get_property("weight"), Some(&json!(2.0)));
        
        edge.set_property("new", true);
        assert_eq!(edge.get_property("new"), Some(&json!(true)));
        
        assert!(edge.remove_property("weight").is_some());
        assert_eq!(edge.properties.len(), 2);
    }
}
