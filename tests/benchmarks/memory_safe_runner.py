@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 16:33:03",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./tests/benchmarks/memory_safe_runner.py",
    "type": "py",
    "hash": "f3ae683a1b56a714f4b3e9f31eb28b880ec06fc7"
  }
}
@pattern_meta@

#!/usr/bin/env python3
"""
Memory-safe runner for load tests.

This module provides utilities to run load tests with memory constraints
and automatic cleanup to prevent system crashes.
"""

import os
import psutil
import signal
import resource
import logging
from typing import Callable, Optional, Dict, Any
from functools import wraps

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("memory_safe_runner")

class MemoryLimitExceededError(Exception):
    """Raised when a memory limit is exceeded."""
    pass

def set_memory_limit(percentage: float = 0.8):
    """
    Set a soft memory limit as a percentage of available memory.
    
    Args:
        percentage: Fraction of total memory to use as limit (0.0 - 1.0)
    """
    if not (0 < percentage <= 1.0):
        raise ValueError("Memory percentage must be between 0 and 1")
    
    # Get total available memory in bytes
    total_mem = psutil.virtual_memory().total
    soft_limit = int(total_mem * percentage)
    
    # Get the current limit
    soft, hard = resource.getrlimit(resource.RLIMIT_AS)
    
    # Set the new limit, but not higher than the hard limit
    new_soft = min(soft_limit, hard) if hard != resource.RLIM_INFINITY else soft_limit
    
    logger.info(f"Setting memory limit to {new_soft / (1024**3):.2f} GB "
                f"({percentage*100:.0f}% of {total_mem / (1024**3):.2f} GB)")
    
    resource.setrlimit(
        resource.RLIMIT_AS,
        (new_soft, hard)
    )

def memory_safe(percentage: float = 0.8):
    """
    Decorator to limit memory usage of a function.
    
    Args:
        percentage: Maximum fraction of total memory to use
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Set memory limit
            set_memory_limit(percentage)
            
            # Set up signal handler for memory errors
            def handle_memory_error(signum, frame):
                raise MemoryLimitExceededError(
                    f"Memory usage exceeded {percentage*100:.0f}% of available memory"
                )
            
            # Save old signal handler
            old_handler = signal.signal(signal.SIGXCPU, handle_memory_error)
            
            try:
                return func(*args, **kwargs)
            finally:
                # Restore original signal handler
                signal.signal(signal.SIGXCPU, old_handler)
        return wrapper
    return decorator

class MemoryMonitor:
    """Context manager to monitor memory usage."""
    
    def __init__(self, threshold: float = 0.9, interval: float = 0.1):
        """
        Initialize the memory monitor.
        
        Args:
            threshold: Fraction of total memory at which to warn (0.0 - 1.0)
            interval: Check interval in seconds
        """
        self.threshold = threshold
        self.interval = interval
        self.process = psutil.Process()
        self.running = False
        
    def __enter__(self):
        self.running = True
        self.monitor_thread = threading.Thread(target=self._monitor_memory)
        self.monitor_thread.daemon = True
        self.monitor_thread.start()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.running = False
        self.monitor_thread.join()
    
    def _monitor_memory(self):
        """Monitor memory usage in a background thread."""
        while self.running:
            try:
                mem = psutil.virtual_memory()
                used_percent = mem.percent / 100
                
                if used_percent > self.threshold:
                    logger.warning(
                        f"High memory usage: {mem.percent}% "
                        f"(threshold: {self.threshold*100:.0f}%)"
                    )
                    
                    # Suggest action if memory is critically high
                    if used_percent > 0.95:
                        logger.warning(
                            "Critical memory usage! Consider reducing the load or "
                            "increasing system memory."
                        )
                
                time.sleep(self.interval)
                
            except Exception as e:
                logger.error(f"Error in memory monitor: {e}")
                time.sleep(1)  # Prevent tight loop on error

def get_current_memory() -> Dict[str, Any]:
    """Get current memory usage statistics."""
    mem = psutil.virtual_memory()
    process = psutil.Process()
    
    return {
        "system": {
            "total_gb": mem.total / (1024**3),
            "available_gb": mem.available / (1024**3),
            "used_gb": mem.used / (1024**3),
            "percent": mem.percent,
            "free_gb": mem.free / (1024**3)
        },
        "process": {
            "rss_gb": process.memory_info().rss / (1024**3),
            "vms_gb": process.memory_info().vms / (1024**3),
            "percent": process.memory_percent()
        }
    }

def log_memory_usage(label: str = ""):
    """Log current memory usage with an optional label."""
    mem = get_current_memory()
    s = mem["system"]
    p = mem["process"]
    
    logger.info(
        f"{label} Memory - System: {s['used_gb']:.2f}/{s['total_gb']:.2f} GB "
        f"({s['percent']:.1f}%), Process: {p['rss_gb']:.2f} GB ({p['percent']:.1f}%)"
    )

if __name__ == "__main__":
    # Example usage
    import time
    import threading
    
    @memory_safe(0.5)  # Limit to 50% of available memory
    def test_memory():
        print("Starting memory test...")
        data = []
        try:
            # This will eventually hit the memory limit
            while True:
                data.append(' ' * 10**6)  # 1MB chunks
                time.sleep(0.01)
        except MemoryLimitExceededError as e:
            print(f"Caught memory limit: {e}")
    
    with MemoryMonitor(threshold=0.8):
        test_memory()
