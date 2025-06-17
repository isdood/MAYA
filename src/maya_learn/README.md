# MAYA Learning Service

A systemd service for continuous learning and pattern recognition in the MAYA AI ecosystem.

## Features

- **Continuous Learning**: Runs as a background service to learn from system and user patterns
- **Pattern Recognition**: Detects and learns patterns in system metrics, user behavior, and more
- **Git Integration**: Automatically tracks learned patterns in Git for version control
- **Resource-Aware**: Respects system resources with configurable limits
- **Privacy-Focused**: Optional data collection with anonymization

## Installation

1. **Install Dependencies**:
   ```bash
   # On Arch Linux
   sudo pacman -S python python-pip python-virtualenv
   
   # Install system dependencies
   sudo pacman -S psutil
   ```

2. **Create and Activate Virtual Environment**:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```

3. **Install the Package**:
   ```bash
   pip install -e .
   ```

4. **Install as Systemd Service**:
   ```bash
   # Create systemd service file
   cat > /etc/systemd/system/maya-learn.service << EOL
   [Unit]
   Description=MAYA Learning Service
   After=network.target
   
   [Service]
   Type=simple
   User=$USER
   WorkingDirectory=$(pwd)
   Environment="PATH=$(pwd)/.venv/bin:$PATH"
   ExecStart=$(pwd)/.venv/bin/python -m maya_learn.service --config $(pwd)/config/learn.yaml
   Restart=always
   RestartSec=5s
   
   # Resource management
   MemoryHigh=4G
   MemoryMax=6G
   CPUQuota=75%
   
   [Install]
   WantedBy=multi-user.target
   EOL
   
   # Reload systemd and enable service
   sudo systemctl daemon-reload
   sudo systemctl enable maya-learn.service
   sudo systemctl start maya-learn.service
   ```

## Configuration

Edit `config/learn.yaml` to customize the service behavior. Key options include:

- `learning`: Control the learning behavior and pattern detection
- `monitoring`: Adjust monitoring intervals
- `storage`: Configure data storage locations and retention
- `privacy`: Manage data collection preferences
- `git`: Configure Git integration for pattern tracking

## Development

### Setting Up Development Environment

1. Install development dependencies:
   ```bash
   pip install -e ".[dev]"
   pre-commit install
   ```

2. Run tests:
   ```bash
   pytest tests/ -v
   ```

3. Run linters:
   ```bash
   black src/
   isort src/
   flake8 src/
   mypy src/
   ```

### Adding New Pattern Detectors

1. Create a new method in `patterns.py` following the `_detect_*` naming convention
2. Add a call to your detector in the `process` method
3. Define pattern types and their schemas
4. Add tests for your detector

## Git Integration

The service can automatically commit learned patterns to Git. To enable:

1. Initialize a Git repository if not already done:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   ```

2. Configure Git integration in `config/learn.yaml`:
   ```yaml
   git:
     enabled: true
     auto_commit: true
     commit_message: "[MAYA] Update learned patterns"
     branch: "main"
     remote: "origin"  # Optional, for automatic pushing
   ```

## Monitoring

View service logs:
```bash
journalctl -u maya-learn.service -f
```

## License

MIT
