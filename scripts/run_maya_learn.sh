#!/usr/bin/env bash
set -e  # Exit on error

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_DIR/.venv"

# Debug information
echo "[$(date)] Starting MAYA Learning Service"
echo "Project directory: $PROJECT_DIR"
echo "Virtual environment: $VENV_DIR"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "Error: Virtual environment not found at $VENV_DIR" >&2
    exit 1
fi

# Activate the virtual environment
if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
else
    echo "Error: Virtual environment activation script not found" >&2
    exit 1
fi

# Add src to PYTHONPATH
export PYTHONPATH="$PROJECT_DIR/src:$PYTHONPATH"

# Debug information
echo "Python: $(which python)"
echo "PYTHONPATH: $PYTHONPATH"
echo "Current directory: $(pwd)"

# Check if the config file exists
CONFIG_FILE="$PROJECT_DIR/config/learn.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE" >&2
    exit 1
fi

# Run the service
echo "Starting service with config: $CONFIG_FILE"
exec python -m maya_learn.service --config "$CONFIG_FILE"
