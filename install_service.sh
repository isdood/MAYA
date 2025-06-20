
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
