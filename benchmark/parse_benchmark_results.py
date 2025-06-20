@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 13:25:44",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./benchmark/parse_benchmark_results.py",
    "type": "py",
    "hash": "4ae2fb978420c6badc187f9d3a92d3c3baf28800"
  }
}
@pattern_meta@

#!/usr/bin/env python3
"""
Parse Criterion benchmark results and generate a markdown report.
"""
import json
import os
import statistics
from pathlib import Path
from datetime import datetime

def format_time(ns: float) -> str:
    """Format time in nanoseconds to appropriate unit."""
    for unit in ['ns', 'µs', 'ms', 's']:
        if ns < 1000 or unit == 's':
            return f"{ns:.2f} {unit}"
        ns /= 1000
    return f"{ns:.2f} s"

def format_throughput(ns: float, bytes: int) -> str:
    """Format throughput in MB/s."""
    if ns == 0:
        return "N/A"
    mb_per_second = (bytes / 1_000_000) / (ns / 1_000_000_000)
    return f"{mb_per_second:.2f} MB/s"

def parse_benchmark_results():
    """Parse all benchmark results and return structured data."""
    base_dir = Path("src/knowledge_graph/target/criterion")
    results = {}
    
    # Map benchmark names to display names and units
    benchmark_meta = {
        "sled_write_1kb": {"name": "Single Write (1KB)", "size": 1024},
        "sled_read_1kb": {"name": "Single Read (1KB)", "size": 1024},
        "sled_batch_write_100_items": {"name": "Batch Write (100 items, 512B each)", "size": 512 * 100},
        "sled_iterate_1000_items": {"name": "Iterate (1000 items)", "size": 1000 * 64},  # Assuming 64B per item
    }
    
    for bench_name, meta in benchmark_meta.items():
        result_file = base_dir / bench_name / "new" / "estimates.json"
        if not result_file.exists():
            print(f"Warning: {result_file} not found")
            continue
            
        with open(result_file) as f:
            data = json.load(f)
            
        mean_ns = data["mean"]["point_estimate"]
        throughput = format_throughput(mean_ns, meta["size"])
        
        results[bench_name] = {
            "name": meta["name"],
            "mean_time_ns": mean_ns,
            "mean_time": format_time(mean_ns),
            "throughput": throughput,
            "confidence_interval": {
                "lower": format_time(data["mean"]["confidence_interval"]["lower_bound"]),
                "upper": format_time(data["mean"]["confidence_interval"]["upper_bound"]),
            },
            "std_dev": format_time(data["std_dev"]["point_estimate"]),
        }
    
    return results

def generate_markdown(results: dict) -> str:
    """Generate markdown report from benchmark results."""
    lines = [
        "# Storage Engine Benchmark Results",
        "",
        "## Test Environment",
        f"- **Date**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "- **CPU**: AMD Ryzen 9 9950X 16-Core Processor (32 vCPUs)",
        "- **Memory**: 60GB total, 42GB available",
        "- **Storage**: NVMe SSD (1.9TB total, 57% used)",
        "- **Rust Version**: rustc 1.86.0 (05f9846f8 2025-03-31)",
        "- **Criterion Version**: 0.4.0",
        "",
        "## Results Summary",
        "",
        "| Benchmark | Mean Time | Throughput | 95% CI | Std Dev |",
        "|-----------|-----------|------------|---------|----------|",
    ]
    
    for bench in results.values():
        ci = f"{bench['confidence_interval']['lower']} - {bench['confidence_interval']['upper']}"
        lines.append(
            f"| {bench['name']} | {bench['mean_time']} | {bench['throughput']} | {ci} | {bench['std_dev']} |"
        )
    
    lines.extend([
        "",
        "## Detailed Results",
        "",
        "### Single Write (1KB)",
        "- **Mean Time**: Time to write a single 1KB value",
        "- **Throughput**: Data write speed",
        "",
        "### Single Read (1KB)",
        "- **Mean Time**: Time to read a single 1KB value",
        "- **Throughput**: Data read speed",
        "",
        "### Batch Write (100 items, 512B each)",
        "- **Mean Time**: Time to write 100 items in a batch",
        "- **Throughput**: Total data write speed for the batch",
        "",
        "### Iteration (1000 items)",
        "- **Mean Time**: Time to iterate over 1000 items with a common prefix",
        "- **Throughput**: Items processed per second",
        "",
        "## Analysis",
        "",
        "### Performance Characteristics",
        "- [Analysis of the results will go here]",
        "",
        "### Potential Bottlenecks",
        "1. [Bottleneck 1]",
        "2. [Bottleneck 2]",
        "",
        "### Recommendations for Optimization",
        "1. [Optimization 1]",
        "2. [Optimization 2]",
        "",
        "## Next Steps",
        "1. [ ] Run benchmarks with different payload sizes",
        "2. [ ] Test with larger datasets",
        "3. [ ] Compare with RocksDB once implemented",
        "4. [ ] Set up continuous benchmarking",
        "",
        "---",
        "*Generated by MAYA Benchmark Suite*"
    ])
    
    return "\n".join(lines)

def main():
    """Main function to parse and display benchmark results."""
    results = parse_benchmark_results()
    if not results:
        print("No benchmark results found.")
        return
    
    markdown = generate_markdown(results)
    
    # Write to results file
    output_file = Path("benchmark/RESULTS.md")
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(markdown)
    print(f"Results written to {output_file}")
    
    # Print summary to console
    print("\nBenchmark Results Summary:")
    print("-" * 50)
    for name, result in results.items():
        print(f"{result['name']}:")
        print(f"  Mean Time: {result['mean_time']}")
        print(f"  Throughput: {result['throughput']}")
        print(f"  95% CI: {result['confidence_interval']['lower']} - {result['confidence_interval']['upper']}")
        print(f"  Std Dev: {result['std_dev']}")
        print()

if __name__ == "__main__":
    main()
