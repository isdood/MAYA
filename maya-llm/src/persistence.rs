//! Data persistence for the MAYA LLM

use serde::{Serialize, Deserialize};
use std::fs::File;
use std::io::{self, Read};
use std::path::Path;
use std::collections::HashMap;

use crate::pattern::PatternMatcher;
use crate::response::ResponseContext;
use crate::memory::MemoryBank;

/// Represents the complete state of the LLM that needs to be persisted
#[derive(Debug, Serialize, Deserialize)]
pub struct PersistentState {
    /// The pattern matcher with all learned patterns
    pub pattern_matcher: PatternMatcher,
    /// The current conversation context
    pub context: ResponseContext,
    /// The model's name
    pub model_name: String,
    /// The memory bank with all stored memories
    pub memory_bank: MemoryBank,
    /// Configuration settings
    pub settings: HashMap<String, String>,
}

/// A wrapper around the LLM state that can be easily serialized/deserialized
#[derive(Debug)]
pub struct SerializableLLM {
    pub pattern_matcher: PatternMatcher,
    pub context: ResponseContext,
    pub model_name: String,
    pub memory_bank: MemoryBank,
    pub settings: HashMap<String, String>,
}

/// Error type for persistence operations
#[derive(Debug)]
pub enum PersistenceError {
    IoError(io::Error),
    SerializationError(serde_json::Error),
    DeserializationError(serde_json::Error),
}

impl std::fmt::Display for PersistenceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            PersistenceError::IoError(e) => write!(f, "IO error: {}", e),
            PersistenceError::SerializationError(e) => write!(f, "Serialization error: {}", e),
            PersistenceError::DeserializationError(e) => write!(f, "Deserialization error: {}", e),
        }
    }
}

impl std::error::Error for PersistenceError {}

impl From<io::Error> for PersistenceError {
    fn from(err: io::Error) -> Self {
        PersistenceError::IoError(err)
    }
}

impl From<serde_json::Error> for PersistenceError {
    fn from(err: serde_json::Error) -> Self {
        PersistenceError::SerializationError(err)
    }
}

/// Saves the current state to a file
pub fn save_state<P: AsRef<Path>>(
    path: P,
    pattern_matcher: &PatternMatcher,
    context: &ResponseContext,
    memory_bank: &MemoryBank,
    model_name: &str,
    settings: Option<HashMap<String, String>>,
) -> Result<(), PersistenceError> {
    let state = PersistentState {
        pattern_matcher: pattern_matcher.clone(),
        context: context.clone(),
        memory_bank: memory_bank.clone(),
        model_name: model_name.to_string(),
        settings: settings.unwrap_or_default(),
    };

    // Create a temporary file for atomic write
    let path_ref = path.as_ref();
    let temp_path = path_ref.with_extension("tmp");
    
    // Write to temp file first
    let mut file = std::fs::File::create(&temp_path).map_err(PersistenceError::IoError)?;
    serde_json::to_writer_pretty(&mut file, &state).map_err(PersistenceError::SerializationError)?;
    file.sync_all().map_err(PersistenceError::IoError)?;
    
    // Atomically rename the temp file to the target file
    std::fs::rename(&temp_path, path_ref).map_err(PersistenceError::IoError)?;
    
    // Ensure directory entries are updated
    if let Some(parent) = path_ref.parent() {
        let _ = std::fs::File::open(parent)?.sync_all().map_err(PersistenceError::IoError)?;
    }
    
    Ok(())
}

/// Loads the state from a file
pub fn load_state<P: AsRef<Path>>(path: P) -> Result<SerializableLLM, PersistenceError> {
    // Try to open the file
    let mut file = File::open(&path).map_err(|e| {
        PersistenceError::IoError(io::Error::new(
            io::ErrorKind::NotFound,
            format!("Failed to open state file: {}", e),
        ))
    })?;
    
    // Read the file contents
    let mut contents = String::new();
    file.read_to_string(&mut contents).map_err(|e| {
        PersistenceError::IoError(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("Failed to read state file: {}", e),
        ))
    })?;
    
    // Deserialize the state
    let state: PersistentState = serde_json::from_str(&contents)
        .map_err(|e| PersistenceError::DeserializationError(e))?;
    
    Ok(SerializableLLM {
        pattern_matcher: state.pattern_matcher,
        context: state.context,
        memory_bank: state.memory_bank,
        model_name: state.model_name,
        settings: state.settings,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use tempfile::tempdir;
    use crate::memory::MemoryType;
    
    #[test]
    fn test_save_and_load_state() {
        let temp_dir = tempdir().unwrap();
        let file_path = temp_dir.path().join("test_state.json");
        
        // Create a pattern matcher with some patterns
        let mut pattern_matcher = PatternMatcher::new();
        pattern_matcher.add_pattern("hello", "Hi there!");
        pattern_matcher.add_pattern("how are you", "I'm doing well, thanks!");
        
        // Create a context with some previous messages
        let mut context = ResponseContext::default();
        context.add_previous_message("Hello, world!");
        
        // Test memory bank persistence
        let mut memory_bank = MemoryBank::new();
        let _memory_id = memory_bank.remember(
            "User's name is Alice",
            MemoryType::UserDetail,
            0.9,  // importance
            0.8,  // confidence
            Some(vec![("key".to_string(), "value".to_string())].into_iter().collect()),
        );
        
        // Test recall
        let results = memory_bank.recall_memories("Alice");
        assert!(!results.is_empty(), "Should find the memory about Alice");
        
        // Add some settings
        let mut settings = HashMap::new();
        settings.insert("version".to_string(), "1.0.0".to_string());
        
        // Save state
        save_state(
            &file_path, 
            &pattern_matcher, 
            &context, 
            &memory_bank,
            "test-model",
            Some(settings.clone())
        ).expect("Failed to save state");
            
        // Load state
        let loaded = load_state(&file_path).expect("Failed to load state");
        
        // Verify loaded data
        assert_eq!(loaded.model_name, "test-model");
        assert_eq!(loaded.context.previous_messages[0], "Hello, world!");
        assert!(!loaded.pattern_matcher.patterns.is_empty());
        assert_eq!(loaded.memory_bank.len(), 1);
        assert_eq!(loaded.settings.get("version"), Some(&"1.0.0".to_string()));
        
        // Verify memory content
        let memories = loaded.memory_bank.recall_memories("Alice");
        assert!(!memories.is_empty(), "Should find memory about Alice");
        
        // Get the memory by ID to check metadata
        if let Some(memory) = loaded.memory_bank.get_memory(0) {
            assert_eq!(memory.content, "User's name is Alice");
            assert_eq!(memory.metadata.get("key"), Some(&"value".to_string()));
        } else {
            panic!("Memory not found by ID");
        }
    }
}
