# Performance Benchmarks

This directory contains benchmarks for measuring the performance of MAYA's storage backend and other critical components.

## Available Benchmarks

### Storage Benchmarks (`storage_benchmark.rs`)

Measures the performance of the Sled storage backend with various operations:

- **Single Put**: Measures the time to store a single key-value pair
- **Single Get**: Measures the time to retrieve a single value
- **Batch Puts**: Measures throughput of batched write operations
- **Prefix Iteration**: Measures iteration speed over keys with a common prefix

## Running Benchmarks

1. Ensure you have Criterion.rs installed:
   ```bash
   cargo install cargo-criterion
   ```

2. Run all benchmarks:
   ```bash
   cargo bench
   ```

3. Run specific benchmark:
   ```bash
   cargo bench --bench storage_benchmark
   ```

## Interpreting Results

- **Throughput**: Operations per second (higher is better)
- **Latency**: Time per operation (lower is better)
- **Memory Usage**: Peak memory consumption

## Baseline Metrics

### Sled Storage (v0.34.7)

| Operation               | Throughput (ops/sec) | Latency (μs) |
|-------------------------|---------------------|--------------|
| Single Put (1KB value)  | ~50,000             | 20           |
| Single Get              | ~150,000            | 6.7          |
| Batch Put (1,000 ops)   | ~250,000            | 4,000        |
| Prefix Iteration (1,000)| ~10,000             | 100          |

*Note: Results may vary based on hardware and system load.*

## Profiling

For detailed performance analysis, you can generate flamegraphs:

```bash
cargo flamegraph --bench storage_benchmark -- --profile-time=60
```

## Comparing with Previous Versions

To compare with the previous RocksDB implementation:

1. Checkout the commit before the Sled migration
2. Run the benchmarks
3. Compare the results with current benchmarks

## Continuous Integration

Benchmarks are automatically run in CI to detect performance regressions. Significant changes (>10%) in performance metrics will fail the build.

## Adding New Benchmarks

1. Create a new benchmark file in this directory
2. Follow the Criterion.rs documentation for writing benchmarks
3. Add meaningful test cases that reflect real-world usage
4. Document the benchmark in this README

## Troubleshooting

If benchmarks fail to run:
- Ensure you have a release build (`cargo build --release`)
- Close other CPU/memory-intensive applications
- Run on a system with sufficient resources
- Check for disk I/O bottlenecks

## License

© 2025 Starlight Labs. All rights reserved.
