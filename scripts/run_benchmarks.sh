#!/bin/bash

set -e

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="performance_reports/$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

echo "🚀 Running storage benchmarks..."
cd src/knowledge_graph

# Install criterion if not already installed
cargo install cargo-criterion 2>/dev/null || true

# Run benchmarks and save output
cargo bench --bench storage_benchmark -- --verbose > "../../$OUTPUT_DIR/benchmark_output.txt" 2>&1

# Generate a summary report
{
    echo "# MAYA Performance Benchmark Report"
    echo "Generated: $(date)"
    echo "Git Commit: $(git rev-parse HEAD)"
    echo ""
    echo "## System Information"
    echo "- CPU: $(lscpu | grep 'Model name' | cut -d ':' -f2 | xargs)"
    echo "- Cores: $(nproc)"
    echo "- Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "- OS: $(uname -a)"
    echo ""
    echo "## Benchmark Results"
    echo '```'
    grep -A 10 "Benchmarking" "../../$OUTPUT_DIR/benchmark_output.txt"
    echo '```'
} > "../../$OUTPUT_DIR/summary.md"

echo "✅ Benchmarks completed successfully!"
echo "📊 Results saved to: $OUTPUT_DIR"

# Generate a comparison with the last run if available
if [ -d "performance_reports/latest" ]; then
    echo ""
    echo "📈 Comparison with previous run:"
    echo '```'
    echo "Current Run:"
    grep -A 5 "Benchmarking" "../../$OUTPUT_DIR/benchmark_output.txt" | head -6
    echo ""
    echo "Previous Run:"
    grep -A 5 "Benchmarking" "performance_reports/latest/benchmark_output.txt" | head -6
    echo '```'
fi

# Update latest symlink
ln -sfn "$TIMESTAMP" "performance_reports/latest"

echo ""
echo "📋 View the full report at: $OUTPUT_DIR/summary.md"
