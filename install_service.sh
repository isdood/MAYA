@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 15:17:02",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./install_service.sh",
    "type": "sh",
    "hash": "42d3543fcb09c76c588d8346ae687ab18278d2e9"
  }
}
@pattern_meta@

#!/bin/bash
set -e

# Configuration
SERVICE_USER=$(whoami)
SERVICE_GROUP=$(id -gn)
PROJECT_DIR="/home/$(whoami)/MAYA"

# Create the service file directly
sudo tee /etc/systemd/system/maya-learn.service > /dev/null << SERVICE_FILE
[Unit]
Description=MAYA Learning Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$PROJECT_DIR
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=$PROJECT_DIR/src"
ExecStart=/bin/bash $PROJECT_DIR/scripts/run_maya_learn.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_FILE

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable maya-learn
sudo systemctl start maya-learn

echo "Service installed and started successfully!"
echo "Check status with: systemctl status maya-learn"
echo "View logs with: journalctl -u maya-learn -f"
