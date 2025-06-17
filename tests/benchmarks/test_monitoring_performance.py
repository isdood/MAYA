#!/usr/bin/env python3
"""
Performance testing for MAYA Monitoring System

This script measures the performance characteristics of the monitoring system,
including CPU/memory overhead and response times.
"""

import asyncio
import time
import psutil
import statistics
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple
import json

# Add project root to path
import sys
sys.path.append(str(Path(__file__).parent.parent))

from src.maya_learn.monitor import SystemMonitor
from src.maya_learn.config import Config

class PerformanceTester:
    """Performance testing framework for MAYA monitoring."""
    
    def __init__(self, config_path: str = None):
        """Initialize the performance tester."""
        self.config = Config() if config_path is None else Config.from_file(config_path)
        self.monitor = SystemMonitor(self.config)
        self.results_dir = Path("tests/results")
        self.results_dir.mkdir(exist_ok=True)
        self.test_start_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.results = {
            "test_start_time": self.test_start_time,
            "system_info": self._get_system_info(),
            "tests": {}
        }
    
    def _get_system_info(self) -> Dict:
        """Collect system information."""
        return {
            "cpu_count": psutil.cpu_count(),
            "cpu_freq": psutil.cpu_freq()._asdict() if hasattr(psutil.cpu_freq(), '_asdict') else {},
            "total_memory_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "os": f"{platform.system()} {platform.release()}",
            "python_version": platform.python_version(),
            "hostname": platform.node()
        }
    
    async def measure_monitoring_overhead(self, duration: int = 60) -> Dict:
        """Measure the CPU and memory overhead of the monitoring system."""
        print(f"\nMeasuring monitoring overhead for {duration} seconds...")
        
        # Get baseline metrics
        baseline_cpu = psutil.cpu_percent(interval=1)
        baseline_mem = psutil.Process().memory_info().rss / (1024 * 1024)  # MB
        
        # Start monitoring
        await self.monitor.start()
        
        # Collect metrics
        cpu_usage = []
        mem_usage = []
        
        start_time = time.time()
        while time.time() - start_time < duration:
            cpu_usage.append(psutil.cpu_percent(interval=1))
            mem_usage.append(psutil.Process().memory_info().rss / (1024 * 1024))  # MB
        
        # Stop monitoring
        await self.monitor.stop()
        
        # Calculate results
        results = {
            "baseline_cpu_percent": baseline_cpu,
            "baseline_memory_mb": baseline_mem,
            "avg_cpu_percent": statistics.mean(cpu_usage) - baseline_cpu,
            "max_cpu_percent": max(cpu_usage) - baseline_cpu,
            "avg_memory_mb": statistics.mean(mem_usage) - baseline_mem,
            "max_memory_mb": max(mem_usage) - baseline_mem,
            "test_duration_seconds": duration
        }
        
        self.results["tests"]["monitoring_overhead"] = results
        return results
    
    async def measure_metric_collection_time(self, iterations: int = 100) -> Dict:
        """Measure the time taken to collect metrics."""
        print(f"\nMeasuring metric collection time over {iterations} iterations...")
        
        times = []
        await self.monitor.start()
        
        for _ in range(iterations):
            start_time = time.perf_counter()
            _ = self.monitor.get_metrics()
            times.append((time.perf_counter() - start_time) * 1000)  # Convert to ms
        
        await self.monitor.stop()
        
        results = {
            "iterations": iterations,
            "avg_time_ms": statistics.mean(times),
            "min_time_ms": min(times),
            "max_time_ms": max(times),
            "p95_time_ms": statistics.quantiles(times, n=20)[-1]  # 95th percentile
        }
        
        self.results["tests"]["metric_collection_time"] = results
        return results
    
    def save_results(self, filename: str = None) -> str:
        """Save test results to a JSON file."""
        if filename is None:
            filename = f"performance_test_{self.test_start_time}.json"
        
        output_path = self.results_dir / filename
        with open(output_path, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        return str(output_path)

async def run_performance_tests():
    """Run all performance tests and save results."""
    tester = PerformanceTester()
    
    print("Starting MAYA Monitoring Performance Tests")
    print("=" * 50)
    
    # Run tests
    overhead = await tester.measure_monitoring_overhead(duration=30)
    print("\nMonitoring Overhead:")
    print(f"  Avg CPU: {overhead['avg_cpu_percent']:.2f}%")
    print(f"  Max CPU: {overhead['max_cpu_percent']:.2f}%")
    print(f"  Avg Memory: {overhead['avg_memory_mb']:.2f} MB")
    print(f"  Max Memory: {overhead['max_memory_mb']:.2f} MB")
    
    collection = await tester.measure_metric_collection_time(iterations=100)
    print("\nMetric Collection Performance:")
    print(f"  Avg Time: {collection['avg_time_ms']:.4f} ms")
    print(f"  Min Time: {collection['min_time_ms']:.4f} ms")
    print(f"  Max Time: {collection['max_time_ms']:.4f} ms")
    print(f"  P95 Time: {collection['p95_time_ms']:.4f} ms")
    
    # Save results
    results_file = tester.save_results()
    print(f"\nResults saved to: {results_file}")
    print("\nPerformance testing complete!")

if __name__ == "__main__":
    import platform
    asyncio.run(run_performance_tests())
