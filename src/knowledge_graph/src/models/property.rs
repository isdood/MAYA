//! Property model for graph elements

use super::*;
use serde::{Serialize, Deserialize};

/// A property is a key-value pair that can be attached to nodes and edges
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Property {
    /// Property key
    pub key: String,
    
    /// Property value (must be JSON-serializable)
    pub value: PropertyValue,
}

impl Property {
    /// Create a new property
    pub fn new(key: &str, value: impl Into<PropertyValue>) -> Self {
        Self {
            key: key.to_string(),
            value: value.into(),
        }
    }
    
    /// Get the property key
    pub fn key(&self) -> &str {
        &self.key
    }
    
    /// Get a reference to the property value
    pub fn value(&self) -> &PropertyValue {
        &self.value
    }
    
    /// Get a mutable reference to the property value
    pub fn value_mut(&mut self) -> &mut PropertyValue {
        &mut self.value
    }
    
    /// Convert the property into its key and value
    pub fn into_parts(self) -> (String, PropertyValue) {
        (self.key, self.value)
    }
}

impl PartialEq<&str> for Property {
    fn eq(&self, other: &&str) -> bool {
        self.key == *other
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    
    #[test]
    fn test_property_creation() {
        let prop = Property::new("test", 42);
        
        assert_eq!(prop.key, "test");
        assert_eq!(prop.value, json!(42));
    }
    
    #[test]
    fn test_property_eq() {
        let prop = Property::new("test", 42);
        assert_eq!(prop, "test");
    }
    
    #[test]
    fn test_property_into_parts() {
        let prop = Property::new("test", 42);
        let (key, value) = prop.into_parts();
        
        assert_eq!(key, "test");
        assert_eq!(value, json!(42));
    }
}
