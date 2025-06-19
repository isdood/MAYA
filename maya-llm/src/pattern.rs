use serde::{Serialize, Deserialize};
use std::collections::HashSet;
use std::time::{SystemTime, UNIX_EPOCH};

/// Represents a pattern with its associated response and learning metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pattern {
    pub text: String,
    pub response: String,
    pub weight: f32,
    pub usage_count: u32,
    pub last_used: u64,
    pub context_triggers: HashSet<String>,
    pub created_at: u64,
}

impl Pattern {
    pub fn new(text: &str, response: &str) -> Self {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
            
        Self {
            text: text.to_lowercase(),
            response: response.to_string(),
            weight: 1.0,
            usage_count: 0,
            last_used: now,
            context_triggers: HashSet::new(),
            created_at: now,
        }
    }

    /// Calculate a score for how well this pattern matches the input
    pub fn match_score(&self, input: &str, context: Option<&[String]>) -> f32 {
        let input = input.to_lowercase();
        let mut score = 0.0;
        
        // Exact match gets highest score
        if self.text == input {
            score = 10.0;
        }
        // Check if pattern is contained in input or vice versa
        else if input.contains(&self.text) || self.text.contains(&input) {
            score = 5.0;
        }
        // Check for word overlap
        else {
            let input_words: Vec<&str> = input.split_whitespace().collect();
            let pattern_words: Vec<&str> = self.text.split_whitespace().collect();
            
            let common_words: Vec<&&str> = input_words
                .iter()
                .filter(|word| pattern_words.contains(word))
                .collect();
            
            if !common_words.is_empty() {
                score = common_words.len() as f32 / pattern_words.len().max(1) as f32;
            }
        }
        
        if score > 0.0 {
            // Apply context similarity if context is provided
            let context_score = context
                .map(|ctx| self.context_similarity(ctx))
                .unwrap_or(0.5); // Neutral score if no context
                
            // Combine scores with weights
            let base_score = score * self.weight * self.time_decay();
            let context_weight = 0.3; // How much context affects the score
            
            base_score * (1.0 - context_weight) + (base_score * context_score * context_weight)
        } else {
            0.0
        }
    }
    
    /// Update pattern usage with context
    pub fn record_usage(&mut self, context: Option<&[String]>) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
            
        self.usage_count += 1;
        self.last_used = now;

        // Increase weight with diminishing returns
        self.weight += 1.0 / (self.usage_count as f32).sqrt();
        self.weight = self.weight.min(5.0); // Cap the maximum weight

        // Add context triggers if provided
        if let Some(ctx) = context {
            for trigger in ctx {
                self.context_triggers.insert(trigger.to_lowercase());
            }
        }
    }
    
    /// Calculate context similarity score
    pub fn context_similarity(&self, context: &[String]) -> f32 {
        if self.context_triggers.is_empty() {
            return 0.5; // Neutral score if no context triggers
        }
        
        let context_set: HashSet<_> = context.iter()
            .map(|s| s.to_lowercase())
            .collect();
            
        let common: HashSet<_> = self.context_triggers.intersection(&context_set).collect();
        
        if common.is_empty() {
            return 0.0;
        }
        
        common.len() as f32 / self.context_triggers.len().max(1) as f32
    }
    
    /// Calculate time decay factor (0.0 to 1.0)
    pub fn time_decay(&self) -> f32 {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
            
        let hours_since_use = (now - self.last_used) as f32 / 3600.0;
        1.0 / (1.0 + hours_since_use / 24.0) // Halflife of 24 hours
    }
}

/// Manages a collection of patterns with learning capabilities
#[derive(Default, Debug, Serialize, Deserialize)]
pub struct PatternMatcher {
    /// The collection of patterns
    pub patterns: Vec<Pattern>,
    /// Learning rate for pattern weights (0.0 to 1.0)
    pub learning_rate: f32,
    /// Maximum number of patterns to store
    pub max_patterns: usize,
}

impl PatternMatcher {
    pub fn new() -> Self {
        Self {
            patterns: Vec::new(),
            learning_rate: 0.1,
            max_patterns: 1000,
        }
    }
    
    /// Set the learning rate (0.0 to 1.0)
    pub fn with_learning_rate(mut self, rate: f32) -> Self {
        self.learning_rate = rate.clamp(0.0, 1.0);
        self
    }
    
    /// Set the maximum number of patterns to store
    pub fn with_max_patterns(mut self, max: usize) -> Self {
        self.max_patterns = max.max(1);
        self
    }
    
    /// Add a new pattern with optional context
    pub fn add_pattern(&mut self, text: &str, response: &str) -> bool {
        // Check for similar existing patterns first
        let similar_patterns: Vec<_> = self.patterns
            .iter_mut()
            .filter(|p| {
                // Consider patterns similar if they share at least half their words
                let pattern_words: HashSet<_> = p.text.split_whitespace().collect();
                let new_words: HashSet<_> = text.split_whitespace().collect();
                let common: HashSet<_> = pattern_words.intersection(&new_words).collect();
                common.len() > 0 && common.len() * 2 >= pattern_words.len().min(new_words.len())
            })
            .collect();
        
        if !similar_patterns.is_empty() {
            // Update the most similar pattern instead of adding a new one
            if let Some(most_similar) = similar_patterns.into_iter().max_by(|a, b| {
                a.match_score(text, None)
                    .partial_cmp(&b.match_score(text, None))
                    .unwrap_or(std::cmp::Ordering::Equal)
            }) {
                // Update the response with a weighted average of old and new
                if most_similar.response != response {
                    most_similar.response = format!("{} {}", most_similar.response, response);
                }
                most_similar.record_usage(None);
                return false; // Pattern was merged, not added
            }
        }
        
        // If we have too many patterns, remove the least used one
        if self.patterns.len() >= self.max_patterns {
            if let Some(min_index) = self.patterns
                .iter()
                .enumerate()
                .min_by(|(_, a), (_, b)| {
                    a.usage_count.cmp(&b.usage_count)
                        .then(a.last_used.cmp(&b.last_used).reverse())
                })
                .map(|(i, _)| i)
            {
                self.patterns.swap_remove(min_index);
            }
        }
        
        self.patterns.push(Pattern::new(text, response));
        true // Pattern was added
    }
    
    /// Find the best matching pattern for the input with optional context
    pub fn find_best_match(&mut self, input: &str) -> Option<&mut Pattern> {
        let context: Vec<String> = Vec::new(); // Empty context for backward compatibility
        self.find_best_match_with_context(input, Some(&context))
    }
    
    /// Find the best matching pattern for the input, considering context
    pub fn find_best_match_with_context<'a>(
        &'a mut self,
        input: &str,
        context: Option<&[String]>
    ) -> Option<&'a mut Pattern> {
        // First pass: find the best matching pattern and its score
        let (best_index, best_score) = {
            let mut best_index = None;
            let mut best_score = 0.0;
            
            for (i, pattern) in self.patterns.iter_mut().enumerate() {
                let score = pattern.match_score(input, context);
                if score > best_score {
                    best_score = score;
                    best_index = Some(i);
                }
            }
            
            (best_index, best_score)
        };
        
        // If we found a match, record its usage and reinforce similar patterns
        if let Some(index) = best_index {
            // Get a mutable reference to the best pattern
            let pattern = &mut self.patterns[index];
            
            // Record usage
            pattern.record_usage(context);
            
            // Only reinforce if the match is good but not perfect
            if best_score > 0.3 && best_score < 9.0 {
                // Make a copy of the pattern's text to avoid borrowing issues
                let pattern_text = pattern.text.clone();
                
                // Find and reinforce similar patterns
                for other_pattern in &mut self.patterns {
                    if other_pattern.text == pattern_text {
                        continue; // Skip the pattern itself
                    }
                    
                    // Create a context with the pattern text
                    let pattern_context = vec![pattern_text.clone()];
                    
                    // Calculate similarity based on context
                    let similarity = other_pattern.match_score(&pattern_text, Some(&pattern_context));
                    if similarity > 0.3 { // If somewhat similar
                        let boost = 0.05 * similarity * best_score;
                        other_pattern.weight = (other_pattern.weight + boost).min(5.0);
                    }
                }
            }
            
            // Return a mutable reference to the pattern
            Some(&mut self.patterns[index])
        } else {
            None
        }
    }
    
    // This method is kept for future use but currently not called directly
    #[allow(dead_code)]
    fn reinforce_similar_patterns(
        &mut self,
        input: &str,
        context: Option<&[String]>,
        strength: f32,
    ) {
        for pattern in &mut self.patterns {
            let similarity = pattern.match_score(input, context);
            if similarity > 0.1 { // Only reinforce somewhat similar patterns
                let boost = strength * similarity;
                pattern.weight = (pattern.weight + boost).min(5.0);
            }
        }
    }
    
    /// Get all patterns (for debugging/display)
    pub fn get_patterns(&self) -> &[Pattern] {
        &self.patterns
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_pattern_matching() {
        let mut matcher = PatternMatcher::new();
        matcher.add_pattern("hello", "Hi there!");
        matcher.add_pattern("how are you", "I'm doing great, thanks!");
        
        // Exact match
        let pattern = matcher.find_best_match("hello").unwrap();
        assert_eq!(pattern.response, "Hi there!");
        
        // Partial match
        let pattern = matcher.find_best_match("hello there").unwrap();
        assert_eq!(pattern.response, "Hi there!");
        
        // Different case
        let pattern = matcher.find_best_match("HELLO").unwrap();
        assert_eq!(pattern.response, "Hi there!");
        
        // No match
        assert!(matcher.find_best_match("goodbye").is_none());
        
        // Test with context
        let context = vec!["previous message".to_string()];
        let pattern = matcher.find_best_match_with_context("hello", Some(&context)).unwrap();
        assert_eq!(pattern.response, "Hi there!");
    }
    
    #[test]
    fn test_usage_tracking() {
        let mut matcher = PatternMatcher::new();
        matcher.add_pattern("test", "Test response");
        
        // First usage
        let pattern = matcher.find_best_match("test").unwrap();
        assert_eq!(pattern.usage_count, 1);
        assert!(pattern.weight > 1.0);
        
        // Second usage with context
        let context = vec!["test context".to_string()];
        let pattern = matcher.find_best_match_with_context("test", Some(&context)).unwrap();
        assert_eq!(pattern.usage_count, 2);
        assert!(pattern.context_triggers.contains("test context"));
    }
    
    #[test]
    fn test_pattern_similarity() {
        let mut matcher = PatternMatcher::new();
        matcher.add_pattern("hello world", "Response 1");
        
        // Similar pattern should update existing one
        let added = matcher.add_pattern("hello there world", "Response 2");
        assert!(!added); // Should merge with existing pattern
        
        // Verify the response was updated
        let pattern = matcher.find_best_match("hello world").unwrap();
        assert!(pattern.response.contains("Response 1") && pattern.response.contains("Response 2"));
    }
    
    #[test]
    fn test_time_decay() {
        let mut pattern = Pattern::new("test", "response");
        
        // New pattern should have minimal decay
        let decay = pattern.time_decay();
        assert!(decay > 0.9);
        
        // Simulate old pattern
        pattern.last_used = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() - 24 * 3600; // 24 hours ago
            
        let decay = pattern.time_decay();
        assert!(decay < 0.6 && decay > 0.4); // Should be around 0.5 after 24h
    }
    
    #[test]
    fn test_pattern_pruning() {
        let mut matcher = PatternMatcher::new();
        matcher.max_patterns = 5;
        matcher.learning_rate = 0.1;
        
        // Add more patterns than the max
        for i in 0..10 {
            matcher.add_pattern(&format!("test {}", i), &format!("response {}", i));
        }
        
        // After adding 10 patterns, it should prune down to 1 (10 * 0.1 = 1)
        assert_eq!(matcher.patterns.len(), 1, "Should keep only 1 pattern after pruning");
    }    
}
