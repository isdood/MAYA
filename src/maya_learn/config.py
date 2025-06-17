"""Configuration management for MAYA Learning Service."""

import os
from pathlib import Path
from typing import Optional, Dict, Any
import yaml
from pydantic import BaseModel, Field, validator

class LearningConfig(BaseModel):
    """Learning-related configuration."""
    enabled: bool = True
    interval: float = 60.0  # seconds
    batch_size: int = 100
    max_patterns: int = 1000

class MonitoringConfig(BaseModel):
    """System monitoring configuration."""
    cpu_interval: float = 5.0
    memory_interval: float = 10.0
    disk_interval: float = 30.0
    network_interval: float = 15.0

class StorageConfig(BaseModel):
    """Storage configuration."""
    data_dir: Path = Path("data/learn")
    model_dir: Path = Path("data/models")
    max_size_gb: float = 50.0
    retention_days: int = 30

class GitConfig(BaseModel):
    """Git integration configuration."""
    enabled: bool = True
    auto_commit: bool = True
    commit_message: str = "[MAYA] Autonomous learning update"
    branch: str = "main"
    remote: str = "origin"

class Config(BaseModel):
    """Main configuration model."""
    learning: LearningConfig = Field(default_factory=LearningConfig)
    monitoring: MonitoringConfig = Field(default_factory=MonitoringConfig)
    storage: StorageConfig = Field(default_factory=StorageConfig)
    git: GitConfig = Field(default_factory=GitConfig)
    
    class Config:
        arbitrary_types_allowed = True


def load_config(config_path: Optional[str] = None) -> Config:
    """Load configuration from file or use defaults."""
    default_config = Config()
    
    if not config_path:
        # Try default locations
        config_paths = [
            Path("config/learn.yaml"),
            Path("/etc/maya/learn.yaml"),
            Path.home() / ".config/maya/learn.yaml"
        ]
        
        for path in config_paths:
            if path.exists():
                config_path = str(path)
                break
        else:
            return default_config
    
    try:
        with open(config_path, 'r') as f:
            config_data = yaml.safe_load(f) or {}
        
        # Convert paths to Path objects
        if 'storage' in config_data:
            storage = config_data.get('storage', {})
            if 'data_dir' in storage:
                storage['data_dir'] = Path(storage['data_dir'])
            if 'model_dir' in storage:
                storage['model_dir'] = Path(storage['model_dir'])
        
        return Config(**config_data)
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(
            f"Failed to load config from {config_path}: {e}. Using defaults."
        )
        return default_config


def save_config(config: Config, path: str) -> None:
    """Save configuration to file."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(path, 'w') as f:
        yaml.dump(config.dict(), f, default_flow_style=False)


def get_default_config() -> Dict[str, Any]:
    """Get default configuration as a dictionary."""
    return Config().dict()
