
//! Memory management commands for the MAYA LLM console

use maya_llm::memory::{MemoryBank, MemoryType, MemoryRelationship};
use std::collections::HashMap;

/// Enum representing different memory commands
pub enum MemoryCommand {
    List { query: Option<String> },
    Get { id: usize },
    Add { 
        content: String, 
        memory_type: MemoryType,
        importance: f32,
        metadata: Option<HashMap<String, String>> 
    },
    Delete { id: usize },
    Relate { 
        source_id: usize, 
        target_id: usize, 
        relationship: MemoryRelationship,
        strength: f32 
    },
    Search { query: String },
    Stats,
    Help,
}

impl MemoryCommand {
    /// Parse command line arguments into a MemoryCommand
    pub fn parse(args: &[&str]) -> Result<Self, String> {
        match args.get(0) {
            Some(&"list") => Ok(MemoryCommand::List {
                query: args.get(1..).map(|s| s.join(" ")).filter(|s| !s.is_empty())
            }),
            
            Some(&"get") => {
                let id = args.get(1)
                    .ok_or("Missing memory ID")?
                    .parse::<usize>()
                    .map_err(|_| "Invalid memory ID")?;
                Ok(MemoryCommand::Get { id })
            },
            
            Some(&"add") => {
                if args.len() < 2 {
                    return Err("Missing memory content".to_string());
                }
                
                // Parse additional flags
                let mut content_parts = Vec::new();
                let mut memory_type = MemoryType::Fact;
                let mut importance: f32 = 0.5;
                let mut metadata = HashMap::new();
                
                let mut i = 1; // Skip 'add' command
                while i < args.len() {
                    match args[i] {
                        "--type" => {
                            if i + 1 >= args.len() {
                                return Err("Missing memory type".to_string());
                            }
                            memory_type = args[i + 1].parse()
                                .map_err(|_| format!("Invalid memory type: {}", args[i + 1]))?;
                            i += 2;
                        },
                        "--importance" => {
                            if i + 1 >= args.len() {
                                return Err("Missing importance value".to_string());
                            }
                            importance = args[i + 1].parse()
                                .map_err(|_| format!("Invalid importance value: {}", args[i + 1]))?;
                            i += 2;
                        },
                        "--meta" => {
                            if i + 2 >= args.len() {
                                return Err("Missing metadata key-value pair".to_string());
                            }
                            metadata.insert(args[i + 1].to_string(), args[i + 2].to_string());
                            i += 3;
                        },
                        _ => {
                            content_parts.push(args[i]);
                            i += 1;
                        }
                    }
                }
                
                if content_parts.is_empty() {
                    return Err("Missing memory content".to_string());
                }
                
                Ok(MemoryCommand::Add {
                    content: content_parts.join(" "),
                    memory_type,
                    importance: importance.clamp(0.0, 1.0),
                    metadata: if metadata.is_empty() { None } else { Some(metadata) },
                })
            },
            
            Some(&"delete") => {
                let id = args.get(1)
                    .ok_or("Missing memory ID")?
                    .parse::<usize>()
                    .map_err(|_| "Invalid memory ID")?;
                Ok(MemoryCommand::Delete { id })
            },
            
            Some(&"relate") => {
                if args.len() < 4 {
                    return Err("Missing required arguments. Usage: memory relate <id1> <id2> <relationship> [--strength 0.5]".to_string());
                }
                
                let source_id = args[1].parse::<usize>()
                    .map_err(|_| "Invalid source memory ID".to_string())?;
                    
                let target_id = args[2].parse::<usize>()
                    .map_err(|_| "Invalid target memory ID".to_string())?;
                    
                let relationship = args[3].parse::<MemoryRelationship>()
                    .map_err(|_| format!("Invalid relationship type: {}", args[3]))?;
                
                // Default strength is 0.5 if not specified
                let mut strength = 0.5;
                let mut i = 4;
                while i + 1 < args.len() {
                    if args[i] == "--strength" {
                        strength = args[i + 1].parse::<f32>()
                            .map_err(|_| format!("Invalid strength value: {}", args[i + 1]))?
                            .clamp(0.0, 1.0);
                        break;
                    }
                    i += 1;
                }
                
                Ok(MemoryCommand::Relate { 
                    source_id, 
                    target_id, 
                    relationship, 
                    strength 
                })
            },
            
            Some(&"search") => {
                if args.len() < 2 {
                    return Err("Missing search query".to_string());
                }
                Ok(MemoryCommand::Search { 
                    query: args[1..].join(" ") 
                })
            },
            
            Some(&"stats") => Ok(MemoryCommand::Stats),
            
            Some(&"help") | None => Ok(MemoryCommand::Help),
            
            Some(cmd) => Err(format!("Unknown memory command: {}", cmd)),
        }
    }
    
    /// Execute the memory command and return the result as a string
    pub fn execute(&self, memory_bank: &mut MemoryBank) -> String {
        match self {
            MemoryCommand::List { query } => {
                let memories = if let Some(q) = query {
                    memory_bank.recall_memories(q)
                } else {
                    // Get all memories and filter out deleted ones
                    let memories = memory_bank.recall_memories("")
                        .into_iter()
                        .filter(|m| !m.is_empty())
                        .collect::<Vec<_>>();
                    memories
                };
                
                if memories.is_empty() {
                    return "No memories found.".to_string();
                }
                
                let mut result = String::new();
                result.push_str(&format!("Found {} memories:\n", memories.len()));
                for (i, mem) in memories.iter().enumerate() {
                    let preview = if mem.len() > 50 {
                        format!("{}...", &mem[..47])
                    } else {
                        mem.clone()
                    };
                    result.push_str(&format!("  {}: {}\n", i, preview));
                }
                result
            },
            
            MemoryCommand::Get { id } => {
                match memory_bank.get_memory(*id) {
                    Some(mem) => format!("Memory #{}:\n  Content: {}\n  Type: {}\n  Importance: {}\n  Created: {}",
                        id, 
                        mem.content,
                        mem.memory_type,
                        mem.importance,
                        mem.created_at.format("%Y-%m-%d %H:%M:%S")),
                    None => format!("Memory #{} not found", id),
                }
            },
            
            MemoryCommand::Add { content, memory_type, importance, metadata } => {
                let id = memory_bank.remember(
                    content.clone(),
                    memory_type.clone(),
                    *importance,
                    1.0, // Full confidence for manually added memories
                    metadata.clone(),
                );
                format!("Added memory #{}: {}", id, content)
            },
            
            MemoryCommand::Delete { id } => {
                if memory_bank.delete(*id) {
                    format!("Deleted memory #{}", id)
                } else {
                    format!("Memory #{} not found", id)
                }
            },
            
            MemoryCommand::Relate { source_id, target_id, relationship, strength } => {
                if let Some(memory) = memory_bank.get_memory_mut(*source_id) {
                    memory.add_relationship(*target_id, relationship.clone(), *strength);
                    format!("Added relationship from #{} to #{}: {:?} (strength: {})", 
                        source_id, target_id, relationship, strength)
                } else {
                    format!("Source memory #{} not found", source_id)
                }
            },
            
            MemoryCommand::Search { query } => {
                let results = memory_bank.recall_memories(query);
                if results.is_empty() {
                    "No matching memories found.".to_string()
                } else {
                    let mut result = format!("Found {} matching memories:\n", results.len());
                    for (i, mem) in results.iter().enumerate() {
                        result.push_str(&format!("  {}: {}\n", i, mem));
                    }
                    result
                }
            },
            
            MemoryCommand::Stats => {
                // Get all memories and filter out deleted ones
                let memories: Vec<String> = memory_bank.recall_memories("").into_iter().filter(|m| !m.is_empty()).collect();
                let memory_count = memories.len();
                
                let mut result = format!("Memory Bank Statistics:\n");
                result.push_str(&format!("  Total memories: {}\n", memory_count));
                
                // Since we only have strings from recall_memories, we can't get memory types
                // This is a limitation of the current API
                
                result
            },
            
            MemoryCommand::Help => {
                r#"
Memory Management Commands:
  memory list [query]       - List all memories (optionally filtered by query)
  memory get <id>          - Get details about a specific memory
  memory add <content> [--type <type>] [--importance <0.0-1.0>] [--meta <key> <value>...]
                            - Add a new memory
    --type <type>          - Memory type (fact, observation, plan, etc.)
    --importance <0.0-1.0> - Memory importance (default: 0.5)
    --meta <key> <value>   - Add metadata key-value pair
  
  memory delete <id>       - Delete a specific memory
  memory relate <id1> <id2> <relationship> [--strength <0.0-1.0>]
                            - Relate two memories
  memory search <query>     - Search for memories by content
  memory stats              - Show memory statistics
  memory help               - Show this help message
"#.to_string()
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_parse_list_command() {
        let cmd = MemoryCommand::parse(&["list"]).unwrap();
        assert!(matches!(cmd, MemoryCommand::List { query: None }));
        
        let cmd = MemoryCommand::parse(&["list", "test"]).unwrap();
        assert!(matches!(cmd, MemoryCommand::List { query: Some(q) } if q == "test"));
    }
    
    #[test]
    fn test_parse_get_command() {
        let cmd = MemoryCommand::parse(&["get", "42"]).unwrap();
        assert!(matches!(cmd, MemoryCommand::Get { id: 42 }));
        
        assert!(MemoryCommand::parse(&["get"]).is_err());
        assert!(MemoryCommand::parse(&["get", "abc"]).is_err());
    }
    
    #[test]
    fn test_parse_add_command() {
        let cmd = MemoryCommand::parse(&["add", "Test memory"]).unwrap();
        match cmd {
            MemoryCommand::Add { content, memory_type, importance, .. } => {
                assert_eq!(content, "Test memory");
                assert_eq!(memory_type, MemoryType::Fact);
                assert_eq!(importance, 0.5);
            },
            _ => panic!("Expected Add command"),
        }
        
        let cmd = MemoryCommand::parse(&["add", "Important", "--type", "goal", "--importance", "0.9"]).unwrap();
        match cmd {
            MemoryCommand::Add { content, memory_type, importance, .. } => {
                assert_eq!(content, "Important");
                assert_eq!(memory_type, MemoryType::Goal);
                assert_eq!(importance, 0.9);
            },
            _ => panic!("Expected Add command with options"),
        }
    }
    
    #[test]
    fn test_parse_relate_command() {
        let cmd = MemoryCommand::parse(&["relate", "1", "2", "hierarchical"]).unwrap();
        match cmd {
            MemoryCommand::Relate { source_id, target_id, relationship, strength } => {
                assert_eq!(source_id, 1);
                assert_eq!(target_id, 2);
                assert_eq!(relationship, MemoryRelationship::ParentOf);
                assert_eq!(strength, 0.5);
            },
            _ => panic!("Expected Relate command"),
        }
        
        let cmd = MemoryCommand::parse(&["relate", "1", "2", "temporal", "--strength", "0.8"]).unwrap();
        match cmd {
            MemoryCommand::Relate { source_id, target_id, relationship, strength } => {
                assert_eq!(source_id, 1);
                assert_eq!(target_id, 2);
                assert_eq!(relationship, MemoryRelationship::HappenedBefore);
                assert_eq!(strength, 0.8);
            },
            _ => panic!("Expected Relate command with strength"),
        }
    }
}
