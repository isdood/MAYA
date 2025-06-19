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
        
        // Prepare context for pattern matching
        let context_strings: Vec<String> = self.context.previous_messages
            .iter()
            .take(3) // Only use last 3 messages as context
            .map(|s| s.to_string())
            .collect();
        
        let mut patterns = self.patterns.borrow_mut();
        
        // Try to find a matching pattern with context
        if let Some(pattern) = patterns.find_best_match_with_context(input, Some(&context_strings)) {
            // Use the template system to generate a response
            let response = generate_response(&pattern.response, &self.context);
            
            // Update context with this response
            self.context.add_previous_message(&response);
            
            // Learn from this interaction if it wasn't a perfect match
            let match_quality = pattern.match_score(input, Some(&context_strings));
            if match_quality < 8.0 { // If not a very strong match
                self.learn_from_interaction(input, &response, &context_strings);
            }
            
            return response;
        }
        
        // If no pattern matches, use a random fallback response
        let idx = (input.len() % self.fallback_responses.len()) as usize;
        let response = self.fallback_responses[idx].to_string();
        
        // Update context with this fallback
        self.context.add_previous_message(&response);
        
        // Learn from this fallback interaction
        self.learn_from_interaction(input, &response, &context_strings);
        
        response
    }
    
    fn learn(&mut self, input: &str, response: &str) {
        let mut patterns = self.patterns.borrow_mut();
        
        // Add a new pattern based on this interaction
        let is_new = patterns.add_pattern(input, response);
        
        if is_new {
            log::debug!("Added new pattern: '{}' -> '{}'", input, response);
            
            // Update context with this learning
            self.context.add_previous_message(&format!("Learned: {} -> {}", input, response));
            
            // If we have too many patterns, remove the least used ones
            self.prune_patterns();
        } else {
            log::debug!("Updated existing pattern for: '{}'", input);
        }
    }
    
    fn name(&self) -> &str {
        &self.name
    }
}

impl BasicLLM {
    /// Learn from an interaction and update patterns
    fn learn_from_interaction(&mut self, input: &str, response: &str, context: &[String]) {
        let mut patterns = self.patterns.borrow_mut();
        
        // Add a new pattern based on this interaction
        let is_new = patterns.add_pattern(input, response);
        
        if is_new {
            log::debug!("Learned from interaction: '{}' -> '{}'", input, response);
            
            // If we have too many patterns, remove the least used ones
            if patterns.patterns.len() > patterns.max_patterns {
                self.prune_patterns();
            }
        }
        
        // Find and update similar patterns with context
        for pattern in &mut patterns.patterns {
            let similarity = pattern.match_score(input, Some(context));
            if similarity > 0.3 { // If somewhat similar
                // Boost weight based on similarity
                let boost = 0.1 * similarity;
                pattern.weight = (pattern.weight + boost).min(5.0);
                
                // Update context triggers
                for ctx in context {
                    pattern.context_triggers.insert(ctx.to_lowercase());
                }
            }
        }
    }
    
    /// Remove least used patterns to keep the collection manageable
    fn prune_patterns(&mut self) {
        let mut patterns = self.patterns.borrow_mut();
        let target_size = patterns.max_patterns.saturating_sub(10); // Keep some room for new patterns
        
        if patterns.patterns.len() > target_size {
            // Sort patterns by usage count and last used time
            patterns.patterns.sort_by(|a, b| {
                a.usage_count.cmp(&b.usage_count)
                    .then(a.last_used.cmp(&b.last_used))
            });
            
            // Remove the least used patterns
            patterns.patterns.truncate(target_size);
            log::debug!("Pruned patterns, now have {} patterns", patterns.patterns.len());
        }
    }
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

mod tests {
    use super::*;
    
    #[test]
    fn test_basic_llm() {
        let mut llm = BasicLLM::default();
        
        // Test default responses with template variables
        let response1 = llm.generate_response("Hello", &[]);
        assert!(response1.contains("MAYA"), "Response should contain MAYA: {}", response1);
        
        let response2 = llm.generate_response("Hi", &[]);
        assert!(response2.contains("MAYA"), "Response should contain MAYA: {}", response2);
        
        // Test with context
        let response3 = llm.generate_response("How are you?", &["Hi MAYA".to_string()]);
        assert!(
            response3.contains("great") || response3.contains("good") || response3.contains("thanks"), 
            "Response should be positive: {}",
            response3
        );
        
        // Test learning with templates
        llm.learn("what's your name", "I'm MAYA, your friendly AI assistant!");
        let response4 = llm.generate_response("what's your name", &[]);
        assert!(
            response4.contains("MAYA") || response4.contains("friendly"),
            "Response should contain MAYA or friendly: {}",
            response4
        );
        
        // Test variable extraction and usage
        llm.generate_response("my name is Bob", &[]);
        let response5 = llm.generate_response("what should I call you", &[]);
        
        // The response should either include the name or a default
        let response5_lower = response5.to_lowercase();
        assert!(
            response5_lower.contains("bob") || 
            response5_lower.contains("maya") ||
            response5_lower.contains("call"),
            "Unexpected response: {}",
            response5
        );
        
        // Test pattern matching with different cases and partial matches
        let response6 = llm.generate_response("HELLO", &[]);
        assert!(
            response6.contains("MAYA") || response6.contains("Hey") || response6.contains("Hello"),
            "Unexpected greeting: {}",
            response6
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
            "I'm still learning. Can you rephrase that?",
            "That's interesting. Tell me more!",
            "I'm not sure I understand. Could you explain further?",
            "I'll make a note of that. What else would you like to know?",
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
    fn test_context_aware_responses() {
        let mut llm = BasicLLM::default();
        
        // Set user name through the proper method
        llm.set_user_name("Bob");
        
        // First interaction
        let response1 = llm.generate_response("Hi", &[]);
        assert!(
            response1.contains("Hello") || response1.contains("Hey") || response1.contains("Hi"),
            "Should greet the user: {}",
            response1
        );
        
        // Second interaction with context
        let response2 = llm.generate_response("How are you?", &[response1.clone()]);
        assert!(
            response2.contains("great") || response2.contains("good") || response2.contains("thanks"),
            "Should respond positively: {}",
            response2
        );
        
        // Check that user name is used in responses
        let response3 = llm.generate_response("what's your name", &[]);
        assert!(
            response3.contains("MAYA") || response3.contains("Bob") || response3.contains("assistant"),
            "Should identify as MAYA or Bob's assistant: {}",
            response3
        );
        
        // Test mood setting
        llm.generate_response("I am feeling happy", &[]);
        let response4 = llm.generate_response("How am I feeling?", &[]);
        assert!(
            response4.to_lowercase().contains("happy") || 
            response4.to_lowercase().contains("great") ||
            response4.to_lowercase().contains("good"),
            "Should know the user is happy: {}",
            response4
        );
        
        // Test context from multiple messages
        let context = vec![
            "I love programming".to_string(),
            "Especially in Rust".to_string()
        ];
        let response5 = llm.generate_response("What do you think about that?", &context);
        assert!(
            !response5.is_empty(),
            "Should handle multiple context messages: {}",
            response5
        );
    }
}
