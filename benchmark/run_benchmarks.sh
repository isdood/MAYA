#!/bin/bash
# Run benchmarks and update results

set -e

# Change to project root
cd "$(dirname "$0")/.."

# Run benchmarks
echo "Running benchmarks..."
cargo bench --bench compare_storage_engines

# Parse and update results
echo -e "\nUpdating results..."
python3 benchmark/parse_results.py

echo -e "\nBenchmark results have been updated in benchmark/RESULTS.md"
