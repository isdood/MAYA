//! Memory system for the MAYA LLM

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Represents a single memory entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Memory {
    pub content: String,
    pub memory_type: MemoryType,
    pub timestamp: DateTime<Utc>,
    pub importance: f32,
    pub metadata: HashMap<String, String>,
}

/// Different types of memories the system can store
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MemoryType {
    Fact,
    Preference,
    Event,
    Relationship,
    UserDetail,
    Custom(String),
}

/// Manages the LLM's memory
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct MemoryBank {
    memories: Vec<Memory>,
    max_memories: usize,
    importance_threshold: f32,
}

impl MemoryBank {
    /// Create a new MemoryBank with default settings
    pub fn new() -> Self {
        Self {
            memories: Vec::new(),
            max_memories: 1000,
            importance_threshold: 0.3,
        }
    }

    /// Add a new memory
    pub fn add_memory<T: Into<String>>(
        &mut self,
        content: T,
        memory_type: MemoryType,
        importance: f32,
        metadata: Option<HashMap<String, String>>,
    ) {
        if importance < self.importance_threshold {
            return; // Skip low-importance memories
        }

        let memory = Memory {
            content: content.into(),
            memory_type,
            timestamp: Utc::now(),
            importance: importance.min(1.0).max(0.0), // Clamp between 0 and 1
            metadata: metadata.unwrap_or_default(),
        };

        self.memories.push(memory);
        self.cleanup();
    }

    /// Get relevant memories based on a query
    pub fn recall<T: AsRef<str>>(&self, query: T) -> Vec<&Memory> {
        let query = query.as_ref().to_lowercase();
        let mut relevant = Vec::new();

        for memory in &self.memories {
            if memory.content.to_lowercase().contains(&query) {
                relevant.push(memory);
            }
        }

        // Sort by importance and then by recency
        relevant.sort_by(|a, b| {
            b.importance
                .partial_cmp(&a.importance)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then(b.timestamp.cmp(&a.timestamp))
        });

        relevant
    }

    /// Remove old or unimportant memories when we reach capacity
    fn cleanup(&mut self) {
        if self.memories.len() <= self.max_memories {
            return;
        }

        // Sort by importance (descending) and then by age (newest first)
        self.memories.sort_by(|a, b| {
            b.importance
                .partial_cmp(&a.importance)  // Note: b before a for descending order
                .unwrap_or(std::cmp::Ordering::Equal)
                .then(b.timestamp.cmp(&a.timestamp))  // Newest first
        });

        // Keep the most important/newest memories
        self.memories.truncate(self.max_memories / 2);
    }

    /// Get all memories of a specific type
    pub fn get_memories_by_type(&self, memory_type: &MemoryType) -> Vec<&Memory> {
        self.memories
            .iter()
            .filter(|m| &m.memory_type == memory_type)
            .collect()
    }

    /// Get the number of stored memories
    pub fn len(&self) -> usize {
        self.memories.len()
    }

    /// Check if the memory bank is empty
    pub fn is_empty(&self) -> bool {
        self.memories.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add_and_recall_memory() {
        let mut memory_bank = MemoryBank::new();
        
        // Add some memories
        memory_bank.add_memory(
            "User's favorite color is blue",
            MemoryType::Preference,
            0.9,
            None,
        );
        
        memory_bank.add_memory(
            "User has a dog named Max",
            MemoryType::Fact,
            0.8,
            None,
        );

        // Test recall
        let results = memory_bank.recall("color");
        assert_eq!(results.len(), 1);
        assert!(results[0].content.contains("blue"));
        
        // Test importance sorting
        memory_bank.add_memory(
            "User's favorite food is pizza",
            MemoryType::Preference,
            0.5,
            None,
        );
        
        let results = memory_bank.recall("favorite");
        assert_eq!(results.len(), 2);
        assert!(results[0].content.contains("color")); // Higher importance
        assert!(results[1].content.contains("food"));
    }

    #[test]
    fn test_cleanup() {
        let mut memory_bank = MemoryBank {
            max_memories: 3, // Small limit for testing
            ..Default::default()
        };

        // Add memories with varying importance
        memory_bank.add_memory("Important", MemoryType::Fact, 0.9, None);
        memory_bank.add_memory("Medium", MemoryType::Fact, 0.6, None);
        memory_bank.add_memory("Low", MemoryType::Fact, 0.3, None);
        
        // Add one more to trigger cleanup (now we have 4, which is > max_memories)
        memory_bank.add_memory("Very Low", MemoryType::Fact, 0.1, None);
        
        // After cleanup, we should have max_memories/2 memories (3/2 = 1.5, rounded down to 1)
        assert_eq!(memory_bank.len(), 1, "Should have 1 memory after cleanup");
        
        // Get all memories to check which ones are still there
        let all_memories: Vec<_> = memory_bank.recall("");
        assert_eq!(all_memories.len(), 1, "Should only have one memory remaining");
        
        // The remaining memory should be the most important one
        assert!(
            all_memories[0].content.contains("Important"),
            "The most important memory should be kept. Got: {}",
            all_memories[0].content
        );
    }
}
