""
System monitoring for MAYA Learning Service.
"""

import asyncio
import psutil
import platform
import logging
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path

from .config import Config

@dataclass
class SystemMetrics:
    """Container for system metrics."""
    timestamp: float
    cpu_percent: float
    memory_percent: float
    disk_usage: Dict[str, float]  # mount_point -> percent_used
    network_io: Dict[str, Any]    # interface -> {bytes_sent, bytes_recv, ...}
    processes: int
    load_avg: Dict[str, float]    # 1min, 5min, 15min
    boot_time: float
    users: int


class SystemMonitor:
    """Monitor system metrics and collect data for learning."""
    
    def __init__(self, config: Config):
        """Initialize the system monitor."""
        self.config = config
        self.logger = logging.getLogger(__name__)
        self._running = False
        self._metrics_cache = None
        self._lock = asyncio.Lock()
        self._tasks = set()
    
    async def start(self):
        """Start the monitoring service."""
        if self._running:
            self.logger.warning("Monitor is already running")
            return
            
        self._running = True
        self.logger.info("Starting system monitor")
        
        # Start monitoring tasks
        tasks = [
            self._monitor_cpu(),
            self._monitor_memory(),
            self._monitor_disk(),
            self._monitor_network(),
            self._monitor_system()
        ]
        
        self._tasks = {asyncio.create_task(t) for t in tasks}
        for task in self._tasks:
            task.add_done_callback(self._tasks.discard)
    
    async def stop(self):
        """Stop the monitoring service."""
        self._running = False
        for task in self._tasks:
            task.cancel()
        self.logger.info("System monitor stopped")
    
    async def cleanup(self):
        """Clean up resources."""
        await self.stop()
    
    async def get_metrics(self) -> Optional[SystemMetrics]:
        """Get the latest system metrics."""
        async with self._lock:
            return self._metrics_cache
    
    async def _monitor_cpu(self):
        """Monitor CPU usage."""
        while self._running:
            try:
                cpu_percent = psutil.cpu_percent(interval=1)
                load_avg = psutil.getloadavg()
                
                async with self._lock:
                    if self._metrics_cache is None:
                        self._metrics_cache = SystemMetrics(
                            timestamp=datetime.now().timestamp(),
                            cpu_percent=cpu_percent,
                            memory_percent=0.0,
                            disk_usage={},
                            network_io={},
                            processes=0,
                            load_avg={
                                '1min': load_avg[0],
                                '5min': load_avg[1],
                                '15min': load_avg[2]
                            },
                            boot_time=psutil.boot_time(),
                            users=len(psutil.users())
                        )
                    else:
                        self._metrics_cache.cpu_percent = cpu_percent
                        self._metrics_cache.load_avg = {
                            '1min': load_avg[0],
                            '5min': load_avg[1],
                            '15min': load_avg[2]
                        }
                
                await asyncio.sleep(self.config.monitoring.cpu_interval)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"CPU monitoring error: {e}")
                await asyncio.sleep(5)
    
    async def _monitor_memory(self):
        """Monitor memory usage."""
        while self._running:
            try:
                mem = psutil.virtual_memory()
                
                async with self._lock:
                    if self._metrics_cache is not None:
                        self._metrics_cache.memory_percent = mem.percent
                
                await asyncio.sleep(self.config.monitoring.memory_interval)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"Memory monitoring error: {e}")
                await asyncio.sleep(5)
    
    async def _monitor_disk(self):
        """Monitor disk usage."""
        while self._running:
            try:
                disk_usage = {}
                for part in psutil.disk_partitions():
                    try:
                        usage = psutil.disk_usage(part.mountpoint)
                        disk_usage[part.mountpoint] = usage.percent
                    except Exception as e:
                        self.logger.debug(f"Could not get disk usage for {part.mountpoint}: {e}")
                
                async with self._lock:
                    if self._metrics_cache is not None:
                        self._metrics_cache.disk_usage = disk_usage
                
                await asyncio.sleep(self.config.monitoring.disk_interval)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"Disk monitoring error: {e}")
                await asyncio.sleep(5)
    
    async def _monitor_network(self):
        """Monitor network I/O."""
        prev_io = psutil.net_io_counters(pernic=True)
        
        while self._running:
            try:
                await asyncio.sleep(self.config.monitoring.network_interval)
                
                curr_io = psutil.net_io_counters(pernic=True)
                net_io = {}
                
                for iface in curr_io:
                    prev = prev_io.get(iface)
                    curr = curr_io[iface]
                    
                    if prev is None:
                        continue
                    
                    time_diff = self.config.monitoring.network_interval
                    
                    net_io[iface] = {
                        'bytes_sent': curr.bytes_sent,
                        'bytes_recv': curr.bytes_recv,
                        'packets_sent': curr.packets_sent,
                        'packets_recv': curr.packets_recv,
                        'err_in': curr.errin,
                        'err_out': curr.errout,
                        'drop_in': curr.dropin,
                        'drop_out': curr.dropout,
                        'bytes_sent_ps': (curr.bytes_sent - prev.bytes_sent) / time_diff,
                        'bytes_recv_ps': (curr.bytes_recv - prev.bytes_recv) / time_diff,
                    }
                
                prev_io = curr_io
                
                async with self._lock:
                    if self._metrics_cache is not None:
                        self._metrics_cache.network_io = net_io
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"Network monitoring error: {e}")
                await asyncio.sleep(5)
    
    async def _monitor_system(self):
        """Monitor system-level metrics."""
        while self._running:
            try:
                async with self._lock:
                    if self._metrics_cache is not None:
                        self._metrics_cache.timestamp = datetime.now().timestamp()
                        self._metrics_cache.processes = len(psutil.pids())
                        self._metrics_cache.boot_time = psutil.boot_time()
                        self._metrics_cache.users = len(psutil.users())
                
                await asyncio.sleep(5)  # Update more frequently
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"System monitoring error: {e}")
                await asyncio.sleep(5)
