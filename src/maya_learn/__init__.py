@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 13:57:27",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/maya_learn/__init__.py",
    "type": "py",
    "hash": "c7e1221d0fc8ec589b5c6b8d1ff21514235192f2"
  }
}
@pattern_meta@

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
