
#!/usr/bin/env python3
"""
MAYA Learning Service Monitor

A console-based monitoring dashboard for the MAYA Learning Service.
"""

import os
import sys
import asyncio
import logging
from pathlib import Path

# Add project root to Python path
project_root = str(Path(__file__).parent.parent)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from src.maya_learn.config import load_config
from src.maya_learn.console_dashboard import run_console_dashboard

def setup_logging():
    """Configure logging for the monitoring script."""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('maya_monitor.log')
        ]
    )

async def async_main():
    """Async entry point for the monitoring script."""
    print("Starting MAYA Learning Service Monitor...")
    print("Press Ctrl+C to exit\n")
    
    try:
        # Load configuration
        config_path = os.path.join(project_root, 'config', 'learn.yaml')
        config = load_config(config_path)
        
        # Setup logging
        setup_logging()
        
        # Import here to avoid circular imports
        from src.maya_learn.monitor import SystemMonitor
        from src.maya_learn.console_dashboard import ConsoleDashboard
        
        # Initialize and start monitoring
        monitor = SystemMonitor(config)
        dashboard = ConsoleDashboard(monitor)
        
        # Start monitoring
        await monitor.start()
        dashboard.start()
        
        # Keep the dashboard running
        try:
            while True:
                await asyncio.sleep(1)
        except asyncio.CancelledError:
            print("\nShutting down monitor...")
        finally:
            dashboard.stop()
            await monitor.stop()
            print("Dashboard stopped.")
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        raise

def main():
    """Main entry point."""
    try:
        asyncio.run(async_main())
    except KeyboardInterrupt:
        print("\nShutdown requested. Exiting...")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
