"""
MAYA Learning Service - Main service implementation
"""

import asyncio
import signal
import logging
from typing import Optional

from . import logger, __version__
from .config import load_config, Config
from .monitor import SystemMonitor
from .patterns import PatternLearner

class MayaLerningService:
    """Main service class for MAYA's continuous learning system."""
    
    def __init__(self, config_path: Optional[str] = None):
        """Initialize the learning service."""
        self.logger = logging.getLogger(__name__)
        self.config = load_config(config_path)
        self.running = False
        self.tasks = set()
        
        # Initialize components
        self.monitor = SystemMonitor(self.config)
        self.learner = PatternLearner(self.config)
        
        # Set up signal handlers
        self.setup_signal_handlers()
    
    def setup_signal_handlers(self):
        """Set up signal handlers for graceful shutdown."""
        loop = asyncio.get_running_loop()
        
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(
                sig, 
                lambda s=sig: asyncio.create_task(self.shutdown(s))
            )
    
    async def start(self):
        """Start the learning service."""
        if self.running:
            self.logger.warning("Service is already running")
            return
            
        self.running = True
        self.logger.info(f"Starting MAYA Learning Service v{__version__}")
        
        try:
            # Start monitoring
            monitor_task = asyncio.create_task(self.monitor.start())
            self.tasks.add(monitor_task)
            monitor_task.add_done_callback(self.tasks.discard)
            
            # Start learning loop
            learn_task = asyncio.create_task(self.learning_loop())
            self.tasks.add(learn_task)
            learn_task.add_done_callback(self.tasks.discard)
            
            # Keep the service running
            while self.running:
                await asyncio.sleep(1)
                
        except asyncio.CancelledError:
            self.logger.info("Service shutdown requested")
        except Exception as e:
            self.logger.error(f"Service error: {e}", exc_info=True)
        finally:
            await self.shutdown()
    
    async def learning_loop(self):
        """Main learning loop."""
        while self.running:
            try:
                # Get latest system data
                system_data = await self.monitor.get_metrics()
                
                # Learn from the data
                await self.learner.process(system_data)
                
                # Sleep for the configured interval
                await asyncio.sleep(self.config.learning.interval)
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                self.logger.error(f"Learning loop error: {e}", exc_info=True)
                await asyncio.sleep(5)  # Prevent tight loop on errors
    
    async def shutdown(self, signal=None):
        """Gracefully shut down the service."""
        if not self.running:
            return
            
        self.logger.info("Shutting down MAYA Learning Service...")
        self.running = False
        
        # Cancel all running tasks
        for task in self.tasks:
            if not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass
        
        # Clean up resources
        await self.learner.cleanup()
        await self.monitor.cleanup()
        
        self.logger.info("Service shutdown complete")


def main():
    """Entry point for the service."""
    import argparse
    
    parser = argparse.ArgumentParser(description="MAYA Learning Service")
    parser.add_argument(
        "-c", "--config", 
        help="Path to configuration file"
    )
    parser.add_argument(
        "-v", "--verbose", 
        action="store_true", 
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    # Configure logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Run the service
    service = MayaLerningService(args.config)
    
    try:
        asyncio.run(service.start())
    except KeyboardInterrupt:
        logger.info("Shutdown requested by user")
    except Exception as e:
        logger.critical(f"Fatal error: {e}", exc_info=True)
        return 1
    
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
