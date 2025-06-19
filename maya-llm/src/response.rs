//! Response generation and templating system

use std::collections::HashMap;
use std::fmt;

/// Represents a response template that can contain variables
#[derive(Debug, Clone)]
pub struct ResponseTemplate {
    template: String,
    variables: Vec<String>,
}

impl ResponseTemplate {
    /// Create a new response template from a string
    /// Variables are in the format {{variable_name}}
    pub fn new(template: &str) -> Self {
        let mut variables = Vec::new();
        let mut current = template;
        
        // Extract all variable names from the template
        while let Some(start) = current.find("{{") {
            if let Some(end) = current[start..].find("}}") {
                let var_name = current[start + 2..start + end].trim().to_string();
                if !var_name.is_empty() {
                    variables.push(var_name);
                }
                current = &current[start + end + 2..];
            } else {
                break;
            }
        }
        
        Self {
            template: template.to_string(),
            variables,
        }
    }
    
    /// Render the template with the provided variables
    pub fn render(&self, context: &HashMap<&str, String>) -> String {
        let mut result = self.template.clone();
        
        for (var, value) in context {
            let placeholder = format!("{{{{ {var} }}}}");
            result = result.replace(&placeholder, value);
        }
        
        // Clean up any remaining placeholders
        result = result.replace("{{", "").replace("}}", "");
        
        result
    }
    
    /// Get the list of variables this template expects
    pub fn variables(&self) -> &[String] {
        &self.variables
    }
}

impl fmt::Display for ResponseTemplate {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.template)
    }
}

/// Context for response generation
#[derive(Default)]
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
        let template = ResponseTemplate::new("Hello, {{ name }}! How are you today?");
        assert_eq!(template.variables(), &["name".to_string()]);
        
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
    fn test_generate_response() {
        let mut context = ResponseContext::new()
            .with_user_name("Charlie");
            
        context.add_previous_message("Hello");
        context.set_var("mood", "excited");
        
        let response = generate_response(
            "Hi {{user}}! I see you're feeling {{mood}}. You've sent {{message_count}} messages.",
            &context
        );
        
        assert_eq!(
            response,
            "Hi Charlie! I see you're feeling excited. You've sent 1 messages."
        );
    }
}
