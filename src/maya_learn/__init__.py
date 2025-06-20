
"""
MAYA Learning Service - Autonomous learning system for MAYA AI
"""

__version__ = "0.1.0"

import logging
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Base paths
PACKAGE_ROOT = Path(__file__).parent
PROJECT_ROOT = PACKAGE_ROOT.parent.parent
DATA_DIR = PROJECT_ROOT / 'data'
MODEL_DIR = DATA_DIR / 'models'
CONFIG_DIR = PROJECT_ROOT / 'config'
