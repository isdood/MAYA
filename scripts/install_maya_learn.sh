
#!/bin/bash

# Exit on error
set -e

# Check if running as root, use sudo if not
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
    echo "This script requires root privileges. Using sudo..."
fi

# Function to run commands with sudo if needed
run_as_root() {
    if [ -n "$SUDO" ]; then
        $SUDO "$@"
    else
        "$@"
    fi
}

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_USER=$(who am i | awk '{print $1}')
SERVICE_GROUP=${SERVICE_USER}
VENV_DIR="$PROJECT_DIR/.venv"

# Create necessary directories
run_as_root mkdir -p /var/log/maya-learn
run_as_root chown ${SERVICE_USER}:${SERVICE_GROUP} /var/log/maya-learn
run_as_root chmod 755 /var/log/maya-learn

# Remove existing virtual environment if it exists
if [ -d "$VENV_DIR" ]; then
    echo "Removing existing virtual environment..."
    rm -rf "$VENV_DIR"
fi

# Create new virtual environment as current user
echo "Creating new virtual environment..."
python3 -m venv --clear --copies "$VENV_DIR"

# Ensure the virtual environment is owned by the current user
chown -R $USER:$USER "$VENV_DIR"

# Activate virtual environment and install dependencies
echo "Installing dependencies..."
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install -r "$PROJECT_DIR/requirements-learn.txt"
deactivate

# Set secure permissions for the virtual environment
chmod -R u+rwX,go-w "$VENV_DIR"
chmod -R go-w "$VENV_DIR/bin"

# Ensure scripts directory exists and is executable
run_as_root chmod +x "$PROJECT_DIR/scripts"/*.sh

# Verify the wrapper script exists
if [ ! -f "$PROJECT_DIR/scripts/run_maya_learn.sh" ]; then
    echo "Error: Wrapper script not found at $PROJECT_DIR/scripts/run_maya_learn.sh"
    exit 1
fi

# Make the wrapper script executable
run_as_root chmod +x "$PROJECT_DIR/scripts/run_maya_learn.sh"

# Verify the virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "Error: Virtual environment not found at $VENV_DIR"
    exit 1
fi

# Create a dedicated directory for logs
LOG_DIR="/var/log/maya-learn"
run_as_root mkdir -p "$LOG_DIR"
run_as_root chown -R ${SERVICE_USER}:${SERVICE_GROUP} "$LOG_DIR"
run_as_root chmod 755 "$LOG_DIR"

# Create systemd service file with absolute paths
SERVICE_TEMP=$(mktemp)
cat > "$SERVICE_TEMP" << EOL
[Unit]
Description=MAYA Learning Service
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${PROJECT_DIR}
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=${PROJECT_DIR}/src"
ExecStart=/bin/bash ${PROJECT_DIR}/scripts/run_maya_learn.sh
StandardOutput=append:${LOG_DIR}/maya-learn.log
StandardError=append:${LOG_DIR}/maya-learn-error.log
Restart=always
RestartSec=10

# Security options
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true
ProtectHome=true
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
SystemCallFilter=@system-service
SystemCallArchitectures=native

# Resource limits
CPUQuota=50%
MemoryMax=1G
MemorySwapMax=100M

[Install]
WantedBy=multi-user.target
EOL

# Install the service file
run_as_root cp "$SERVICE_TEMP" /etc/systemd/system/maya-learn.service
run_as_root chmod 644 /etc/systemd/system/maya-learn.service
run_as_root systemctl daemon-reload

# Clean up
rm -f "$SERVICE_TEMP"

# Enable and start the service
run_as_root systemctl enable maya-learn.service
run_as_root systemctl restart maya-learn.service

echo "MAYA Learning Service has been installed and started"
echo "Check status with: systemctl status maya-learn"
echo "View logs with: journalctl -u maya-learn -f"

exit 0
