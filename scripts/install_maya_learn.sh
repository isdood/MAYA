#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICE_USER=$(who am i | awk '{print $1}')
SERVICE_GROUP=${SERVICE_USER}
VENV_DIR="$PROJECT_DIR/.venv"

# Create necessary directories
mkdir -p /var/log/maya-learn
chown ${SERVICE_USER}:${SERVICE_GROUP} /var/log/maya-learn
chmod 755 /var/log/maya-learn

# Ensure virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python -m venv "$VENV_DIR"
    
    # Activate virtual environment and install dependencies
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$PROJECT_DIR/requirements-learn.txt"
    deactivate
else
    echo "Virtual environment already exists at $VENV_DIR"
fi

# Ensure we have the Python path from the virtual environment
PYTHON_PATH="$VENV_DIR/bin/python"
if [ ! -f "$PYTHON_PATH" ]; then
    echo "Error: Python not found in virtual environment at $PYTHON_PATH"
    exit 1
fi

# Create systemd service file
cat > /etc/systemd/system/maya-learn.service << EOL
[Unit]
Description=MAYA Learning Service
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${PROJECT_DIR}
Environment="PYTHONPATH=${PROJECT_DIR}/src"
ExecStart=${PYTHON_PATH} -m maya_learn.service --config ${PROJECT_DIR}/config/learn.yaml
Environment=PATH=${VENV_DIR}/bin:${PATH}
Restart=always
RestartSec=10

# Security options
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true
ProtectHome=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=true
MemoryDenyWriteExecute=true
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

# Set permissions on the service file
chmod 644 /etc/systemd/system/maya-learn.service

# Reload systemd to recognize the new service
systemctl daemon-reload

# Enable and start the service
systemctl enable maya-learn.service
systemctl start maya-learn.service

echo "MAYA Learning Service has been installed and started"
echo "Check status with: systemctl status maya-learn"
echo "View logs with: journalctl -u maya-learn -f"

exit 0
