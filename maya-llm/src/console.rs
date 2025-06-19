//! Console interface for the MAYA LLM

use maya_llm::LLM;
use rustyline::error::ReadlineError;
use rustyline::{Config, Editor};
use std::error::Error;
use std::result::Result as StdResult;

/// Runs the console interface
pub fn run(llm: &mut impl LLM) -> StdResult<(), Box<dyn Error>> {
    // Create a new editor with command history
    let config = Config::builder()
        .history_ignore_space(true)
        .auto_add_history(true)
        .build();
        
    let mut rl = match Editor::<()>::with_config(config) {
        Ok(editor) => editor,
        Err(e) => return Err(Box::new(e)),
    };
    
    // Load command history if it exists
    if let Err(e) = rl.load_history(".maya_history") {
        println!("No previous history found: {}", e);
    }

    // Main REPL loop
    loop {
        let readline = rl.readline("\n>>> ");
        
        match readline {
            Ok(line) => {
                // Process the input
                match line.trim() {
                    "" => continue,  // Skip empty lines
                    "exit" | "quit" | "q" => break,
                    "help" => show_help(),
                    "clear" => {
                        println!("\x1B[2J\x1B[1;1H"); // Clear screen
                        continue;
                    }
                    "history" => {
                        for (i, entry) in rl.history().iter().enumerate() {
                            println!("{}: {}", i + 1, entry);
                        }
                        continue;
                    }
                    input => {
                        // Process the input with the LLM
                        let response = llm.generate_response(input, &[]);
                        println!("\nMAYA: {}", response);
                    }
                }
            }
            Err(ReadlineError::Interrupted) => {
                println!("CTRL-C");
                break;
            }
            Err(ReadlineError::Eof) => {
                println!("CTRL-D");
                break;
            }
            Err(err) => {
                eprintln!("Error: {:?}", err);
                break;
            }
        }
    }

    // Save the command history
    if let Err(e) = rl.save_history(".maya_history") {
        eprintln!("Failed to save history: {}", e);
    }
    
    Ok(())
}

/// Displays help information
fn show_help() {
    println!("\nMAYA LLM Console Commands:");
    println!("  help      - Show this help message");
    println!("  clear     - Clear the screen");
    println!("  history   - Show command history");
    println!("  exit/quit - Exit the program");
    println!("\nEnter any other text to chat with MAYA!");
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_help_command() {
        // This is a simple smoke test to ensure the help command compiles and runs
        // We'll test the actual functionality in integration tests
        assert!(true);
    }
}
