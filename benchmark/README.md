@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 12:32:01",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./benchmark/README.md",
    "type": "md",
    "hash": "7f6fcd146f371f06ba67caefd74db2dc2bc82093"
  }
}
@pattern_meta@

# Storage Engine Benchmarking

This directory contains the benchmarking infrastructure for comparing different storage engines
used in the MAYA Knowledge Graph.

## Available Benchmarks

### Storage Engine Comparison (`compare_storage_engines`)

Compares the performance of different storage backends (Sled and RocksDB) for various operations:

- **Write Performance**: Single write operations with different value sizes
- **Read Performance**: Single read operations
- **Batch Writes**: Bulk insertion performance with different batch sizes
- **Iteration**: Performance of prefix-based iteration

## Prerequisites

- Rust toolchain (stable)
- Python 3.7+
- Required Python packages: `statistics` (in Python standard library)

## Running Benchmarks

### 1. Run All Benchmarks and Generate Report

```bash
# Make the script executable
chmod +x benchmark/run_benchmarks.py

# Run the benchmark script
./benchmark/run_benchmarks.py
```

This will:
1. Run all benchmarks
2. Save raw results to `performance_reports/benchmark_results.json`
3. Generate a markdown report at `performance_reports/performance_report.md`

### 2. Run Specific Benchmarks

You can run specific benchmarks using Cargo:

```bash
# Run all benchmarks
cargo bench --package maya_knowledge_graph --bench compare_storage_engines

# Run a specific benchmark
cargo bench --package maya_knowledge_graph --bench compare_storage_engines -- sled_benchmark
```

## Interpreting Results

The benchmark report includes:

1. **Throughput Comparison**: Median operation times for each storage engine
2. **Performance Comparison**: Relative performance between engines
3. **Statistical Information**: Min, max, mean, and standard deviation of measurements

## Continuous Benchmarking

To set up continuous benchmarking:

1. **GitHub Actions**: Add a workflow to run benchmarks on push to main and PRs
2. **Performance Tracking**: Use tools like [criterion-compare-action](https://github.com/rhysd/github-action-benchmark) to track performance over time
3. **Alerting**: Set up alerts for performance regressions

## Adding New Benchmarks

1. Create a new benchmark file in `src/knowledge_graph/benches/`
2. Add your benchmark to the appropriate Criterion benchmark group
3. Update the analysis script if needed to handle new benchmark types

## Troubleshooting

- **Benchmarks are slow**: Ensure you're running in release mode (`cargo bench` automatically does this)
- **Permission errors**: Make sure the script is executable
- **Missing dependencies**: Install any required system dependencies for the storage engines

## License

Proprietary - © 2025 MAYA AI. All rights reserved.
