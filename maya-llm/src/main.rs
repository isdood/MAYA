mod console;

use maya_llm::BasicLLM;
use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    println!("MAYA LLM - Interactive Console (type 'help' for commands)");
    
    // Initialize the LLM with default patterns
    let mut llm = BasicLLM::new();
    
    // Start the console interface
    console::run(&mut llm)?;
    
    Ok(())
}
