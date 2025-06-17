""
Pattern learning and recognition for MAYA Learning Service.
"""

import asyncio
import json
import logging
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, asdict
from datetime import datetime
import hashlib

from .config import Config
from .monitor import SystemMetrics

@dataclass
class Pattern:
    """A learned pattern."""
    id: str
    pattern_type: str
    data: Dict[str, Any]
    created_at: float
    updated_at: float
    confidence: float = 1.0
    metadata: Dict[str, Any] = None


class PatternLearner:
    """Learn and recognize patterns in system metrics."""
    
    def __init__(self, config: Config):
        """Initialize the pattern learner."""
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.patterns: Dict[str, Pattern] = {}
        self.pattern_file = config.storage.data_dir / "patterns.json"
        self._lock = asyncio.Lock()
        
        # Ensure data directory exists
        self.pattern_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Load existing patterns
        self._load_patterns()
    
    async def process(self, metrics: SystemMetrics) -> None:
        """Process new metrics and learn patterns."""
        if not self.config.learning.enabled:
            return
        
        try:
            # Convert metrics to dict for processing
            metrics_dict = asdict(metrics)
            
            # Simple pattern detection (can be enhanced with ML models)
            await self._detect_cpu_patterns(metrics_dict)
            await self._detect_memory_patterns(metrics_dict)
            await self._detect_network_patterns(metrics_dict)
            
            # Save patterns periodically
            if len(self.patterns) % 10 == 0:
                await self._save_patterns()
                
                # Auto-commit changes if enabled
                if self.config.git.enabled and self.config.git.auto_commit:
                    await self._git_commit_changes()
            
        except Exception as e:
            self.logger.error(f"Error processing metrics: {e}", exc_info=True)
    
    async def _detect_cpu_patterns(self, metrics: Dict[str, Any]) -> None:
        """Detect CPU usage patterns."""
        cpu_usage = metrics['cpu_percent']
        load_avg = metrics['load_avg']
        
        # Simple threshold-based pattern detection
        if cpu_usage > 80.0 and load_avg['1min'] > 4.0:
            pattern_id = self._generate_pattern_id('high_cpu', metrics)
            
            pattern = Pattern(
                id=pattern_id,
                pattern_type='high_cpu',
                data={
                    'cpu_percent': cpu_usage,
                    'load_avg': load_avg,
                    'processes': metrics['processes']
                },
                created_at=metrics['timestamp'],
                updated_at=metrics['timestamp'],
                confidence=min(1.0, (cpu_usage - 70) / 30),  # Normalize confidence
                metadata={
                    'detection_method': 'threshold',
                    'threshold': 80.0
                }
            )
            
            await self._add_pattern(pattern)
    
    async def _detect_memory_patterns(self, metrics: Dict[str, Any]) -> None:
        """Detect memory usage patterns."""
        mem_usage = metrics['memory_percent']
        
        if mem_usage > 85.0:
            pattern_id = self._generate_pattern_id('high_memory', metrics)
            
            pattern = Pattern(
                id=pattern_id,
                pattern_type='high_memory',
                data={
                    'memory_percent': mem_usage,
                    'timestamp': metrics['timestamp']
                },
                created_at=metrics['timestamp'],
                updated_at=metrics['timestamp'],
                confidence=min(1.0, (mem_usage - 75) / 25),  # Normalize confidence
                metadata={
                    'detection_method': 'threshold',
                    'threshold': 85.0
                }
            )
            
            await self._add_pattern(pattern)
    
    async def _detect_network_patterns(self, metrics: Dict[str, Any]) -> None:
        """Detect network usage patterns."""
        for iface, stats in metrics['network_io'].items():
            # Skip loopback and inactive interfaces
            if iface == 'lo' or 'bytes_sent_ps' not in stats:
                continue
            
            # Detect high network traffic
            if stats['bytes_sent_ps'] > 1_000_000 or stats['bytes_recv_ps'] > 1_000_000:  # 1 MB/s
                pattern_id = self._generate_pattern_id('high_network', {**metrics, 'interface': iface})
                
                pattern = Pattern(
                    id=pattern_id,
                    pattern_type='high_network',
                    data={
                        'interface': iface,
                        'bytes_sent_ps': stats['bytes_sent_ps'],
                        'bytes_recv_ps': stats['bytes_recv_ps'],
                        'timestamp': metrics['timestamp']
                    },
                    created_at=metrics['timestamp'],
                    updated_at=metrics['timestamp'],
                    confidence=0.8,  # High confidence for network patterns
                    metadata={
                        'detection_method': 'threshold',
                        'threshold': 1_000_000  # 1 MB/s
                    }
                )
                
                await self._add_pattern(pattern)
    
    async def _add_pattern(self, pattern: Pattern) -> None:
        """Add or update a pattern."""
        async with self._lock:
            existing = self.patterns.get(pattern.id)
            
            if existing:
                # Update existing pattern
                existing.updated_at = pattern.updated_at
                existing.confidence = min(1.0, existing.confidence + 0.1)  # Increase confidence
                existing.data.update(pattern.data)
            else:
                # Add new pattern
                self.patterns[pattern.id] = pattern
                
                # Limit number of patterns
                if len(self.patterns) > self.config.learning.max_patterns:
                    # Remove oldest pattern
                    oldest = min(self.patterns.values(), key=lambda p: p.updated_at)
                    del self.patterns[oldest.id]
    
    def _generate_pattern_id(self, pattern_type: str, data: Dict[str, Any]) -> str:
        """Generate a unique ID for a pattern."""
        # Create a hash of the pattern data for a stable ID
        hash_input = f"{pattern_type}:{json.dumps(data, sort_keys=True)}"
        return f"{pattern_type}_{hashlib.md5(hash_input.encode()).hexdigest()[:8]}"
    
    def _load_patterns(self) -> None:
        """Load patterns from disk."""
        if not self.pattern_file.exists():
            return
            
        try:
            with open(self.pattern_file, 'r') as f:
                data = json.load(f)
                
            for pattern_data in data.get('patterns', []):
                pattern = Pattern(**pattern_data)
                self.patterns[pattern.id] = pattern
                
            self.logger.info(f"Loaded {len(self.patterns)} patterns from {self.pattern_file}")
            
        except Exception as e:
            self.logger.error(f"Error loading patterns: {e}")
    
    async def _save_patterns(self) -> None:
        """Save patterns to disk."""
        async with self._lock:
            try:
                data = {
                    'version': '1.0',
                    'updated_at': datetime.now().timestamp(),
                    'patterns': [asdict(p) for p in self.patterns.values()]
                }
                
                # Write to a temporary file first
                temp_file = self.pattern_file.with_suffix('.tmp')
                with open(temp_file, 'w') as f:
                    json.dump(data, f, indent=2)
                
                # Atomic replace
                temp_file.replace(self.pattern_file)
                
            except Exception as e:
                self.logger.error(f"Error saving patterns: {e}")
    
    async def _git_commit_changes(self) -> None:
        """Commit changes to git repository."""
        try:
            # Check if we're in a git repository
            if not (Path.cwd() / '.git').exists():
                return
                
            # Add all changes
            subprocess.run(
                ['git', 'add', str(self.pattern_file.relative_to(Path.cwd()))],
                check=True,
                capture_output=True,
                text=True
            )
            
            # Check if there are any changes to commit
            status = subprocess.run(
                ['git', 'status', '--porcelain'],
                check=True,
                capture_output=True,
                text=True
            )
            
            if not status.stdout.strip():
                return  # No changes to commit
            
            # Commit changes
            commit_msg = self.config.git.commit_message
            subprocess.run(
                ['git', 'commit', '-m', commit_msg],
                check=True,
                capture_output=True,
                text=True
            )
            
            self.logger.info("Committed pattern changes to git")
            
            # Push changes if we're on a branch with a remote
            if self.config.git.remote:
                subprocess.run(
                    ['git', 'push', self.config.git.remote, self.config.git.branch],
                    check=False,  # Don't fail if push fails
                    capture_output=True,
                    text=True
                )
                
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Git command failed: {e.stderr}")
        except Exception as e:
            self.logger.error(f"Error committing to git: {e}")
    
    async def cleanup(self) -> None:
        """Clean up resources."""
        await self._save_patterns()
        
        # One final git commit
        if self.config.git.enabled and self.config.git.auto_commit:
            await self._git_commit_changes()
