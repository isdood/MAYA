use std::collections::HashMap;

/// Represents a pattern with its associated response and weight
#[derive(Debug, Clone)]
pub struct Pattern {
    pub text: String,
    pub response: String,
    pub weight: f32,
    pub usage_count: u32,
}

impl Pattern {
    pub fn new(text: &str, response: &str) -> Self {
        Self {
            text: text.to_lowercase(),
            response: response.to_string(),
            weight: 1.0,
            usage_count: 0,
        }
    }

    /// Calculate a score for how well this pattern matches the input
    pub fn match_score(&self, input: &str) -> f32 {
        let input = input.to_lowercase();
        
        // Exact match gets highest score
        if self.text == input {
            return 10.0 * self.weight;
        }
        
        // Check if pattern is contained in input or vice versa
        if input.contains(&self.text) || self.text.contains(&input) {
            return 5.0 * self.weight;
        }
        
        // Check for word overlap
        let input_words: Vec<&str> = input.split_whitespace().collect();
        let pattern_words: Vec<&str> = self.text.split_whitespace().collect();
        
        let common_words: Vec<&&str> = input_words
            .iter()
            .filter(|word| pattern_words.contains(word))
            .collect();
        
        if !common_words.is_empty() {
            let score = (common_words.len() as f32 / pattern_words.len().max(1) as f32) * self.weight;
            return score.max(0.1); // Ensure minimum score for any match
        }
        
        0.0
    }
    
    /// Increase the weight based on successful usage
    pub fn record_usage(&mut self) {
        self.usage_count += 1;
        self.weight += 0.1; // Slight increase per usage
        self.weight = self.weight.min(5.0); // Cap the maximum weight
    }
}

/// Manages a collection of patterns
#[derive(Default)]
pub struct PatternMatcher {
    patterns: Vec<Pattern>,
}

impl PatternMatcher {
    pub fn new() -> Self {
        Self {
            patterns: Vec::new(),
        }
    }
    
    /// Add a new pattern
    pub fn add_pattern(&mut self, text: &str, response: &str) {
        self.patterns.push(Pattern::new(text, response));
    }
    
    /// Find the best matching pattern for the input
    pub fn find_best_match(&mut self, input: &str) -> Option<&mut Pattern> {
        self.patterns
            .iter_mut()
            .map(|p| (p.match_score(input), p))
            .filter(|(score, _)| *score > 0.0)
            .max_by(|(a, _), (b, _)| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal))
            .map(|(_, pattern)| {
                pattern.record_usage();
                pattern
            })
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
    }
    
    #[test]
    fn test_usage_tracking() {
        let mut matcher = PatternMatcher::new();
        matcher.add_pattern("test", "Test response");
        
        // First usage
        let pattern = matcher.find_best_match("test").unwrap();
        assert_eq!(pattern.usage_count, 1);
        assert!(pattern.weight > 1.0);
        
        // Second usage
        let pattern = matcher.find_best_match("test").unwrap();
        assert_eq!(pattern.usage_count, 2);
    }
}
