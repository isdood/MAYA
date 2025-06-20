@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-19 14:43:09",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./maya-llm/src/memory.rs",
    "type": "rs",
    "hash": "957145bb4379be4ecea33f68a74fbcdca22b862f"
  }
}
@pattern_meta@

//! Memory system for the MAYA LLM

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fmt;
use std::str::FromStr;

/// Represents a relationship between two memories
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryLink {
    pub target_id: usize,
    pub relationship: MemoryRelationship,
    pub strength: f32,  // 0.0 to 1.0 indicating relationship strength
}

/// Represents a single memory entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Memory {
    /// The actual content of the memory
    pub content: String,
    
    /// The type/category of the memory
    pub memory_type: MemoryType,
    
    /// When the memory was created
    pub created_at: DateTime<Utc>,
    
    /// Last time this memory was accessed or modified
    pub last_accessed: DateTime<Utc>,
    
    /// Importance score (0.0 to 1.0)
    pub importance: f32,
    
    /// Confidence in the memory (0.0 to 1.0)
    pub confidence: f32,
    
    /// Additional metadata
    pub metadata: HashMap<String, String>,
    
    /// Relationships to other memories
    #[serde(default)]
    pub relationships: Vec<MemoryLink>,
    
    /// Whether this memory should be kept even if it's old/unimportant
    #[serde(default)]
    pub pinned: bool,
}

/// Different types of memories the system can store
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum MemoryType {
    // Core memory types
    Fact,
    Preference,
    Event,
    Relationship,
    UserDetail,
    
    // More specific memory types
    Task,
    Goal,
    Belief,
    Opinion,
    Experience,
    
    // System and internal types
    System,
    
    // Custom type for user-defined categories
    Custom(String),
}

impl FromStr for MemoryType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "fact" => Ok(MemoryType::Fact),
            "preference" => Ok(MemoryType::Preference),
            "event" => Ok(MemoryType::Event),
            "relationship" => Ok(MemoryType::Relationship),
            "userdetail" | "user_detail" | "user" => Ok(MemoryType::UserDetail),
            "task" => Ok(MemoryType::Task),
            "goal" => Ok(MemoryType::Goal),
            "belief" => Ok(MemoryType::Belief),
            "opinion" => Ok(MemoryType::Opinion),
            "experience" => Ok(MemoryType::Experience),
            "system" => Ok(MemoryType::System),
            custom => Ok(MemoryType::Custom(custom.to_string())),
        }
    }
}

impl fmt::Display for MemoryType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MemoryType::Fact => write!(f, "fact"),
            MemoryType::Preference => write!(f, "preference"),
            MemoryType::Event => write!(f, "event"),
            MemoryType::Relationship => write!(f, "relationship"),
            MemoryType::UserDetail => write!(f, "user_detail"),
            MemoryType::Task => write!(f, "task"),
            MemoryType::Goal => write!(f, "goal"),
            MemoryType::Belief => write!(f, "belief"),
            MemoryType::Opinion => write!(f, "opinion"),
            MemoryType::Experience => write!(f, "experience"),
            MemoryType::System => write!(f, "system"),
            MemoryType::Custom(s) => write!(f, "{}", s),
        }
    }
}

/// Types of relationships between memories
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum MemoryRelationship {
    // Hierarchical relationships
    ParentOf,
    ChildOf,
    
    // Temporal relationships
    HappenedBefore,
    HappenedAfter,
    
    // Causal relationships
    CausedBy,
    Caused,
    
    // Semantic relationships
    RelatedTo,
    SimilarTo,
    OppositeOf,
    
    // Task relationships
    PartOf,
    DependsOn,
    
    // Custom relationship type
    Custom(String),
}

impl FromStr for MemoryRelationship {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "parentof" | "parent_of" | "parent" | "hierarchical" => Ok(MemoryRelationship::ParentOf),
            "childof" | "child_of" | "child" => Ok(MemoryRelationship::ChildOf),
            "happenedbefore" | "happened_before" | "before" | "temporal" => Ok(MemoryRelationship::HappenedBefore),
            "happenedafter" | "happened_after" | "after" => Ok(MemoryRelationship::HappenedAfter),
            "causedby" | "caused_by" => Ok(MemoryRelationship::CausedBy),
            "caused" | "causes" => Ok(MemoryRelationship::Caused),
            "relatedto" | "related_to" | "related" => Ok(MemoryRelationship::RelatedTo),
            "similarto" | "similar_to" | "similar" => Ok(MemoryRelationship::SimilarTo),
            "oppositeof" | "opposite_of" | "opposite" => Ok(MemoryRelationship::OppositeOf),
            "partof" | "part_of" | "part" => Ok(MemoryRelationship::PartOf),
            "dependson" | "depends_on" | "depends" => Ok(MemoryRelationship::DependsOn),
            custom => Ok(MemoryRelationship::Custom(custom.to_string())),
        }
    }
}

impl fmt::Display for MemoryRelationship {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MemoryRelationship::ParentOf => write!(f, "parent_of"),
            MemoryRelationship::ChildOf => write!(f, "child_of"),
            MemoryRelationship::HappenedBefore => write!(f, "happened_before"),
            MemoryRelationship::HappenedAfter => write!(f, "happened_after"),
            MemoryRelationship::CausedBy => write!(f, "caused_by"),
            MemoryRelationship::Caused => write!(f, "caused"),
            MemoryRelationship::RelatedTo => write!(f, "related_to"),
            MemoryRelationship::SimilarTo => write!(f, "similar_to"),
            MemoryRelationship::OppositeOf => write!(f, "opposite_of"),
            MemoryRelationship::PartOf => write!(f, "part_of"),
            MemoryRelationship::DependsOn => write!(f, "depends_on"),
            MemoryRelationship::Custom(s) => write!(f, "{}", s),
        }
    }
}

/// Manages the LLM's memory
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct MemoryBank {
    memories: Vec<Memory>,
    max_memories: usize,
    importance_threshold: f32,
}

impl Memory {
    /// Create a new memory with default values
    pub fn new<T: Into<String>>(content: T, memory_type: MemoryType) -> Self {
        let now = Utc::now();
        Self {
            content: content.into(),
            memory_type,
            created_at: now,
            last_accessed: now,
            importance: 0.5,  // Default medium importance
            confidence: 0.8,  // Start with high confidence
            metadata: HashMap::new(),
            relationships: Vec::new(),
            pinned: false,
        }
    }

    /// Update the last_accessed timestamp to now
    pub fn touch(&mut self) {
        self.last_accessed = Utc::now();
    }

    /// Add a relationship to another memory
    pub fn add_relationship(&mut self, target_id: usize, relationship: MemoryRelationship, strength: f32) {
        // Don't allow self-references
        if target_id == self as *const _ as usize {
            return;
        }
        
        let link = MemoryLink {
            target_id,
            relationship: relationship.clone(),
            strength: strength.clamp(0.0, 1.0),
        };
        
        // Update existing relationship if it exists, otherwise add new
        let relationship_clone = relationship;
        if let Some(existing) = self.relationships.iter_mut()
            .find(|r| r.target_id == target_id && r.relationship == relationship_clone) {
            existing.strength = strength.clamp(0.0, 1.0);
        } else {
            self.relationships.push(link);
        }
    }
    
    /// Remove a relationship to another memory
    pub fn remove_relationship(&mut self, target_id: usize, relationship: &MemoryRelationship) -> bool {
        if let Some(pos) = self.relationships.iter().position(|r| r.target_id == target_id && &r.relationship == relationship) {
            self.relationships.remove(pos);
            true
        } else {
            false
        }
    }
    
    /// Check if the memory is empty (deleted)
    pub fn is_empty(&self) -> bool {
        self.content.is_empty() && self.importance == 0.0 && self.confidence == 0.0
    }
}

impl Default for Memory {
    fn default() -> Self {
        Self::new("", MemoryType::Fact)
    }
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

    /// Add a new memory and return its ID
    pub fn add_memory(&mut self, memory: Memory) -> usize {
        let id = self.memories.len();
        self.memories.push(memory);
        self.cleanup();
        id
    }
    
    /// Create and add a new memory with the given content and type
    pub fn remember<T: Into<String>>(
        &mut self,
        content: T,
        memory_type: MemoryType,
        importance: f32,
        confidence: f32,
        metadata: Option<HashMap<String, String>>,
    ) -> usize {
        let mut memory = Memory::new(content, memory_type);
        memory.importance = importance.clamp(0.0, 1.0);
        memory.confidence = confidence.clamp(0.0, 1.0);
        
        if let Some(meta) = metadata {
            memory.metadata = meta;
        }
        
        self.add_memory(memory)
    }
    
    /// Get a memory by ID (mutable)
    pub fn get_memory_mut(&mut self, id: usize) -> Option<&mut Memory> {
        self.memories.get_mut(id)
    }
    
    /// Get a memory by ID (immutable)
    pub fn get_memory(&self, id: usize) -> Option<&Memory> {
        self.memories.get(id)
    }
    
    /// Update a memory's content and metadata
    pub fn update_memory<T: Into<String>>(
        &mut self,
        id: usize,
        content: Option<T>,
        importance: Option<f32>,
        confidence: Option<f32>,
        metadata: Option<HashMap<String, String>>,
    ) -> bool {
        if let Some(memory) = self.get_memory_mut(id) {
            if let Some(content) = content {
                memory.content = content.into();
            }
            if let Some(imp) = importance {
                memory.importance = imp.clamp(0.0, 1.0);
            }
            if let Some(conf) = confidence {
                memory.confidence = conf.clamp(0.0, 1.0);
            }
            if let Some(meta) = metadata {
                memory.metadata = meta;
            }
            memory.touch();
            true
        } else {
            false
        }
    }

    /// Get relevant memories based on a query
    pub fn recall_memories(&self, query: &str) -> Vec<String> {
        self.search(query)
            .into_iter()
            .map(|(_, mem, _)| mem.content.clone())
            .collect()
    }

    /// Clean up less important memories when we reach capacity
    fn cleanup(&mut self) {
        if self.memories.len() > self.max_memories {
            // First, sort by pinned status (pinned first), then by importance, then by last accessed
            self.memories.sort_by(|a, b| {
                b.pinned.cmp(&a.pinned)
                    .then(b.importance.partial_cmp(&a.importance).unwrap_or(std::cmp::Ordering::Equal))
                    .then(b.last_accessed.cmp(&a.last_accessed))
            });
            
            // Keep only the most important memories, but never remove pinned ones
            let pinned_count = self.memories.iter().filter(|m| m.pinned).count();
            let to_keep = std::cmp::max(self.max_memories, pinned_count);
            
            // Remove unpinned memories that exceed the limit
            self.memories.truncate(to_keep);
            
            // Rebuild any indexes or caches if needed
            self.rebuild_indexes();
        }
    }
    
    /// Rebuild any internal indexes (placeholder for future use)
    fn rebuild_indexes(&mut self) {
        // This can be implemented to maintain secondary indexes for faster lookups
    }
    
    /// Find memories by type
    pub fn find_by_type(&self, memory_type: &MemoryType) -> Vec<&Memory> {
        self.memories
            .iter()
            .filter(|m| &m.memory_type == memory_type)
            .collect()
    }
    
    /// Find memories matching a query string
    pub fn search(&self, query: &str) -> Vec<(usize, &Memory, f32)> {
        // Simple implementation - could be enhanced with more sophisticated search
        let query = query.to_lowercase();
        self.memories
            .iter()
            .enumerate()
            .filter_map(|(id, mem)| {
                let score = if mem.content.to_lowercase().contains(&query) {
                    // Simple relevance scoring - could be enhanced
                    let content = mem.content.to_lowercase();
                    let matches = content.matches(&query).count() as f32;
                    let position = content.find(&query).unwrap_or(0) as f32;
                    
                    // Higher score for earlier matches and more matches
                    (1.0 / (position + 1.0)) * (1.0 + matches * 0.5)
                } else {
                    0.0
                };
                
                if score > 0.0 {
                    Some((id, mem, score * mem.importance * mem.confidence))
                } else {
                    None
                }
            })
            .collect()
    }

    /// Get all memories of a specific type
    pub fn get_memories_by_type(&self, memory_type: MemoryType) -> Vec<&Memory> {
        self.memories
            .iter()
            .filter(|m| m.memory_type == memory_type)
            .collect()
    }
    
    /// Get memories related to a specific memory
    pub fn get_related_memories(&self, memory_id: usize, min_strength: f32) -> Vec<(usize, &Memory, &MemoryRelationship, f32)> {
        let mut related = Vec::new();
        
        if let Some(memory) = self.memories.get(memory_id) {
            for link in &memory.relationships {
                if link.strength >= min_strength {
                    if let Some(related_mem) = self.memories.get(link.target_id) {
                        related.push((link.target_id, related_mem, &link.relationship, link.strength));
                    }
                }
            }
        }
        
        // Sort by strength (highest first)
        related.sort_by(|a, b| b.3.partial_cmp(&a.3).unwrap_or(std::cmp::Ordering::Equal));
        related
    }

    /// Get the number of stored memories
    pub fn len(&self) -> usize {
        self.memories.len()
    }
    
    /// Check if the memory bank is empty
    pub fn is_empty(&self) -> bool {
        self.memories.is_empty()
    }
    
    /// Delete a memory by ID
    pub fn delete(&mut self, id: usize) -> bool {
        if id < self.memories.len() {
            // Mark the memory as deleted by setting its content to empty string
            // This preserves the ID space while effectively removing the content
            if let Some(memory) = self.memories.get_mut(id) {
                memory.content = String::new();
                memory.importance = 0.0;
                memory.confidence = 0.0;
                memory.metadata.clear();
                memory.relationships.clear();
                memory.pinned = false;
                return true;
            }
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn create_test_memory(content: &str, memory_type: MemoryType, importance: f32) -> Memory {
        Memory {
            content: content.to_string(),
            memory_type,
            created_at: Utc::now(),
            last_accessed: Utc::now(),
            importance,
            confidence: 0.9,
            metadata: HashMap::new(),
            relationships: Vec::new(),
            pinned: false,
        }
    }

    #[test]
    fn test_add_and_recall_memory() {
        let mut memory_bank = MemoryBank::new();
        
        // Add some memories
        let alice_id = memory_bank.add_memory(create_test_memory(
            "User's name is Alice", 
            MemoryType::UserDetail, 
            0.9
        ));
        
        let choco_id = memory_bank.add_memory(create_test_memory(
            "User likes chocolate", 
            MemoryType::Preference, 
            0.7
        ));
        
        // Add a relationship
        memory_bank.get_memory_mut(alice_id).unwrap()
            .add_relationship(choco_id, MemoryRelationship::RelatedTo, 0.8);
        
        // Test recall
        let results = memory_bank.recall_memories("chocolate");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0], "User likes chocolate");
        
        // Test relationship lookup
        let related = memory_bank.get_related_memories(alice_id, 0.5);
        assert_eq!(related.len(), 1);
        assert_eq!(related[0].1.content, "User likes chocolate");
    }
    
    #[test]
    fn test_memory_relationships() {
        let mut memory_bank = MemoryBank::new();
        
        // Create related memories
        let task_id = memory_bank.add_memory(create_test_memory(
            "Complete project documentation",
            MemoryType::Task,
            0.8
        ));
        
        let subtask_id = memory_bank.add_memory(create_test_memory(
            "Write API documentation",
            MemoryType::Task,
            0.6
        ));
        
        // Add parent-child relationship
        memory_bank.get_memory_mut(task_id).unwrap()
            .add_relationship(subtask_id, MemoryRelationship::ParentOf, 0.9);
            
        memory_bank.get_memory_mut(subtask_id).unwrap()
            .add_relationship(task_id, MemoryRelationship::ChildOf, 0.9);
        
        // Verify relationships
        let children = memory_bank.get_related_memories(task_id, 0.5);
        assert_eq!(children.len(), 1);
        assert_eq!(children[0].1.content, "Write API documentation");
        assert!(matches!(children[0].2, MemoryRelationship::ParentOf));
        
        let parents = memory_bank.get_related_memories(subtask_id, 0.5);
        assert_eq!(parents.len(), 1);
        assert_eq!(parents[0].1.content, "Complete project documentation");
        assert!(matches!(parents[0].2, MemoryRelationship::ChildOf));
    }
    
    #[test]
    fn test_cleanup_preserves_pinned() {
        let mut memory_bank = MemoryBank {
            memories: Vec::new(),
            max_memories: 2,
            importance_threshold: 0.0,
        };
        
        // Add memories including one that's pinned
        memory_bank.add_memory(create_test_memory("Important memory", MemoryType::Fact, 0.9));
        
        let pinned_mem = memory_bank.add_memory(create_test_memory(
            "Pinned memory", 
            MemoryType::Fact, 
            0.5
        ));
        
        // Pin the second memory
        memory_bank.get_memory_mut(pinned_mem).unwrap().pinned = true;
        
        // Add more memories to trigger cleanup
        memory_bank.add_memory(create_test_memory("New memory 1", MemoryType::Fact, 0.8));
        memory_bank.add_memory(create_test_memory("New memory 2", MemoryType::Fact, 0.7));
        
        // Verify pinned memory is still there
        let memories: Vec<_> = memory_bank.memories.iter().map(|m| &m.content[..]).collect();
        assert!(memories.contains(&"Pinned memory"), "Pinned memory should be preserved");
        assert_eq!(memory_bank.memories.len(), 2, "Should have exactly 2 memories");
        
        // The remaining memories should be the pinned one and the most important one
        let has_pinned = memory_bank.memories.iter().any(|m| m.pinned);
        assert!(has_pinned, "Pinned memory should be in the remaining memories");
        
        let has_important = memory_bank.memories.iter().any(|m| m.importance == 0.9);
        assert!(has_important, "Most important memory should be preserved");
    }
}
