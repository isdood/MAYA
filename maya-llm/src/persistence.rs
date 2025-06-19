//! Data persistence for the MAYA LLM

use serde::{Serialize, Deserialize};
use std::fs::{File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::Path;
use std::error::Error;
use std::fmt;
use std::rc::Rc;
use std::cell::RefCell;

use crate::pattern::PatternMatcher;
use crate::response::ResponseContext;

/// Represents the complete state of the LLM that needs to be persisted
#[derive(Debug, Serialize, Deserialize)]
pub struct PersistentState {
    /// The pattern matcher with all learned patterns
    pub pattern_matcher: PatternMatcher,
    /// The current conversation context
    pub context: ResponseContext,
    /// The model's name
    pub model_name: String,
}

/// A wrapper around the LLM state that can be easily serialized/deserialized
#[derive(Debug)]
pub struct SerializableLLM {
    pub pattern_matcher: PatternMatcher,
    pub context: ResponseContext,
    pub model_name: String,
}

/// Error type for persistence operations
#[derive(Debug)]
pub enum PersistenceError {
    IoError(io::Error),
    SerializationError(serde_json::Error),
}

impl fmt::Display for PersistenceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PersistenceError::IoError(e) => write!(f, "IO error: {}", e),
            PersistenceError::SerializationError(e) => write!(f, "Serialization error: {}", e),
        }
    }
}

impl Error for PersistenceError {}

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
    pattern_matcher: &Rc<RefCell<PatternMatcher>>,
    context: &ResponseContext,
    model_name: &str,
) -> Result<(), PersistenceError> {
    // Create a new PatternMatcher with the same data
    let pattern_matcher_data = pattern_matcher.borrow();
    let mut new_pattern_matcher = PatternMatcher::new()
        .with_learning_rate(pattern_matcher_data.learning_rate)
        .with_max_patterns(pattern_matcher_data.max_patterns);
        
    // Clone all patterns
    for pattern in &pattern_matcher_data.patterns {
        new_pattern_matcher.add_pattern(&pattern.text, &pattern.response);
    }
    
    let state = PersistentState {
        pattern_matcher: new_pattern_matcher,
        context: context.clone(),
        model_name: model_name.to_string(),
    };

    let json = serde_json::to_string_pretty(&state)?;
    
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(path)?;
    
    file.write_all(json.as_bytes())?;
    file.sync_all()?;
    
    Ok(())
}

/// Loads the state from a file
pub fn load_state<P: AsRef<Path>>(path: P) -> Result<SerializableLLM, PersistenceError> {
    let mut file = File::open(path)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;
    
    let state: PersistentState = serde_json::from_str(&contents)?;
    
    Ok(SerializableLLM {
        pattern_matcher: state.pattern_matcher,
        context: state.context,
        model_name: state.model_name,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;
    
    #[test]
    fn test_save_and_load_state() {
        // Create a temporary directory for testing
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test_state.json");
        
        // Create test data
        let mut pattern_matcher = PatternMatcher::new();
        pattern_matcher.add_pattern("test", "test response");
        let context = ResponseContext::new();
        let model_name = "test_model".to_string();
        
        // Wrap the pattern matcher in Rc<RefCell<>> for the test
        let pattern_matcher_rc = Rc::new(RefCell::new(pattern_matcher));
        
        // Test saving
        save_state(&file_path, &pattern_matcher_rc, &context, &model_name).unwrap();
        
        // Verify file exists
        assert!(file_path.exists());
        
        // Test loading
        let loaded = load_state(&file_path).unwrap();
        
        // Verify loaded data
        assert_eq!(loaded.model_name, model_name);
        assert_eq!(loaded.context, context);
        // Check the pattern count
        assert_eq!(loaded.pattern_matcher.get_patterns().len(), 1);
    }
}
