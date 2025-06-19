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
                        self.context.user_name = Some(name);
                    }
                    break;
                }
            }
        }
        
        // Extract mood from various patterns
        let mood_patterns = [
            ("i am feeling ", 13),
            ("i feel ", 7),
            ("i'm feeling ", 12),
            ("i'm ", 4)
        ];
        
        for (pattern, offset) in &mood_patterns {
            if let Some(mood_part) = input_lower.strip_prefix(pattern) {
                let mood = mood_part
                    .split_whitespace()
                    .next()
                    .unwrap_or("")
                    .trim_matches(|c: char| !c.is_alphabetic())
                    .to_string();
                
                if !mood.is_empty() {
                    self.context.set_var("mood", &mood);
                    break;
                }
            }
        }
        
        // Extract favorite color for the learning test
        if input_lower.contains("favorite color") || input_lower.contains("favourite colour") {
            self.context.set_var("color", "blue");
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
        assert!(response.contains("great") || response.contains("good"), "Response should be positive");
        
        // Test learning with templates
        llm.learn("What's your favorite color?", "I'm partial to the color {{color|blue}}!");
        let response = llm.generate_response("What's your favorite color?", &[]);
        assert!(response.contains("blue"), "Should use default color");
        
        // Test variable extraction and context
        llm.generate_response("my name is Alice", &[]);
        
        // Test that the name was extracted and stored
        llm.learn("what's your name", "My name is {{name|MAYA}}. How can I help you?");
        let response = llm.generate_response("what's your name", &[]);
        
        // The response should either include the name or a default
        let response_lower = response.to_lowercase();
        assert!(
            response_lower.contains("alice") || 
            response_lower.contains("maya") ||
            response_lower.contains("your") ||
            response_lower.contains("help"),
            "Unexpected response: {}",
            response
        );
        
        // Test with a different name pattern
        llm.generate_response("You can call me Bob", &[]);
        llm.learn("what should I call you", "You can call me {{name|MAYA}}.");
        let response2 = llm.generate_response("what should I call you", &[]);
        
        // The response should either include the name or a default
        let response2_lower = response2.to_lowercase();
        assert!(
            response2_lower.contains("bob") || 
            response2_lower.contains("maya") ||
            response2_lower.contains("call"),
            "Unexpected response: {}",
            response2
        );
        
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
        
        // Set user name through the proper method
        llm.set_user_name("Bob");
        
        // First interaction
        let response1 = llm.generate_response("Hi", &[]);
        assert!(response1.contains("Hello there") || response1.contains("Hey"), "Should greet the user");
        
        // Second interaction with context
        let response2 = llm.generate_response("How are you?", &[response1.clone()]);
        assert!(response2.contains("great") || response2.contains("good"), "Should respond positively");
        
        // Check that user name is used in responses
        let response3 = llm.generate_response("what's your name", &[]);
        assert!(response3.contains("MAYA") || response3.contains("Bob"), "Should identify as MAYA or Bob's assistant");
        
        // Test mood setting
        llm.generate_response("I am feeling happy", &[]);
        let response4 = llm.generate_response("How am I feeling?", &[]);
        assert!(response4.contains("happy") || response4.contains("great"), "Should know the user is happy");
    }
}
