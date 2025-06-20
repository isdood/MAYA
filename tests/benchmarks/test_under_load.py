
#!/usr/bin/env python3
"""
Load testing for MAYA Monitoring System

This script simulates different system load conditions and measures
how the monitoring system performs under stress.

Memory Safety Features:
- Memory limits to prevent system crashes
- Automatic cleanup of resources
- Graceful degradation under memory pressure
- Detailed memory usage logging
"""

# Memory safety imports
from .memory_safe_runner import (
    memory_safe, 
    MemoryMonitor, 
    log_memory_usage,
    MemoryLimitExceededError
)

import asyncio
import time
import random
import psutil
import numpy as np
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
import json
import platform
import socket
import subprocess
from concurrent.futures import ThreadPoolExecutor

# Add project root to path
import sys
sys.path.append(str(Path(__file__).parent.parent))

from src.maya_learn.monitor import SystemMonitor, SystemMetrics
from src.maya_learn.config import Config

@dataclass
class LoadTestConfig:
    """Configuration for load testing."""
    duration: int = 300  # Test duration in seconds
    cpu_loads: List[float] = None  # List of CPU load percentages to test
    memory_loads: List[float] = None  # List of memory load percentages to test
    io_loads: List[float] = None  # List of I/O load levels to test
    network_loads: List[float] = None  # List of network load levels to test
    
    def __post_init__(self):
        if self.cpu_loads is None:
            self.cpu_loads = [0.25, 0.5, 0.75, 1.0]  # 25%, 50%, 75%, 100% CPU
        if self.memory_loads is None:
            self.memory_loads = [0.25, 0.5, 0.75]  # 25%, 50%, 75% memory
        if self.io_loads is None:
            self.io_loads = [0.25, 0.5, 0.75]  # Low, medium, high I/O
        if self.network_loads is None:
            self.network_loads = [0.25, 0.5, 0.75]  # Low, medium, high network

@dataclass
class LoadTestResult:
    """Results from a single load test."""
    test_name: str
    load_level: float
    metrics: Dict[str, float]
    system_metrics: Dict[str, float]
    timestamp: float = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = time.time()

class LoadTester:
    """Load testing framework for MAYA Monitoring System."""
    
    def __init__(self, config: LoadTestConfig = None):
        """Initialize the load tester."""
        self.config = config or LoadTestConfig()
        self.results = []
        self._stop_event = asyncio.Event()
        self._load_processes = []
        self._monitor = SystemMonitor(Config())
        self._results_dir = Path("tests/results/load_tests")
        self._results_dir.mkdir(parents=True, exist_ok=True)
    
    async def start_monitoring(self):
        """Start the monitoring system."""
        await self._monitor.start()
    
    async def stop_monitoring(self):
        """Stop the monitoring system."""
        await self._monitor.stop()
    
    async def run_cpu_load_test(self, load_level: float, duration: int):
        """Run a CPU load test."""
        test_name = f"cpu_load_{int(load_level*100)}%"
        print(f"\n🚀 Starting {test_name} test for {duration} seconds...")
        
        # Start CPU load
        load_process = self._start_cpu_load(load_level)
        
        # Run test
        result = await self._run_load_test(test_name, load_level, duration)
        
        # Stop CPU load
        self._stop_load_process(load_process)
        
        return result
    
    async def run_memory_load_test(self, load_level: float, duration: int):
        """Run a memory load test."""
        test_name = f"memory_load_{int(load_level*100)}%"
        print(f"\n🧠 Starting {test_name} test for {duration} seconds...")
        
        # Start memory load
        load_process = self._start_memory_load(load_level)
        
        # Run test
        result = await self._run_load_test(test_name, load_level, duration)
        
        # Stop memory load
        self._stop_load_process(load_process)
        
        return result
    
    async def run_io_load_test(self, load_level: float, duration: int):
        """Run an I/O load test."""
        test_name = f"io_load_{int(load_level*100)}%"
        print(f"\n💾 Starting {test_name} test for {duration} seconds...")
        
        # Start I/O load
        load_process = self._start_io_load(load_level)
        
        # Run test
        result = await self._run_load_test(test_name, load_level, duration)
        
        # Stop I/O load
        self._stop_load_process(load_process)
        
        return result
    
    async def run_network_load_test(self, load_level: float, duration: int):
        """Run a network load test."""
        test_name = f"network_load_{int(load_level*100)}%"
        print(f"\n🌐 Starting {test_name} test for {duration} seconds...")
        
        # Start network load
        load_process = self._start_network_load(load_level)
        
        # Run test
        result = await self._run_load_test(test_name, load_level, duration)
        
        # Stop network load
        self._stop_load_process(load_process)
        
        return result
    
    @memory_safe(0.8)  # Limit to 80% of available memory
    async def _run_load_test(self, test_name: str, load_level: float, duration: int) -> LoadTestResult:
        """Run a load test and collect metrics."""
        metrics = {
            "cpu_usage": [],
            "memory_usage": [],
            "io_reads": [],
            "io_writes": [],
            "network_sent": [],
            "network_recv": [],
            "response_times": []
        }
        
        start_time = time.time()
        
        try:
            while time.time() - start_time < duration and not self._stop_event.is_set():
                # Collect metrics
                metrics["cpu_usage"].append(psutil.cpu_percent(interval=0.1))
                metrics["memory_usage"].append(psutil.virtual_memory().percent)
                
                # Get disk I/O
                io = psutil.disk_io_counters()
                metrics["io_reads"].append(io.read_bytes)
                metrics["io_writes"].append(io.write_bytes)
                
                # Get network I/O
                net = psutil.net_io_counters()
                metrics["network_sent"].append(net.bytes_sent)
                metrics["network_recv"].append(net.bytes_recv)
                
                # Measure response time of getting metrics
                start = time.perf_counter()
                _ = self._monitor.get_metrics()
                metrics["response_times"].append((time.perf_counter() - start) * 1000)  # ms
                
                # Small sleep to prevent 100% CPU usage
                await asyncio.sleep(0.1)
                
        except asyncio.CancelledError:
            print("\nTest cancelled by user")
            raise
        
        # Calculate aggregated metrics
        def safe_avg(values):
            return sum(values) / len(values) if values else 0
        
        result = LoadTestResult(
            test_name=test_name,
            load_level=load_level,
            metrics={
                "avg_cpu_usage": safe_avg(metrics["cpu_usage"]),
                "max_cpu_usage": max(metrics["cpu_usage"], default=0),
                "avg_memory_usage": safe_avg(metrics["memory_usage"]),
                "max_memory_usage": max(metrics["memory_usage"], default=0),
                "avg_response_time_ms": safe_avg(metrics["response_times"]),
                "p95_response_time_ms": np.percentile(metrics["response_times"], 95) if metrics["response_times"] else 0,
                "max_response_time_ms": max(metrics["response_times"], default=0),
            },
            system_metrics={
                "io_read_mb": (metrics["io_reads"][-1] - metrics["io_reads"][0]) / (1024 * 1024) if len(metrics["io_reads"]) > 1 else 0,
                "io_write_mb": (metrics["io_writes"][-1] - metrics["io_writes"][0]) / (1024 * 1024) if len(metrics["io_writes"]) > 1 else 0,
                "network_sent_mb": (metrics["network_sent"][-1] - metrics["network_sent"][0]) / (1024 * 1024) if len(metrics["network_sent"]) > 1 else 0,
                "network_recv_mb": (metrics["network_recv"][-1] - metrics["network_recv"][0]) / (1024 * 1024) if len(metrics["network_recv"]) > 1 else 0,
            }
        )
        
        self.results.append(result)
        self._save_results()
        
        return result
    
    def _start_cpu_load(self, load_level: float) -> subprocess.Popen:
        """Start a CPU load generator."""
        # This is a simple CPU load generator using Python
        cmd = [
            "python3", "-c",
            f"while True: [i*i for i in range({int(1000000 * load_level)})]"
        ]
        return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    def _start_memory_load(self, load_level: float) -> subprocess.Popen:
        """
        Start a memory load generator with safety limits.
        
        Args:
            load_level: Fraction of total memory to use (0.0 - 1.0)
            
        Returns:
            subprocess.Popen: Process handle for the memory load
        """
        try:
            # Get available memory (leave some headroom)
            available_mem = psutil.virtual_memory().available
            max_safe_mb = int((available_mem * 0.8) / (1024 * 1024))  # Use 80% of available
            
            # Calculate target memory with upper bound
            total_memory = psutil.virtual_memory().total / (1024 * 1024)  # MB
            target_mb = min(int(total_memory * load_level), max_safe_mb)
            
            if target_mb < 10:  # Minimum 10MB to be meaningful
                raise MemoryError("Not enough available memory for test")
                
            logger.info(f"Allocating {target_mb}MB for memory load test "
                      f"(requested {int(total_memory * load_level)}MB)")
            
            # Use a generator to allocate memory in chunks
            cmd = [
                "python3", "-c",
                f"""
                import sys
                chunk_size = 10 * 1024 * 1024  # 10MB chunks
                chunks = []
                target = {target_mb} * 1024 * 1024
                allocated = 0
                
                print(f"Allocating {{target/1024/1024:.1f}}MB...")
                try:
                    while allocated < target:
                        chunk = ' ' * min(chunk_size, target - allocated)
                        chunks.append(chunk)
                        allocated += len(chunk)
                        print(f"Allocated {{allocated/1024/1024:.1f}}MB", end='\r')
                        
                    print("\nHolding memory...")
                    import time
                    time.sleep(3600)  # Hold for up to an hour
                except MemoryError:
                    print("\nMemory limit reached!")
                    sys.exit(1)
                """
            ]
            return subprocess.Popen(
                cmd, 
                stdout=subprocess.PIPE, 
                stderr=subprocess.PIPE,
                text=True
            )
            
        except Exception as e:
            logger.error(f"Failed to start memory load: {e}")
            raise
    
    def _start_io_load(self, load_level: float) -> subprocess.Popen:
        """Start an I/O load generator using Python's built-in I/O."""
        # Create a temporary file for I/O testing
        temp_file = "/tmp/io_load_test.bin"
        size_mb = int(100 * load_level)  # Up to 100MB
        chunk_size = 1024 * 1024  # 1MB chunks
        data = b'0' * chunk_size
        
        # Write data in chunks to create I/O load
        with open(temp_file, 'wb') as f:
            for _ in range(size_mb):
                f.write(data)
                f.flush()
        
        # Start a process that reads the file in a loop
        cmd = [
            "python3", "-c",
            f"data = open('{temp_file}', 'rb').read(); "
            "while True: [x for x in data]",
        ]
        return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    def _start_network_load(self, load_level: float) -> subprocess.Popen:
        """Start a network load generator."""
        # Simple network load using iperf3 (must be installed)
        # This is a placeholder - in a real scenario, you'd need an iperf3 server
        rate = f"{int(100 * load_level)}M"  # Up to 100Mbps
        cmd = ["ping", "-i", "0.1", "-s", "1000", "8.8.8.8"]
        return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    def _stop_load_process(self, process: subprocess.Popen):
        """Stop a load generation process."""
        try:
            process.terminate()
            process.wait(timeout=5)
        except (subprocess.TimeoutExpired, ProcessLookupError):
            try:
                process.kill()
            except:
                pass
    
    def _save_results(self):
        """Save test results to a file."""
        filename = f"load_test_results_{int(time.time())}.json"
        filepath = self._results_dir / filename
        
        # Convert results to dict
        results_data = {
            "system_info": self._get_system_info(),
            "timestamp": time.time(),
            "results": [asdict(r) for r in self.results]
        }
        
        with open(filepath, 'w') as f:
            json.dump(results_data, f, indent=2)
        
        return filepath
    
    def _get_system_info(self) -> Dict:
        """Get system information."""
        disk_usage = {}
        for partition in psutil.disk_partitions():
            if partition.mountpoint:
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    disk_usage[partition.mountpoint] = f"{usage.percent}%"
                except Exception as e:
                    disk_usage[partition.mountpoint] = f"Error: {str(e)}"
        
        return {
            "hostname": socket.gethostname(),
            "os": f"{platform.system()} {platform.release()}",
            "python_version": platform.python_version(),
            "cpu_count": psutil.cpu_count(),
            "cpu_freq": getattr(psutil.cpu_freq(), "current", "N/A"),
            "total_memory_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "disk_usage": disk_usage
        }

async def run_load_tests():
    """
    Run all load tests with memory safety.
    
    This function coordinates running different types of load tests
    while monitoring system resources to prevent crashes.
    """
    print("🚀 Starting MAYA Load Testing Suite")
    print("=" * 50)
    
    # Log initial memory state
    log_memory_usage("Initial")
    
    # Configure tests
    config = LoadTestConfig(
        duration=60,  # 1 minute per test
        cpu_loads=[0.25, 0.5, 0.75, 1.0],
        memory_loads=[0.25, 0.5, 0.75],
        io_loads=[0.25, 0.5, 0.75],
        network_loads=[0.25, 0.5, 0.75]
    )
    
    tester = LoadTester(config)
    
    try:
        # Start monitoring with memory safety
        print("\n🔄 Starting monitoring system with memory safety...")
        
        # Use memory monitor context
        with MemoryMonitor(threshold=0.8):
            await tester.start_monitoring()
            
            # Log memory after monitor start
            log_memory_usage("After monitor start")
        
        # Run CPU load tests with memory monitoring
        print("\n🔧 Running CPU load tests...")
        for load in config.cpu_loads:
            log_memory_usage(f"Before CPU load {int(load*100)}%")
            try:
                await tester.run_cpu_load_test(load, config.duration)
            except MemoryLimitExceededError as e:
                logger.error(f"Memory limit exceeded during CPU load test: {e}")
                logger.warning("Skipping remaining CPU load tests")
                break
            log_memory_usage(f"After CPU load {int(load*100)}%")
        
        # Run memory load tests with extra caution
        print("\n🧠 Running memory load tests...")
        for load in config.memory_loads:
            log_memory_usage(f"Before memory load {int(load*100)}%")
            try:
                await tester.run_memory_load_test(load, config.duration)
            except MemoryLimitExceededError as e:
                logger.error(f"Memory limit exceeded during memory load test: {e}")
                logger.warning("Skipping remaining memory load tests")
                break
            log_memory_usage(f"After memory load {int(load*100)}%")
        
        # Run I/O load tests with monitoring
        print("\n💾 Running I/O load tests...")
        for load in config.io_loads:
            log_memory_usage(f"Before I/O load {int(load*100)}%")
            try:
                await tester.run_io_load_test(load, config.duration)
            except MemoryLimitExceededError as e:
                logger.error(f"Memory limit exceeded during I/O test: {e}")
                logger.warning("Skipping remaining I/O tests")
                break
            log_memory_usage(f"After I/O load {int(load*100)}%")
        
        # Run network load tests with monitoring
        print("\n🌐 Running network load tests...")
        for load in config.network_loads:
            log_memory_usage(f"Before network load {int(load*100)}%")
            try:
                await tester.run_network_load_test(load, config.duration)
            except MemoryLimitExceededError as e:
                logger.error(f"Memory limit exceeded during network test: {e}")
                logger.warning("Skipping remaining network tests")
                break
            log_memory_usage(f"After network load {int(load*100)}%")
        
    except asyncio.CancelledError:
        print("\n⚠️  Tests cancelled by user")
    except Exception as e:
        print(f"\n❌ Error during testing: {e}")
        raise
    finally:
        # Stop monitoring
        print("\n🛑 Stopping monitoring system...")
        await tester.stop_monitoring()
        
        # Save final results
        results_file = tester._save_results()
        print(f"\n✅ Test results saved to: {results_file}")
        print("\n🎉 Load testing complete!")

if __name__ == "__main__":
    try:
        asyncio.run(run_load_tests())
    except KeyboardInterrupt:
        print("\n👋 Exiting...")
        sys.exit(0)
