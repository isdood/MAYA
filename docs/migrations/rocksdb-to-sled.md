@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 05:44:02",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./docs/migrations/rocksdb-to-sled.md",
    "type": "md",
    "hash": "e3a9a733be85de033d5e37b82338987eaff7d0a4"
  }
}
@pattern_meta@

# Migration Guide: RocksDB to Sled

This guide provides instructions for migrating from RocksDB to Sled as the storage backend for MAYA's knowledge graph.

## Overview

- **Previous Version**: RocksDB
- **New Version**: Sled 0.34.7+
- **Migration Type**: One-way migration (automatic)
- **Estimated Downtime**: Minimal (during service restart)

## Breaking Changes

1. **Storage Format**
   - Sled uses a different on-disk format than RocksDB
   - The migration is one-way (no rollback to RocksDB after migration)

2. **Configuration Changes**
   - Update your configuration to use Sled-specific settings
   - Remove any RocksDB-specific configuration

## Migration Steps

### 1. Backup Your Data

Before proceeding, ensure you have a complete backup of your RocksDB data:

```bash
# Create a backup directory
mkdir -p ~/maya_backup_$(date +%Y%m%d)

# Copy RocksDB data
cp -r /var/lib/maya/knowledge_graph ~/maya_backup_$(date +%Y%m%d)/
```

### 2. Update Dependencies

Update your `Cargo.toml` to include the Sled dependency:

```toml
[dependencies]
sled = { version = "0.34.7", features = ["compression"] }
```

### 3. Configuration Updates

Update your configuration file (`config/storage.toml`):

```toml
[storage]
engine = "sled"
path = "/var/lib/maya/knowledge_graph"

[storage.sled]
cache_capacity = 1073741824  # 1GB cache
compression = true
use_compression = ["lz4"]
```

### 4. Run Migration

Start the MAYA service. The first time it runs with the new version, it will automatically:

1. Detect the RocksDB database
2. Migrate all data to Sled format
3. Create a backup of the original RocksDB data
4. Start using the new Sled storage

### 5. Verify Migration

Check the service logs for any migration-related messages:

```bash
journalctl -u maya-learn --since "5 minutes ago" | grep -i migration
```

Verify that all your data is accessible through the API or CLI.

## Performance Tuning

After migration, you may want to tune Sled for your workload:

```toml
[storage.sled]
# Adjust cache size based on available RAM
cache_capacity = 2147483648  # 2GB

# Enable compression for better disk usage
compression = true

# Compression algorithms to use (in order of preference)
use_compression = ["lz4", "zstd"]

# Tune flush interval (in milliseconds)
flush_every_ms = 1000
```

## Troubleshooting

### Migration Fails

If the automatic migration fails:

1. Check the logs for specific error messages
2. Restore from backup
3. Contact support with the error details

### Performance Issues

If you experience performance issues after migration:

1. Increase the cache size
2. Adjust compression settings
3. Check disk I/O performance

## Rollback

If you need to rollback:

1. Stop the MAYA service
2. Restore your RocksDB backup
3. Revert to the previous version of MAYA

> **Note**: After running with Sled, you cannot rollback to a version earlier than the migration.

## Support

For assistance with the migration, please contact support@starlightlabs.io with the subject "Sled Migration Support".

## License

© 2025 Starlight Labs. All rights reserved.
