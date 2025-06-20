@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-19 11:51:52",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./maya-llm/src/main.rs",
    "type": "rs",
    "hash": "1e53be3d70b8ec033ce6abb88bff7e34ac7e4089"
  }
}
@pattern_meta@

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
