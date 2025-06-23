#!/bin/bash

set -e

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="performance_reports/zig_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

# Build with profiling enabled
echo "🔧 Building with profiling enabled..."
cd "$(git rev-parse --show-toplevel)"

# Clean previous build
rm -rf zig-cache zig-out

# Build with profiling
zig build -Doptimize=ReleaseSafe -Denable-profiling=true

# Run benchmarks and save output
echo "🚀 Running benchmarks..."
./zig-out/bin/test-patterns > "$OUTPUT_DIR/benchmark_output.txt" 2>&1

# Generate flamegraph if on Linux
if [[ "$(uname)" == "Linux" ]]; then
    echo "🔥 Generating flamegraph..."
    perf record -g -F 99 --call-graph dwarf \
        -o "$OUTPUT_DIR/perf.data" \
        ./zig-out/bin/test-patterns >/dev/null 2>&1
    
    perf script -i "$OUTPUT_DIR/perf.data" > "$OUTPUT_DIR/out.perf"
    
    # Install flamegraph if not present
    if ! command -v flamegraph &> /dev/null; then
        cargo install flamegraph
    fi
    
    flamegraph --perfdata "$OUTPUT_DIR/out.perf" \
        --title "MAYA Pattern Processing" \
        --width 1800 \
        --colors zig \
        --hash \
        --min-width 0.5 \
        --font-size 12 \
        --flamechart \
        > "$OUTPUT_DIR/flamegraph.svg"
    
    echo "📊 Flamegraph generated: $OUTPUT_DIR/flamegraph.svg"
fi

# Generate a summary report
{
    echo "# MAYA Zig Performance Benchmark Report"
    echo "Generated: $(date)"
    echo "Git Commit: $(git rev-parse HEAD)"
    echo ""
    echo "## System Information"
    echo "- CPU: $(lscpu | grep 'Model name' | cut -d ':' -f2 | xargs)"
    echo "- Cores: $(nproc)"
    echo "- Memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "- OS: $(uname -a)"
    echo "- Zig Version: $(zig version)"
    echo ""
    echo "## Benchmark Results"
    echo '```'
    grep -A 5 "=== Pattern Creation Benchmarks ===" "$OUTPUT_DIR/benchmark_output.txt" | head -20
    echo '```'
    echo ""
    echo "## Memory Usage"
    echo '```'
    grep -A 10 "=== Memory Usage Tests ===" "$OUTPUT_DIR/benchmark_output.txt" | head -15
    echo '```'
    
    if [[ -f "$OUTPUT_DIR/flamegraph.svg" ]]; then
        echo ""
        echo "## Flamegraph"
        echo "![Flamegraph](flamegraph.svg)"
    fi
    
} > "$OUTPUT_DIR/summary.md"

echo "✅ Benchmarks completed successfully!"
echo "📊 Results saved to: $OUTPUT_DIR"

# Update latest symlink
rm -f "performance_reports/zig_latest"
ln -s "$(basename "$OUTPUT_DIR")" "performance_reports/zig_latest"

# Open the results in default browser
if command -v xdg-open &> /dev/null; then
    xdg-open "$OUTPUT_DIR/summary.md"
elif command -v open &> /dev/null; then
    open "$OUTPUT_DIR/summary.md"
fi
