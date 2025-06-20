@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 12:41:14",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./benchmark/run_benchmarks.sh",
    "type": "sh",
    "hash": "f28a72ebf3d6c1053d68f2928facac03fba9e47a"
  }
}
@pattern_meta@

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
