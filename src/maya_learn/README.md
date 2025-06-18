# MAYA Learning Service

A systemd service for continuous learning and pattern recognition in the MAYA AI ecosystem, enabling adaptive behavior and intelligent automation.

## Features

- **Continuous Learning**: Runs as a background service to learn from system and user patterns
- **Pattern Recognition**: Detects and learns patterns in system metrics, user behavior, and application usage
- **Adaptive Behavior**: Adjusts system behavior based on learned patterns and user preferences
- **Resource Optimization**: Implements intelligent resource management and power optimization
- **Privacy-Focused**: Optional data collection with configurable anonymization
- **Version Control Integration**: Automatically tracks learned patterns in Git
- **RESTful API**: Provides endpoints for interaction and monitoring

## Prerequisites

- Python 3.9+
- Rust 1.70+ (for performance-critical components)
- System dependencies:
  - `psutil` for system monitoring
  - `git` for version control integration
  - `build-essential` for compiling extensions

## Installation

### Quick Start (Development)

```bash
# Clone the repository
cd ~/MAYA

# Create and activate virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install in development mode with all dependencies
pip install -e ".[dev]"

# Install pre-commit hooks
pre-commit install
```

### System Installation

1. **Install system dependencies**:
   ```bash
   # On Arch Linux
   sudo pacman -S python python-pip python-virtualenv psutil git
   
   # On Ubuntu/Debian
   # sudo apt update
   # sudo apt install python3 python3-pip python3-venv python3-psutil git
   ```

2. **Create a dedicated user** (recommended):
   ```bash
   sudo useradd -r -s /sbin/nologin maya-learn
   sudo mkdir -p /var/lib/maya/learn
   sudo chown -R maya-learn:maya-learn /var/lib/maya/learn
   ```

3. **Install the package**:
   ```bash
   sudo -u maya-learn python -m venv /opt/maya/venv
   sudo -u maya-learn /opt/maya/venv/bin/pip install --upgrade pip
   sudo -u maya-learn /opt/maya/venv/bin/pip install -e .
   ```

4. **Configure systemd service**:
   ```bash
   # Create configuration directory
   sudo mkdir -p /etc/maya/learn
   sudo cp config/learn.yaml /etc/maya/learn/config.yaml
   
   # Create systemd service file
   cat > /etc/systemd/system/maya-learn.service << EOL
   [Unit]
   Description=MAYA Learning Service
   After=network.target
   StartLimitIntervalSec=0
   
   [Service]
   Type=simple
   User=maya-learn
   Group=maya-learn
   WorkingDirectory=/var/lib/maya/learn
   Environment="PYTHONUNBUFFERED=1"
   Environment="PYTHONPATH=/opt/maya/venv/lib/python3.9/site-packages"
   ExecStart=/opt/maya/venv/bin/python -m maya_learn.service --config /etc/maya/learn/config.yaml
   Restart=always
   RestartSec=5s
   
   # Resource limits
   MemoryHigh=4G
   MemoryMax=6G
   CPUQuota=75%
   LimitNOFILE=65535
   
   # Security
   NoNewPrivileges=true
   PrivateTmp=true
   ProtectSystem=full
   ProtectHome=read-only
   
   [Install]
   WantedBy=multi-user.target
   EOL
   
   # Reload systemd and enable service
   sudo systemctl daemon-reload
   sudo systemctl enable --now maya-learn.service
   ```

## Configuration

Edit `/etc/maya/learn/config.yaml` to customize the service behavior:

```yaml
# Learning configuration
learning:
  enabled: true
  interval: 300  # seconds between learning cycles
  max_patterns: 1000  # maximum number of patterns to store
  confidence_threshold: 0.7  # minimum confidence to consider a pattern valid

# Monitoring configuration
monitoring:
  system_metrics: true
  process_metrics: true
  network_metrics: true
  metrics_interval: 60  # seconds between metric collections

# Storage configuration
storage:
  data_dir: /var/lib/maya/learn/data
  patterns_file: patterns.json
  retention_days: 30
  
  # Sled database configuration
  sled:
    path: /var/lib/maya/learn/db
    cache_capacity: 1073741824  # 1GB
    compression: true
    checksum_verification: true

# Privacy settings
privacy:
  anonymize_ips: true
  anonymize_uuids: true
  max_retention_days: 90
  
# Git version control integration
git:
  enabled: true
  auto_commit: true
  auto_push: false
  commit_message: "[MAYA] Update learned patterns"
  branch: "main"
  remote: "origin"
  user_name: "MAYA Learning Service"
  user_email: "maya-learn@$(hostname)"

# API server configuration
api:
  enabled: true
  host: "127.0.0.1"
  port: 8080
  api_key: ""  # Set to a secure random string
  cors_origins: ["http://localhost:3000"]
  rate_limit: "100/minute"

# Logging configuration
logging:
  level: "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
  file: "/var/log/maya/learn.log"
  max_size: 10485760  # 10MB
  backup_count: 5
  json_format: false
```

## API Reference

### Authentication
All API endpoints require an API key set in the `X-API-Key` header.

### Endpoints

#### GET /api/v1/patterns
List all learned patterns.

**Query Parameters:**
- `type`: Filter by pattern type
- `confidence_min`: Minimum confidence threshold (0.0-1.0)
- `limit`: Maximum number of patterns to return
- `offset`: Pagination offset

**Response:**
```json
{
  "patterns": [
    {
      "id": "pattern_123",
      "type": "usage_pattern",
      "confidence": 0.95,
      "created_at": "2023-01-01T00:00:00Z",
      "data": {
        "pattern": "high_cpu_usage",
        "conditions": ["cpu_percent > 80"],
        "actions": ["notify_admin"]
      }
    }
  ],
  "total": 1,
  "offset": 0,
  "limit": 10
}
```

#### POST /api/v1/patterns/learn
Trigger a learning cycle.

**Request Body:**
```json
{
  "force": false,
  "full_analysis": false
}
```

**Response:**
```json
{
  "success": true,
  "new_patterns": 5,
  "duration_seconds": 12.5
}
```

#### GET /api/v1/metrics
Get current system metrics.

**Response:**
```json
{
  "cpu": {
    "percent": 23.5,
    "cores": 8,
    "load_avg": [1.2, 1.5, 1.8]
  },
  "memory": {
    "total": 17179869184,
    "available": 8589934592,
    "percent": 50.0,
    "used": 8589934592
  },
  "disk": {
    "total": 107374182400,
    "used": 53687091200,
    "free": 53687091200,
    "percent": 50.0
  },
  "network": {
    "bytes_sent": 12345678,
    "bytes_recv": 87654321,
    "packets_sent": 12345,
    "packets_recv": 54321
  },
  "timestamp": "2023-01-01T12:00:00Z"
}
```

## Integration with MAYA Ecosystem

### Knowledge Graph Integration

MAYA Learn can store learned patterns in the MAYA Knowledge Graph for advanced querying and analysis:

```python
from maya_learn import MayaLerningService
from maya_knowledge_graph import Graph, SledStorage

# Initialize services
learn_service = MayaLerningService()
kg_storage = SledStorage("/var/lib/maya/knowledge")
kg = Graph(kg_storage)

# Store a learned pattern in the knowledge graph
async def store_pattern(pattern):
    node = {
        "type": "learned_pattern",
        "pattern_type": pattern.pattern_type,
        "confidence": pattern.confidence,
        "data": pattern.data,
        "created_at": pattern.created_at
    }
    await kg.add_node(f"pattern_{pattern.id}", node)
```

### STARWEAVE Integration

MAYA Learn can be integrated with STARWEAVE for distributed learning:

1. **Configure STARWEAVE in `config.yaml`**:
   ```yaml
   starweave:
     enabled: true
     cluster_name: "maya_learn_cluster"
     node_type: "learner"  # or "coordinator"
     coordinator_url: "http://coordinator:8080"
     sync_interval: 300  # seconds
   ```

2. **Start the service with STARWEAVE support**:
   ```bash
   python -m maya_learn.service --config /etc/maya/learn/config.yaml --enable-starweave
   ```

## Development

### Project Structure

```
maya_learn/
├── __init__.py           # Package definition
├── service.py            # Main service implementation
├── patterns.py           # Pattern learning and detection
├── monitor.py            # System monitoring
├── config.py             # Configuration management
├── api/                  # REST API implementation
│   ├── __init__.py
│   ├── server.py
│   ├── routes.py
│   └── models.py
├── storage/              # Storage backends
│   ├── __init__.py
│   ├── base.py
│   ├── filesystem.py
│   └── sled_store.py
├── tests/                # Unit and integration tests
│   ├── __init__.py
│   ├── test_patterns.py
│   └── test_service.py
└── scripts/              # Utility scripts
    ├── benchmark.py
    └── export_patterns.py
```

### Adding New Pattern Detectors

1. **Create a detection method** in `patterns.py`:
   ```python
   async def _detect_usage_patterns(self, metrics: SystemMetrics) -> List[Pattern]:
       """Detect usage patterns from system metrics."""
       patterns = []
       
       # Example: Detect high CPU usage
       if metrics.cpu.percent > self.config.learning.cpu_threshold:
           pattern = Pattern(
               id=generate_id(),
               pattern_type="high_cpu_usage",
               data={
                   "metric": "cpu_percent",
                   "threshold": self.config.learning.cpu_threshold,
                   "value": metrics.cpu.percent
               },
               confidence=min(1.0, metrics.cpu.percent / 100.0),
               created_at=time.time(),
               updated_at=time.time()
           )
           patterns.append(pattern)
       
       return patterns
   ```

2. **Register the detector** in the `process` method:
   ```python
   async def process(self, metrics: SystemMetrics) -> None:
       """Process metrics through all detectors."""
       if not self.config.learning.enabled or metrics is None:
           return
       
       patterns = []
       patterns.extend(await self._detect_usage_patterns(metrics))
       # Add more detectors here
       
       await self._process_patterns(patterns)
   ```

3. **Add tests** in `tests/test_patterns.py`

## Monitoring and Maintenance

### Logs

View service logs:
```bash
# Follow logs
journalctl -u maya-learn.service -f

# Filter by priority
journalctl -u maya-learn.service -p err

# Show logs since last hour
journalctl -u maya-learn.service --since "1 hour ago"
```

### Metrics

MAYA Learn exposes Prometheus metrics at `/metrics` when the API is enabled.

Key metrics:
- `maya_learn_patterns_total`: Total number of learned patterns
- `maya_learn_processing_seconds`: Time spent processing metrics
- `maya_learn_errors_total`: Total number of errors
- `maya_learn_memory_usage_bytes`: Current memory usage

### Backup and Recovery

#### Manual Backup

```bash
# Create backup directory
BACKUP_DIR="/var/backups/maya/learn/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Stop the service
sudo systemctl stop maya-learn.service

# Backup data
sudo -u maya-learn cp -r /var/lib/maya/learn/data "$BACKUP_DIR/"
sudo -u maya-learn cp /etc/maya/learn/config.yaml "$BACKUP_DIR/"

# Restart the service
sudo systemctl start maya-learn.service
```

#### Automated Backups with systemd

Create a timer for daily backups:

```bash
# /etc/systemd/system/maya-learn-backup.service
[Unit]
Description=MAYA Learn Backup
After=maya-learn.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/maya-learn-backup.sh

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/maya-learn-backup.timer
[Unit]
Description=Run MAYA Learn backup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

## Troubleshooting

### Common Issues

1. **Service fails to start**
   - Check logs: `journalctl -u maya-learn.service -n 50`
   - Verify permissions on data directory
   - Check if port is already in use

2. **High CPU/Memory Usage**
   - Adjust resource limits in systemd service file
   - Reduce monitoring frequency
   - Increase pattern cleanup interval

3. **Patterns not being detected**
   - Verify metrics collection is working
   - Check confidence thresholds
   - Enable debug logging

### Getting Help

- Check the [MAYA Documentation](https://maya-ai.dev/docs)
- Open an issue on [GitHub](https://github.com/your-org/maya/issues)
- Join our [Discord community](https://discord.gg/maya-ai)

## License

MAYA Learn is licensed under the [MIT License](LICENSE).

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for more information.

## Acknowledgments

- Thanks to all our contributors
- Built with ❤️ by the MAYA AI team
