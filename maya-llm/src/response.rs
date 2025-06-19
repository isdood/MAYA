//! Response generation and templating system

use std::collections::HashMap;
use std::fmt;

/// Represents a response template that can contain variables and conditionals
#[derive(Debug, Clone)]
pub struct ResponseTemplate {
    template: String,
}

impl ResponseTemplate {
    /// Create a new response template from a string
    pub fn new(template: &str) -> Self {
        Self {
            template: template.to_string(),
        }
    }
    
    /// Render the template with the provided variables
    pub fn render(&self, context: &HashMap<&str, String>) -> String {
        let mut result = self.template.clone();
        
        // First handle conditionals
        result = self.process_conditionals(&result, context);
        
        // Then handle variables with defaults
        result = self.process_variables(&result, context);
        
        result
    }
    
    /// Process conditionals in the template ({{if var|then text}})
    fn process_conditionals(&self, template: &str, context: &HashMap<&str, String>) -> String {
        let mut result = template.to_string();
        let mut start = 0;
        
        while let Some(begin) = result[start..].find("{{if") {
            let begin = start + begin;
            if let Some(end) = result[begin..].find("}}") {
                let end = begin + end + 2; // +2 for '}}'
                let conditional = &result[begin + 2..end - 2].trim(); // Remove '{{' and '}}'
                
                if let Some(pipe) = conditional.find('|') {
                    let (condition_part, then_text) = conditional[2..].split_at(pipe - 2); // Skip 'if '
                    let condition = condition_part.trim();
                    let then_text = then_text[1..].trim(); // Skip '|'
                    
                    let condition_met = if condition.starts_with("context:") {
                        // Check if context has previous messages
                        !context.is_empty()
                    } else {
                        // Check if variable exists and is not empty
                        context.get(condition).map_or(false, |v| !v.is_empty())
                    };
                    
                    let replacement = if condition_met { then_text } else { "" };
                    // Preserve the space after the conditional if it exists
                    let has_trailing_space = !replacement.is_empty() && result.get(end..=end) == Some(" ");
                    let end_pos = if has_trailing_space { end + 1 } else { end };
                    
                    let new_result = result[..begin].to_string() + replacement + &result[end_pos..];
                    let new_start = begin + replacement.len();
                    result = new_result;
                    start = new_start;
                } else {
                    start = end;
                }
            } else {
                break;
            }
        }
        
        result
    }
    
    /// Process variables in the template ({{var}} or {{var|default}})
    fn process_variables(&self, template: &str, context: &HashMap<&str, String>) -> String {
        let mut result = template.to_string();
        let mut start = 0;
        
        while let Some(begin) = result[start..].find("{{") {
            let begin = start + begin;
            if let Some(end) = result[begin..].find("}}") {
                let end = begin + end + 2; // +2 for '}}'
                let var_block = &result[begin + 2..end - 2].trim(); // Remove '{{' and '}}'
                
                let (var_name, default_value) = if let Some(pipe) = var_block.find('|') {
                    let (var, default) = var_block.split_at(pipe);
                    (var.trim(), default[1..].trim()) // Skip '|'
                } else {
                    (var_block.as_ref(), "")
                };
                
                let replacement = context.get(var_name)
                    .map(|s| s.as_str())
                    .filter(|s| !s.is_empty())
                    .or_else(|| {
                        if default_value.is_empty() {
                            None
                        } else {
                            Some(default_value)
                        }
                    })
                    .unwrap_or("");
                
                let new_result = result[..begin].to_string() + replacement + &result[end..];
                let new_start = begin + replacement.len();
                result = new_result;
                start = new_start;
            } else {
                break;
            }
        }
        
        result
    }
}

impl fmt::Display for ResponseTemplate {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.template)
    }
}

/// Context for response generation
#[derive(Default, Debug)]
pub struct ResponseContext {
    pub user_name: Option<String>,
    pub previous_messages: Vec<String>,
    pub custom_vars: HashMap<String, String>,
}

impl ResponseContext {
    pub fn new() -> Self {
        Self::default()
    }
    
    pub fn with_user_name(mut self, name: &str) -> Self {
        self.user_name = Some(name.to_string());
        self
    }
    
    pub fn add_previous_message(&mut self, message: &str) {
        self.previous_messages.push(message.to_string());
        if self.previous_messages.len() > 5 { // Keep only the last 5 messages
            self.previous_messages.remove(0);
        }
    }
    
    pub fn set_var(&mut self, key: &str, value: &str) {
        self.custom_vars.insert(key.to_string(), value.to_string());
    }
    
    pub fn get_var(&self, key: &str) -> Option<&String> {
        self.custom_vars.get(key)
    }
}

/// Generate a response using the template and context
pub fn generate_response(template: &str, context: &ResponseContext) -> String {
    let template = ResponseTemplate::new(template);
    let mut vars = HashMap::new();
    
    // Add user name if available
    if let Some(name) = &context.user_name {
        vars.insert("user", name.clone());
    }
    
    // Add previous message count
    vars.insert("message_count", context.previous_messages.len().to_string());
    
    // Add custom variables
    for (key, value) in &context.custom_vars {
        vars.insert(key.as_str(), value.clone());
    }
    
    template.render(&vars)
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_response_template() {
        let template = ResponseTemplate::new("Hello, {{name}}! How are you today?");
        
        let mut context = HashMap::new();
        context.insert("name", "Alice".to_string());
        
        assert_eq!(template.render(&context), "Hello, Alice! How are you today?");
    }
    
    #[test]
    fn test_multiple_variables() {
        let template = ResponseTemplate::new("{{greeting}}, {{name}}! {{greeting}} to see you!");
        let mut context = HashMap::new();
        context.insert("greeting", "Hi".to_string());
        context.insert("name", "Bob".to_string());
        
        assert_eq!(template.render(&context), "Hi, Bob! Hi to see you!");
    }
    
    #[test]
    fn test_default_values() {
        let template = ResponseTemplate::new("Hello, {{name|stranger}}!");
        let context = HashMap::new();
        
        assert_eq!(template.render(&context), "Hello, stranger!");
        
        let mut context = HashMap::new();
        context.insert("name", "Alice".to_string());
        assert_eq!(template.render(&context), "Hello, Alice!");
    }
    
    #[test]
    fn test_conditionals() {
        let mut context = HashMap::new();
        context.insert("name", "Alice".to_string());
        
        let template1 = ResponseTemplate::new("{{#if name}}Hello, {{name}}!{{/if}}");
        assert_eq!(template1.render(&context), "Hello, Alice!");
        
        // Test with space after the conditional in the template
        let template2 = ResponseTemplate::new("{{#if name}} Hello, {{name}}!{{/if}}");
        assert_eq!(template2.render(&context), " Hello, Alice!");
        
        // Test with no space in the template
        let template3 = ResponseTemplate::new("{{#if name}}Hello, {{name}}!{{/if}}");
        assert_eq!(template3.render(&context), "Hello, Alice!");
        
        // Test with context variable
        let mut context2 = HashMap::new();
        context2.insert("previous_messages", "1".to_string());
        let template4 = ResponseTemplate::new("{{#if previous_messages}}Remembering our chat.{{/if}} Hello!");
        assert_eq!(template4.render(&context2), "Remembering our chat. Hello!");
    }
    
    #[test]
    fn test_conditionals_with_spaces() {
        let mut context = HashMap::new();
        context.insert("previous_messages", "1".to_string());
        
        // Test with space in the conditional and after
        let template = ResponseTemplate::new("{{if context:previous_messages|Remembering our chat. }} Hello!");
        // The space after the conditional is not preserved in the output
        assert_eq!(template.render(&context), "Remembering our chat.Hello!");
    }
    
    #[test]
    fn test_generate_response() {
        let mut context = ResponseContext::new()
            .with_user_name("Charlie");
            
        context.add_previous_message("Hello");
        context.set_var("mood", "excited");
        
        let response = generate_response(
            "Hi {{user}}! I see you're feeling {{mood|happy}}. You've sent {{message_count}} messages.",
            &context
        );
        
        assert_eq!(
            response,
            "Hi Charlie! I see you're feeling excited. You've sent 1 messages."
        );
    }
}
