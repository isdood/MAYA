@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 12:31:33",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./benchmark/run_benchmarks.py",
    "type": "py",
    "hash": "edb10ba1d6781ca1a8bd95e120f8105127e84b0c"
  }
}
@pattern_meta@

#!/usr/bin/env python3
"""
Run and compare storage engine benchmarks.

This script runs the benchmark suite for both Sled and RocksDB storage engines,
collects the results, and generates a comparison report.
"""

import json
import subprocess
import statistics
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Tuple

# Configuration
BENCHMARK_BIN = "cargo"
BENCHMARK_ARGS = ["bench", "--package", "maya_knowledge_graph", "--bench", "compare_storage_engines"]
OUTPUT_DIR = Path("performance_reports")
BENCHMARK_RESULTS = OUTPUT_DIR / "benchmark_results.json"
REPORT_FILE = OUTPUT_DIR / "performance_report.md"

def run_benchmarks() -> Dict[str, Any]:
    """Run the benchmarks and return the results as a dictionary."""
    print("🚀 Running benchmarks...")
    
    # Ensure output directory exists
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Run the benchmarks
    result = subprocess.run(
        [BENCHMARK_BIN, *BENCHMARK_ARGS, "--", "--output-format=json"],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"❌ Benchmark failed: {result.stderr}")
        exit(1)
    
    # Parse the JSON output
    try:
        # The output contains one JSON object per line
        results = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
        
        # Save raw results
        with open(BENCHMARK_RESULTS, 'w') as f:
            json.dump(results, f, indent=2)
            
        return results
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse benchmark results: {e}")
        print(f"Raw output: {result.stdout[:500]}...")  # Print first 500 chars of output
        exit(1)

def analyze_results(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Analyze benchmark results and return a structured report."""
    report = {
        "timestamp": datetime.utcnow().isoformat(),
        "engines": {},
        "comparisons": {}
    }
    
    # Group results by benchmark name and engine
    benchmarks = {}
    for result in results:
        if "reason" in result and result["reason"] == "benchmark-complete":
            name = result["id"]["name"]
            engine = name.split('_')[0]  # First part is the engine name
            benchmark_name = '_'.join(name.split('_')[1:])  # Rest is the benchmark name
            
            if engine not in benchmarks:
                benchmarks[engine] = {}
            
            if benchmark_name not in benchmarks[engine]:
                benchmarks[engine][benchmark_name] = []
                
            benchmarks[engine][benchmark_name].append(result)
    
    # Analyze each benchmark
    for engine, engine_benchmarks in benchmarks.items():
        report["engines"][engine] = {}
        
        for benchmark_name, runs in engine_benchmarks.items():
            # Extract relevant metrics
            durations = [run["typical"] for run in runs]
            
            report["engines"][engine][benchmark_name] = {
                "count": len(durations),
                "min": min(durations),
                "max": max(durations),
                "mean": statistics.mean(durations),
                "median": statistics.median(durations),
                "stdev": statistics.stdev(durations) if len(durations) > 1 else 0,
                "unit": runs[0]["unit"]
            }
    
    # Generate comparisons between engines
    if len(benchmarks) > 1:
        engines = list(benchmarks.keys())
        for benchmark_name in benchmarks[engines[0]].keys():
            if all(benchmark_name in benchmarks[e] for e in engines[1:]):
                # Calculate relative performance
                base_engine = engines[0]
                base_median = report["engines"][base_engine][benchmark_name]["median"]
                
                report["comparisons"][benchmark_name] = {}
                
                for engine in engines[1:]:
                    engine_median = report["engines"][engine][benchmark_name]["median"]
                    ratio = base_median / engine_median
                    report["comparisons"][benchmark_name][f"{base_engine}_vs_{engine}"] = {
                        "ratio": ratio,
                        "faster_by": f"{abs(1 - ratio) * 100:.1f}%",
                        "faster": ratio < 1.0
                    }
    
    return report

def generate_markdown_report(report: Dict[str, Any]) -> str:
    """Generate a markdown report from the analysis."""
    timestamp = datetime.fromisoformat(report["timestamp"]).strftime("%Y-%m-%d %H:%M:%S UTC")
    
    markdown = f"""# Storage Engine Benchmark Report

**Date:** {timestamp}  
**Environment:** {os.uname().sysname} {os.uname().machine}

## Results Summary

### Throughput Comparison (Higher is Better)

| Benchmark | {engines} |
|-----------|{dashes}|
""".format(
        timestamp=timestamp,
        engines=" | ".join(report["engines"].keys()),
        dashes=" | ".join(["---"] * (len(report["engines"]) + 1))
    )
    
    # Get all benchmark names
    benchmark_names = set()
    for engine_benchmarks in report["engines"].values():
        benchmark_names.update(engine_benchmarks.keys())
    
    # Add rows for each benchmark
    for benchmark in sorted(benchmark_names):
        row = [benchmark]
        for engine in report["engines"].keys():
            if benchmark in report["engines"][engine]:
                result = report["engines"][engine][benchmark]
                row.append(f"{result['median']:.2f} {result['unit']}")
            else:
                row.append("N/A")
        markdown += f"| {' | '.join(row)} |\n"
    
    # Add comparison section if we have comparisons
    if report["comparisons"]:
        markdown += "\n## Performance Comparison\n\n"
        markdown += "| Benchmark | Comparison | Performance |\n"
        markdown += "|-----------|------------|-------------|\n"
        
        for benchmark, comparisons in report["comparisons"].items():
            for comp_name, comp in comparisons.items():
                engine1, engine2 = comp_name.split("_vs_")
                faster = f"{engine1} is {comp['faster_by']} faster" if comp['faster'] else f"{engine2} is {comp['faster_by']} faster"
                markdown += f"| {benchmark} | {engine1} vs {engine2} | {faster} |\n"
    
    return markdown

def main():
    """Main function to run benchmarks and generate reports."""
    print("🔍 Analyzing benchmark results...")
    
    # Run benchmarks
    results = run_benchmarks()
    
    # Analyze results
    report = analyze_results(results)
    
    # Generate markdown report
    markdown = generate_markdown_report(report)
    
    # Save report
    with open(REPORT_FILE, 'w') as f:
        f.write(markdown)
    
    print(f"✅ Benchmark completed! Report saved to {REPORT_FILE}")
    print("\nSummary of results:")
    print(markdown.split("## Results Summary")[1])

if __name__ == "__main__":
    main()
