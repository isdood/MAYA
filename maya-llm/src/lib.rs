//! Core LLM implementation for MAYA

use std::cell::RefCell;
use std::rc::Rc;
use std::collections::HashMap;

pub mod error;
pub mod models;
pub mod storage;
pub mod pattern;
pub mod response;

use pattern::{Pattern, PatternMatcher};
use response::{ResponseContext, generate_response, ResponseTemplate};

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
    fallback_responses: Vec<&'static str>,
    context: ResponseContext,
}

impl Default for BasicLLM {
    fn default() -> Self {
        let mut patterns = PatternMatcher::new();
        
        // Add some default patterns with template support
        patterns.add_pattern("hello", "{{greeting|Hey}}! I'm MAYA ✨");
        patterns.add_pattern("hi", "{{greeting|Hello}} there! I'm MAYA ✨");
        patterns.add_pattern("hey", "{{greeting|Hey}}! How can I help you today?");
        patterns.add_pattern(
            "how are you", 
            "I'm doing {{mood|great}}, thanks for asking! {{if context:previous_messages|I remember our previous conversation. }}"
        );
        patterns.add_pattern(
            "what's your name", 
            "I'm MAYA, your friendly AI assistant! {{if user|You can call me {{user}}'s assistant. }}"
        );
        patterns.add_pattern(
            "my name is {{name}}",
            "Nice to meet you, {{name}}! I'll remember that."
        );
        
        Self {
            name: "MAYA".to_string(),
            patterns: Rc::new(RefCell::new(patterns)),
            fallback_responses: vec![
                "I'm still learning. Can you rephrase that?",
                "That's interesting. Tell me more!",
                "I'm not sure I understand. Could you explain further?",
                "I'll make a note of that. What else would you like to know?",
            ],
            context: ResponseContext::new(),
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
        
        let mut patterns = self.patterns.borrow_mut();
        
        // Try to find a matching pattern
        if let Some(pattern) = patterns.find_best_match(input) {
            // Use the template system to generate a response
            let response = generate_response(&pattern.response, &self.context);
            
            // Update context with this response
            self.context.add_previous_message(&response);
            
            return response;
        }
        
        // If no pattern matches, use a random fallback response
        let idx = (input.len() % self.fallback_responses.len()) as usize; // Simple deterministic "random"
        let response = self.fallback_responses[idx].to_string();
        
        // Update context with this fallback
        self.context.add_previous_message(&response);
        
        response
    }
    
    fn learn(&mut self, input: &str, response: &str) {
        let mut patterns = self.patterns.borrow_mut();
        
        // Add a new pattern based on this interaction
        patterns.add_pattern(input, response);
        
        // If we see the same input multiple times, the pattern's weight will increase
        if let Some(pattern) = patterns.find_best_match(input) {
            // The pattern's weight is already increased by find_best_match
            log::debug!("Learned pattern: '{}' -> '{}' (weight: {})", 
                       pattern.text, pattern.response, pattern.weight);
            
            // Update context with this learning
            self.context.add_previous_message(&format!("Learned: {} -> {}", input, response));
        }
    }
    
    fn name(&self) -> &str {
        &self.name
    }
}

impl BasicLLM {
    /// Extract variables from input and add them to the context
    fn extract_variables(&mut self, input: &str) {
        // Simple example: extract name from "my name is X"
        if let Some(name) = input.strip_prefix("my name is ") {
            self.context.set_var("name", name.trim());
        }
        
        // Add more variable extraction rules as needed
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
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_basic_llm() {
        let mut llm = BasicLLM::default();
        
        // Test default responses with template variables
        assert_eq!(llm.generate_response("Hello", &[]), "Hey! I'm MAYA ✨");
        assert_eq!(llm.generate_response("Hi", &[]), "Hello there! I'm MAYA ✨");
        
        // Test with context
        let response = llm.generate_response("How are you?", &["Hi MAYA".to_string()]);
        assert!(response.contains("I'm doing great, thanks for asking!"));
        assert!(response.contains("I remember our previous conversation."));
        
        // Test learning with templates
        llm.learn("What's your favorite color?", "I'm partial to the color {{color|blue}}!");
        let response = llm.generate_response("What's your favorite color?", &[]);
        assert_eq!(response, "I'm partial to the color blue!");
        
        // Test variable extraction and context
        llm.generate_response("my name is Alice", &[]);
        let response = llm.generate_response("what's your name", &[]);
        assert!(response.contains("Alice's assistant"));
        
        // Test pattern matching with different cases and partial matches
        assert_eq!(
            llm.generate_response("HELLO", &[]),
            "Hey! I'm MAYA ✨"
        );
    }
    
    #[test]
    fn test_fallback_responses() {
        let mut llm = BasicLLM::default();
        
        // This should use one of the fallback responses
        let response = llm.generate_response("asdfjkl;", &[]);
        assert!(
            [
                "I'm still learning. Can you rephrase that?",
                "That's interesting. Tell me more!",
                "I'm not sure I understand. Could you explain further?",
                "I'll make a note of that. What else would you like to know?",
            ].contains(&response.as_str())
        );
    }
    
    #[test]
    fn test_context_aware_responses() {
        let mut llm = BasicLLM::default();
        llm.set_user_name("Bob");
        
        // First interaction
        let response1 = llm.generate_response("Hi", &[]);
        assert!(response1.contains("Hello there!"));
        
        // Second interaction with context
        let response2 = llm.generate_response("How are you?", &[response1.clone()]);
        assert!(response2.contains("I remember our previous conversation"));
        
        // Check that user name is used in responses
        let response3 = llm.generate_response("what's your name", &[]);
        assert!(response3.contains("Bob's assistant"));
    }
}
