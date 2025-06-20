@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 17:26:53",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./scripts/run_knowledge_graph_tests.sh",
    "type": "sh",
    "hash": "0f488051152296a21f1595dcc988ee2e05ae33bb"
  }
}
@pattern_meta@

#!/bin/bash

# Exit on error
set -e

# Change to the knowledge graph directory
cd "$(dirname "$0")/../src/knowledge_graph"

# Format check
echo "Checking code formatting..."
cargo fmt -- --check

# Linting
echo "Running clippy..."
cargo clippy --all-targets -- -D warnings

# Run tests
echo "Running tests..."

# Run unit tests
echo "Running unit tests..."
cargo test --lib -- --nocapture

# Run integration tests
echo "Running integration tests..."
cargo test --test integration -- --nocapture

# Run graph tests
echo "Running graph tests..."
cargo test --test graph -- --nocapture

# Run storage tests
echo "Running storage tests..."
cargo test --test storage -- --nocapture

echo "All tests passed successfully!"
