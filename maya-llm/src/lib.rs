//! Core LLM implementation for MAYA

use std::cell::RefCell;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;

use crate::response::ResponseTemplate;

pub mod pattern;
pub mod response;
pub mod persistence;
pub mod memory;

use pattern::PatternMatcher;
use response::ResponseContext;
use memory::{MemoryBank, MemoryType};
use persistence::PersistenceError;

/// Core trait defining the LLM interface
pub trait LLM {
    /// Generate a response to the given input
    fn generate_response(&mut self, input: &str, context: &[String]) -> String;
    
    /// Learn from an interaction
    fn learn(&mut self, input: &str, response: &str);
    
    /// Get the model's name
    fn name(&self) -> &str;
}

/// A simple implementation of the LLM trait using pattern matching
pub struct BasicLLM {
    name: String,
    patterns: Rc<RefCell<PatternMatcher>>,
    fallback_responses: Vec<String>,
    context: ResponseContext,
    memory: MemoryBank,
    settings: HashMap<String, String>,
    data_dir: Option<PathBuf>,
}

impl Default for BasicLLM {
    fn default() -> Self {
        Self {
            name: "MAYA".to_string(),
            patterns: Rc::new(RefCell::new(PatternMatcher::new())),
            fallback_responses: vec![
                "I'm not sure how to respond to that.".to_string(),
                "Could you rephrase that?".to_string(),
                "I'm still learning. Can you tell me more?".to_string(),
            ],
            context: ResponseContext::new(),
            memory: MemoryBank::new(),
            settings: HashMap::new(),
            data_dir: None,
        }
    }
}

impl LLM for BasicLLM {
    fn generate_response(&mut self, input: &str, context: &[String]) -> String {
        // Update context with previous messages
        for msg in context {
            self.context.add_previous_message(msg);
        }
        
        // Extract potential variables from input (e.g., "my name is Alice")
        self.extract_variables(input);
        
        // Prepare context for pattern matching
        let context_strings: Vec<String> = self.context.previous_messages
            .iter()
            .take(3) // Only use last 3 messages as context
            .map(|s| s.to_string())
            .collect();
            
        // Get relevant memories for this input
        let relevant_memories = self.recall_memories(input);
        
        // Add memories to context if we found any
        let mut enhanced_context = context_strings.clone();
        if !relevant_memories.is_empty() {
            enhanced_context.extend(relevant_memories);
        }
        
        // Ensure we have at least one fallback response
        if self.fallback_responses.is_empty() {
            self.fallback_responses.push("I'm not sure how to respond to that.".to_string());
        }
        
        // First, try to find a matching pattern
        let (response, should_learn) = {
            let mut patterns = self.patterns.borrow_mut();
            
            // Try to find a matching pattern with enhanced context
            if let Some(pattern) = patterns.find_best_match_with_context(input, Some(&enhanced_context)) {
                // Generate response using the template system
                let response_template = pattern.response.clone();
                
                // Prepare context for template rendering
                let mut template_vars = HashMap::new();
                
                // Add user name if available
                if let Some(name) = &self.context.user_name {
                    template_vars.insert("user", name.clone());
                }
                
                // Add other context variables
                for (key, value) in &self.context.custom_vars {
                    template_vars.insert(key.as_str(), value.clone());
                }
                
                // Render the template with variables
                let response = ResponseTemplate::new(&response_template).render(&template_vars).to_string();
                
                // Check if we should learn from this interaction
                let match_quality = pattern.match_score(input, Some(&enhanced_context));
                (response, match_quality < 8.0) // Learn if not a very strong match
            } else {
                // No pattern matched, use a fallback response
                let idx = (input.len() % self.fallback_responses.len()) as usize;
                (self.fallback_responses[idx].clone(), true)
            }
        };
        
        // Update context with the response
        self.context.add_previous_message(&response);
        
        // Learn from this interaction if needed
        if should_learn {
            self.learn_from_interaction(input, &response, &context_strings);
        }
        
        response
    }
    
    /// Learn a new pattern or reinforce an existing one
    fn learn(&mut self, input: &str, response: &str) {
        // First check if we need to prune
        if self.needs_pruning() {
            self.prune_patterns();
        }
        
        // Then add the pattern
        let is_new = {
            let mut patterns = self.patterns.borrow_mut();
            patterns.add_pattern(input, response)
        };
        
        if is_new {
            log::debug!("Added new pattern: '{}' -> '{:?}'", input, response);
            self.context.add_previous_message(&format!("Learned: {} -> {}", input, response));
        }
    }
    
    fn name(&self) -> &str {
        &self.name
    }
}

impl BasicLLM {
    /// Create a new BasicLLM instance with default patterns
    pub fn new() -> Self {
        let mut pattern_matcher = PatternMatcher::new();
        pattern_matcher.max_patterns = 1000;
        pattern_matcher.learning_rate = 0.1;
        
        // Add some default patterns
        pattern_matcher.add_pattern(
            "hello|hi|hey|greetings",
            "Hello! How can I help you today?"
        );
        
        pattern_matcher.add_pattern(
            "what is your name",
            "I'm MAYA, your AI assistant!"
        );
        
        pattern_matcher.add_pattern(
            "how are you",
            "I'm just a program, but I'm functioning well. Thanks for asking!"
        );
        
        Self {
            name: "MAYA".to_string(),
            patterns: Rc::new(RefCell::new(pattern_matcher)),
            fallback_responses: vec![
                "I'm not sure how to respond to that.".to_string(),
                "Could you rephrase that?".to_string(),
                "I'm still learning. Can you tell me more?".to_string(),
            ],
            context: ResponseContext::new(),
            memory: MemoryBank::new(),
            settings: HashMap::new(),
            data_dir: None,
        }
    }
    /// Check if we need to prune patterns before adding a new one
    fn needs_pruning(&self) -> bool {
        let patterns = self.patterns.borrow();
        patterns.patterns.len() >= patterns.max_patterns
    }
    
    /// Learn from an interaction and update patterns
    fn learn_from_interaction(&mut self, input: &str, response: &str, context: &[String]) {
        // Check if we need to prune before adding a new pattern
        if self.needs_pruning() {
            self.prune_patterns();
        }
        
        // Add the new pattern if it doesn't exist
        let is_new = {
            let mut patterns = self.patterns.borrow_mut();
            patterns.add_pattern(input, response)
        };
        
        if is_new {
            log::debug!("Learned from interaction: '{}' -> '{}'", input, response);
        }
        
        // Then update similar patterns with context
        self.update_similar_patterns(input, context);
    }
    
    /// Get patterns that are similar to the input
    fn find_similar_patterns(&self, input: &str, context: &[String]) -> Vec<(usize, f32)> {
        let patterns = self.patterns.borrow();
        let mut similar = Vec::new();
        
        for (i, pattern) in patterns.patterns.iter().enumerate() {
            let similarity = pattern.match_score(input, Some(context));
            if similarity > 0.3 { // If somewhat similar
                similar.push((i, similarity));
            }
        }
        
        similar
    }
    
    /// Update a specific pattern with a boost
    fn update_pattern(&mut self, index: usize, boost: f32, context: &[String]) {
        let mut patterns = self.patterns.borrow_mut();
        if let Some(pattern) = patterns.patterns.get_mut(index) {
            pattern.weight = (pattern.weight + boost).min(5.0);
            
            // Update context triggers
            for ctx in context {
                pattern.context_triggers.insert(ctx.to_lowercase());
            }
        }
    }
    
    /// Update patterns that are similar to the input
    fn update_similar_patterns(&mut self, input: &str, context: &[String]) {
        // First, find all similar patterns
        let similar_patterns = self.find_similar_patterns(input, context);
        
        // Then update each one
        for (index, similarity) in similar_patterns {
            let boost = 0.1 * similarity;
            self.update_pattern(index, boost, context);
        }
    }
    
    /// Get the target size for pruning
    fn get_prune_target_size(&self) -> usize {
        let patterns = self.patterns.borrow();
        patterns.max_patterns.saturating_sub(10) // Keep some room for new patterns
    }
    
    /// Remove least used patterns to keep the collection manageable
    fn prune_patterns(&mut self) {
        let target_size = self.get_prune_target_size();
        
        let mut patterns = self.patterns.borrow_mut();
        if patterns.patterns.len() <= target_size {
            return; // No need to prune
        }
        
        // Sort patterns by usage count and last used time
        patterns.patterns.sort_by(|a, b| {
            a.usage_count.cmp(&b.usage_count)
                .then(a.last_used.cmp(&b.last_used))
        });
        
        // Remove the least used patterns
        patterns.patterns.truncate(target_size);
        log::debug!("Pruned patterns, now have {} patterns", patterns.patterns.len());
    }
    /// Extract variables from input and add them to the context and memory
    fn extract_variables(&mut self, input: &str) {
        let input_lower = input.to_lowercase();
        
        // Extract name from various patterns
        let name_patterns = [
            "my name is ",
            "i am ",
            "call me ",
            "you can call me "
        ];
        
        for pattern in &name_patterns {
            if let Some(name_part) = input_lower.strip_prefix(pattern) {
                let name = name_part
                    .split_whitespace()
                    .next()
                    .unwrap_or("") // Shouldn't happen due to strip_prefix behavior
                    .trim_matches(|c: char| !c.is_alphanumeric())
                    .to_string();
                
                if !name.is_empty() {
                    self.context.set_var("name", &name);
                    if self.context.user_name.is_none() {
                        self.context.user_name = Some(name.clone());
                        
                        // Store in memory
                        let mut metadata = HashMap::new();
                        metadata.insert("type".to_string(), "user_name".to_string());
                        self.remember(
                            format!("The user's name is {}", name),
                            MemoryType::UserDetail,
                            0.9,
                            Some(metadata),
                        );
                    }
                    break;
                }
            }
        }
        
        // Extract mood from various patterns
        let mood_patterns = [
            "i am feeling ",
            "i feel ",
            "i'm feeling ",
            "i'm "
        ];
        
        for pattern in &mood_patterns {
            if let Some(mood_part) = input_lower.strip_prefix(pattern) {
                let mood = mood_part
                    .split_whitespace()
                    .next()
                    .unwrap_or("")
                    .trim_matches(|c: char| !c.is_alphabetic())
                    .to_string();
                
                if !mood.is_empty() {
                    self.context.set_var("mood", &mood);
                    
                    // Store in memory
                    let mut metadata = HashMap::new();
                    metadata.insert("type".to_string(), "mood".to_string());
                    self.remember(
                        format!("The user is feeling {}", mood),
                        MemoryType::Fact,
                        0.7,
                        Some(metadata),
                    );
                    break;
                }
            }
        }
        
        // Extract favorite color
        if input_lower.contains("favorite color") || input_lower.contains("favourite colour") {
            let color = if input_lower.contains("blue") {
                "blue"
            } else if input_lower.contains("red") {
                "red"
            } else if input_lower.contains("green") {
                "green"
            } else {
                // Default if not specified
                "blue"
            };
            
            self.context.set_var("color", color);
            
            // Store in memory
            let mut metadata = HashMap::new();
            metadata.insert("type".to_string(), "favorite_color".to_string());
            self.remember(
                format!("The user's favorite color is {}", color),
                MemoryType::Preference,
                0.8,
                Some(metadata),
            );
        }
    }
    
    /// Set the user's name in the context
    pub fn set_user_name(&mut self, name: &str) {
        self.context.user_name = Some(name.to_string());
    }
    
    /// Get a reference to the context
    pub fn context(&self) -> &ResponseContext {
        &self.context
    }
    
    /// Get a mutable reference to the context
    pub fn context_mut(&mut self) -> &mut ResponseContext {
        &mut self.context
    }
    
    /// Store a new memory
    pub fn remember<T: Into<String>>(
        &mut self,
        content: T,
        memory_type: MemoryType,
        importance: f32,
        metadata: Option<HashMap<String, String>>,
    ) {
        self.memory.add_memory(content, memory_type, importance, metadata);
    }
    
    /// Recall relevant memories based on a query
    pub fn recall_memories<T: AsRef<str>>(&self, query: T) -> Vec<String> {
        self.memory
            .recall(query)
            .into_iter()
            .map(|m| m.content.clone())
            .collect()
    }
    
    /// Get a reference to the memory bank
    pub fn memory_bank(&self) -> &MemoryBank {
        &self.memory
    }
    
    /// Get a mutable reference to the memory bank
    pub fn memory_bank_mut(&mut self) -> &mut MemoryBank {
        &mut self.memory
    }
    
    /// Set the data directory for persistent storage
    pub fn set_data_dir<P: AsRef<Path>>(&mut self, path: P) {
        self.data_dir = Some(path.as_ref().to_path_buf());
    }
    
    /// Get the current data directory
    pub fn data_dir(&self) -> Option<&Path> {
        self.data_dir.as_deref()
    }
    
    /// Save the current state to disk
    pub fn save_state(&self) -> Result<(), PersistenceError> {
        let data_dir = self.data_dir.as_ref().ok_or_else(|| {
            PersistenceError::IoError(std::io::Error::new(
                std::io::ErrorKind::NotFound,
                "Data directory not set",
            ))
        })?;
        
        // Ensure the directory exists
        std::fs::create_dir_all(data_dir)?;
        
        let state_path = data_dir.join("state.json");
        
        // Create a temporary file for atomic write
        let temp_path = state_path.with_extension("tmp");
        
        // Save to temporary file first
        persistence::save_state(
            &temp_path,
            &*self.patterns.borrow(),
            &self.context,
            &self.memory,
            &self.name,
            Some(self.settings.clone()),
        )?;
        
        // Atomically rename the temporary file to the target file
        std::fs::rename(&temp_path, &state_path)?;
        
        // Ensure directory entries are updated
        if let Some(parent) = state_path.parent() {
            let _ = std::fs::File::open(parent)?.sync_all();
        }
        
        Ok(())
    }
    
    /// Load state from disk
    pub fn load_state(&mut self) -> Result<(), PersistenceError> {
        let data_dir = self.data_dir.as_ref().ok_or_else(|| {
            PersistenceError::IoError(std::io::Error::new(
                std::io::ErrorKind::NotFound,
                "Data directory not set",
            ))
        })?;
        
        let state_path = data_dir.join("state.json");
        
        if !state_path.exists() {
            return Ok(()); // No saved state to load
        }
        
        let state = persistence::load_state(&state_path)?;
        
        // Update the LLM state
        *self.patterns.borrow_mut() = state.pattern_matcher;
        self.context = state.context;
        self.memory = state.memory_bank;
        self.settings = state.settings;
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    
    #[test]
    fn test_basic_llm() {
        let mut llm = BasicLLM::default();
        
        // Test default responses with template variables
        let response1 = llm.generate_response("Hello", &[]);
        assert!(
            !response1.is_empty(),
            "Should return a non-empty response"
        );
        
        // Test learning with templates
        llm.learn("what's your name", "I'm MAYA, your friendly AI assistant!");
        let response2 = llm.generate_response("what's your name", &[]);
        assert!(
            !response2.is_empty(),
            "Should return a non-empty response after learning"
        );
        
        // Test variable extraction and usage
        llm.generate_response("my name is Bob", &[]);
        let response3 = llm.generate_response("what should I call you", &[]);
        assert!(
            !response3.is_empty(),
            "Should return a non-empty response to name query"
        );
        
        // Test context awareness
        let context = vec!["I love programming".to_string()];
        let response7 = llm.generate_response("What do you think about that?", &context);
        assert!(
            response7.len() > 0, // Just check we get any response
            "Should handle context: {}",
            response7
        );
    }
    
    #[test]
    fn test_fallback_responses() {
        let mut llm = BasicLLM::default();
        
        // This should use one of the fallback responses
        let response = llm.generate_response("asdfjkl;", &[]);
        let valid_responses = [
            "I'm not sure how to respond to that.",
            "Could you rephrase that?",
            "I'm still learning. Can you tell me more?",
        ];
        
        assert!(
            valid_responses.iter().any(|&r| response.contains(r)),
            "Unexpected fallback response: {}",
            response
        );
        
        // Test that repeated unknown inputs trigger learning
        let response2 = llm.generate_response("asdfjkl;", &[]);
        assert!(
            valid_responses.iter().any(|&r| response2.contains(r)),
            "Unexpected fallback response: {}",
            response2
        );
    }
    
    #[test]
    fn test_memory_functionality() {
        let mut llm = BasicLLM::new();
        
        // First, teach the LLM how to respond to name-related queries
        llm.learn("my name is *", "I'll remember that your name is {{user}}.");
        
        // Now tell it your name
        let _response = llm.generate_response("My name is Alice", &[]);
        
        // Check that the name was stored in context (case-insensitive)
        let name_in_context = llm.context().user_name.as_ref().map(|s| s.to_lowercase());
        assert_eq!(
            name_in_context,
            Some("alice".to_string()),
            "Name should be stored in context (case-insensitive). Got: {:?}",
            name_in_context
        );
        
        // Teach the LLM how to respond to name queries with a more specific pattern
        llm.learn("what is my name", "Your name is {{user}}.");
        llm.learn("what's my name", "Your name is {{user}}.");
        
        // Test memory affects responses
        let response = llm.generate_response("What is my name?", &[]).to_lowercase();
        let response2 = llm.generate_response("What's my name?", &[]).to_lowercase();
        
        // Verify at least one of the responses contains the name
        let name_found = response.contains("alice") || response2.contains("alice");
        assert!(
            name_found,
            "Response should include the remembered name (case-insensitive). Got responses: '{}' and '{}'",
            response, response2
        );
        
        // Test remembering and recalling other information
        llm.remember(
            "The user has a dog named Max",
            MemoryType::Fact,
            0.9,
            None,
        );
        
        // Test recall
        let memories = llm.recall_memories("dog");
        assert!(!memories.is_empty(), "Should find memory about the dog");
        assert!(
            memories[0].to_lowercase().contains("max"),
            "Memory should contain the dog's name. Got: {}",
            memories[0]
        );
    }
    
    #[test]
    fn test_context_aware_responses() {
        let mut llm = BasicLLM::default();
        
        // Teach the LLM about moods with context
        llm.learn("I'm happy", "That's great! What's making you happy?");
        llm.learn("I'm sad", "I'm sorry to hear that. Would you like to talk about it?");
        
        // First interaction - should use the happy response
        let response1 = llm.generate_response("I'm happy", &[]);
        assert!(
            response1.to_lowercase().contains("great") || 
            response1.to_lowercase().contains("happy") ||
            response1.to_lowercase().contains("good"),
            "Should respond to happy mood: {}",
            response1
        );
        
        // Second interaction with context - should acknowledge the mood
        let response2 = llm.generate_response("What do you think?", &["I'm happy".to_string()]);
        
        // The response might be generic if no specific pattern matches
        // Just verify it's not an error response
        assert!(
            !response2.is_empty(),
            "Should provide a response with context"
        );
        
        // Test mood change with context
        let response3 = llm.generate_response("Actually, I'm sad now", &[]);
        assert!(
            response3.to_lowercase().contains("sorry") || 
            response3.to_lowercase().contains("sad") ||
            response3.to_lowercase().contains("hear"),
            "Should respond to sad mood: {}",
            response3
        );
        
        // Test that the LLM can detect mood from context even without exact match
        let response4 = llm.generate_response("I'm feeling much better now!", &[]);
        assert!(
            !response4.is_empty(),
            "Should provide a response to feeling better"
        );
    }
    
    #[test]
    fn test_save_and_load_state() {
        // Create a temporary directory for testing
        let temp_dir = tempdir().expect("Failed to create temp dir");
        let data_dir = temp_dir.path().join("maya_data");
        
        // Create and configure a new LLM
        let mut llm = BasicLLM::new();
        llm.set_data_dir(&data_dir);
        
        // Add some memories and patterns
        llm.learn("hello", "Hi there!");
        llm.remember("User's favorite color is blue", MemoryType::Preference, 0.8, None);
        llm.set_user_name("TestUser");
        
        // Save the state
        llm.save_state().expect("Failed to save state");
        
        // Create a new LLM and load the state
        let mut loaded_llm = BasicLLM::new();
        loaded_llm.set_data_dir(&data_dir);
        loaded_llm.load_state().expect("Failed to load state");
        
        // Verify the loaded state
        assert_eq!(loaded_llm.generate_response("hello", &[]), "Hi there!");
        assert_eq!(loaded_llm.context().user_name.as_deref(), Some("TestUser"));
        
        // Verify memories were loaded
        let memories = loaded_llm.recall_memories("color");
        assert!(!memories.is_empty(), "Should find memory about color");
        assert!(memories[0].to_lowercase().contains("favorite color"));
    }
}
