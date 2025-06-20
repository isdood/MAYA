@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 15:38:48",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/maya_learn/console_dashboard.py",
    "type": "py",
    "hash": "c4b9c49a3bdd93cc8e5dd1e54e9999d2257a7973"
  }
}
@pattern_meta@

"""Console-based dashboard for MAYA Learning Service monitoring."""

import asyncio
import time
from datetime import datetime
from typing import Dict, Any, Optional

from rich.console import Console
from rich.layout import Layout
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, BarColumn, TextColumn, TimeElapsedColumn
from rich.live import Live
from rich.style import Style
from rich.text import Text

from .monitor import SystemMonitor, SystemMetrics
from .config import Config

class ConsoleDashboard:
    """Interactive console dashboard for monitoring MAYA Learning Service."""

    def __init__(self, monitor: SystemMonitor, update_interval: float = 1.0):
        """Initialize the console dashboard.
        
        Args:
            monitor: SystemMonitor instance to get metrics from
            update_interval: Update interval in seconds
        """
        self.monitor = monitor
        self.update_interval = update_interval
        self.console = Console()
        self.layout = self._create_layout()
        self.running = False
        self.start_time = time.time()

    def _create_layout(self) -> Layout:
        """Create the dashboard layout."""
        layout = Layout()
        layout.split(
            Layout(name="header", size=3),
            Layout(name="main", ratio=1),
            Layout(name="footer", size=3)
        )
        layout["main"].split_row(
            Layout(name="left", ratio=1),
            Layout(name="right", ratio=1)
        )
        return layout

    def _update_header(self) -> Panel:
        """Update the header panel."""
        uptime = time.time() - self.start_time
        hours, remainder = divmod(uptime, 3600)
        minutes, seconds = divmod(remainder, 60)
        uptime_str = f"{int(hours):02d}:{int(minutes):02d}:{int(seconds):02d}"
        
        title = Text("MAYA Learning Service Monitor", style="bold blue")
        title.append(f" | Uptime: {uptime_str}", style="green")
        
        return Panel(
            title,
            border_style="blue",
            padding=(1, 2)
        )

    def _create_metrics_table(self, metrics: SystemMetrics) -> Table:
        """Create a table with system metrics."""
        table = Table(show_header=False, box=None, padding=(0, 1))
        table.add_column("Metric", style="cyan", no_wrap=True)
        table.add_column("Value", style="green", justify="right")

        # CPU and Memory
        table.add_row("CPU Usage:", f"{metrics.cpu_percent:.1f}%")
        table.add_row("Memory Usage:", f"{metrics.memory_percent:.1f}%")
        
        # Disk usage
        for mount, usage in metrics.disk_usage.items():
            table.add_row(f"Disk ({mount}):", f"{usage:.1f}%")
        
        return table

    def _create_progress_bars(self, metrics: SystemMetrics) -> Table:
        """Create progress bars for key metrics."""
        bars = Table(show_header=False, box=None, padding=(0, 1))
        bars.add_column("Metric", style="cyan", no_wrap=True)
        bars.add_column("Progress", style="green", no_wrap=True)

        # CPU bar
        bars.add_row("CPU:", self._create_progress_bar(metrics.cpu_percent))
        
        # Memory bar
        bars.add_row("Memory:", self._create_progress_bar(metrics.memory_percent))
        
        # Disk bars
        for mount, usage in metrics.disk_usage.items():
            bars.add_row(f"Disk {mount}:", self._create_progress_bar(usage))
        
        return bars

    def _create_progress_bar(self, percent: float, width: int = 20) -> str:
        """Create a text-based progress bar."""
        filled = '█' * int(percent / 100 * width)
        empty = ' ' * (width - len(filled))
        return f"{filled}{empty} {percent:.1f}%"

    async def update(self) -> None:
        """Update the dashboard display."""
        try:
            with Live(self.layout, refresh_per_second=4, screen=True) as live:
                while self.running:
                    try:
                        metrics = self.monitor.get_metrics()
                        if metrics is None:
                            await asyncio.sleep(self.update_interval)
                            continue
                            
                        # Update header
                        self.layout["header"].update(self._update_header())
                        
                        # Update metrics table
                        table = self._create_metrics_table(metrics)
                        self.layout["left"].update(Panel(table, title="System Metrics"))
                        
                        # Update progress bars
                        bars = self._create_progress_bars(metrics)
                        self.layout["right"].update(Panel(bars, title="Resource Usage"))
                        
                        # Update footer
                        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        self.layout["footer"].update(
                            Panel(f"Last updated: {timestamp}", style="dim")
                        )
                    except Exception as e:
                        self.console.print(f"[red]Error updating dashboard: {e}[/]")
                    
                    await asyncio.sleep(self.update_interval)
        except asyncio.CancelledError:
            raise
        except Exception as e:
            self.console.print(f"[red]Fatal error in dashboard: {e}[/]")
            raise

    def start(self) -> None:
        """Start the dashboard."""
        self.running = True
        asyncio.create_task(self.update())

    def stop(self) -> None:
        """Stop the dashboard."""
        self.running = False


def run_console_dashboard(config: Config) -> None:
    """Run the console dashboard.
    
    Args:
        config: Application configuration
    """
    from .monitor import SystemMonitor
    
    try:
        monitor = SystemMonitor(config)
        dashboard = ConsoleDashboard(monitor)
        
        # Start monitoring
        monitor.start()
        dashboard.start()
        
        # Keep the dashboard running
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nShutting down dashboard...")
        finally:
            dashboard.stop()
            monitor.stop()
            print("Dashboard stopped.")
    except Exception as e:
        print(f"Error starting dashboard: {e}")
        raise
