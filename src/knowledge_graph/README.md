# MAYA Knowledge Graph

> High-performance, persistent knowledge graph storage and query engine for the MAYA ecosystem

## Overview

The MAYA Knowledge Graph is a powerful graph database that provides efficient storage, retrieval, and querying capabilities for complex, interconnected data. It's built with performance, reliability, and scalability in mind, making it ideal for AI/ML applications, knowledge representation, and complex data analysis.

## Features

- **High-Performance Storage**: Built on Sled for fast, reliable persistence
- **ACID Transactions**: Ensures data consistency and reliability
- **Flexible Data Model**: Supports nodes, edges, and properties
- **Powerful Querying**: Advanced graph traversal and pattern matching
- **Thread-Safe**: Designed for concurrent access
- **Configurable Caching**: Built-in LRU cache for hot data

## Storage Backend

The knowledge graph uses [Sled](https://github.com/spacejam/sled) as its storage backend, providing:

- **ACID Compliance**: Ensures data integrity
- **High Throughput**: Optimized for both read and write operations
- **Crash Safety**: Built-in checksumming and copy-on-write
- **Compression**: Reduces disk space usage

### Performance Characteristics

| Operation | Performance | Notes |
|-----------|-------------|-------|
| Node Insert | ~50K ops/sec | With default configuration |
| Edge Insert | ~45K ops/sec | With default configuration |
| Node Lookup | ~100K ops/sec | With cache hit |
| Traversal (10 hops) | ~5K ops/sec | Depends on graph density |
| Batch Import | ~1M nodes/min | With batch size of 10K |

*Note: Performance may vary based on hardware and workload characteristics.*

## Getting Started

### Adding to Your Project

Add the following to your `Cargo.toml`:

```toml
[dependencies]
knowledge_graph = { path = "path/to/maya/src/knowledge_graph" }
```

### Basic Usage

```rust
use knowledge_graph::{Graph, Storage, SledStorage};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
struct User {
    id: String,
    name: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize storage
    let storage = SledStorage::open("data/graph")?;
    let graph = Graph::new(storage);

    // Create nodes
    let user1 = User {
        id: "1".to_string(),
        name: "Alice".to_string(),
    };

    let user2 = User {
        id: "2".to_string(),
        name: "Bob".to_string(),
    };

    // Add nodes to graph
    graph.add_node("user", &user1.id, &user1).await?;
    graph.add_node("user", &user2.id, &user2).await?;

    // Add relationship
    graph.add_edge("follows", &user1.id, &user2.id, None).await?;

    // Query relationships
    let followers = graph.get_edges_to(&user2.id, Some("follows")).await?;
    println!("Users following Bob: {:?}", followers);

    Ok(())
}
```

## Advanced Usage

### Batch Operations

```rust
use knowledge_graph::{BatchOperation, Graph, SledStorage};

let storage = SledStorage::open("data/graph")?;
let graph = Graph::new(storage);

let mut batch = graph.batch();

// Queue operations
batch.add_node("user", "1", &user1)?;
batch.add_node("user", "2", &user2)?;
batch.add_edge("follows", "1", "2", None)?;

// Execute batch
batch.commit().await?;
```

### Querying the Graph

```rust
// Find all paths between two nodes
let paths = graph.find_paths("1", "2", Some(3), None).await?;

// Find nodes by property
let users = graph.query_nodes("user", "name = $1", &["Alice"]).await?;

// Traverse graph
let mut traversal = graph.traverse("1")
    .with_max_depth(3)
    .with_edge_filter(|e| e.label() == "follows");

for node in traversal.await? {
    println!("Visited: {:?}", node);
}
```

## Configuration

### Storage Options

```rust
use knowledge_graph::SledStorage;

let storage = SledStorage::builder()
    .path("data/graph")
    .cache_capacity(1_000_000)  // 1M items in cache
    .compression(true)
    .mode("high_throughput")  // or "low_space", "high_safety"
    .open()?;
```

## Performance Tuning

### Caching Strategy

The knowledge graph uses an LRU cache to improve performance. Consider these tuning options:

- **Cache Size**: Adjust based on your working set size
- **Batch Sizes**: Larger batches improve throughput but increase memory usage
- **Compression**: Reduces disk usage at the cost of CPU

### Recommended Settings

For production workloads:

```rust
let storage = SledStorage::builder()
    .path("data/graph")
    .cache_capacity(10_000_000)  // 10M items
    .compression(true)
    .mode("high_throughput")
    .open()?;
```

For development:
```rust
let storage = SledStorage::temp()?;  // Creates a temporary in-memory database
```

## Monitoring

### Built-in Metrics

Monitor the knowledge graph using the built-in metrics:

```rust
let metrics = graph.metrics();
println!("Cache hit rate: {:.2}%", metrics.cache_hit_rate() * 100.0);
println!("Nodes: {}", metrics.node_count());
println!("Edges: {}", metrics.edge_count());
```

### Logging

Enable debug logging for detailed insights:

```toml
# In your Cargo.toml
[dependencies]
log = "0.4"
env_logger = "0.10"
```

```rust
// In your application
env_logger::init();
log::info!("Knowledge Graph initialized");
```

## Advanced Query Examples

### 1. Complex Graph Traversals

```rust
// Find all users who are followed by someone Alice follows (2-hop query)
let mut query = graph.traverse(&alice_id)
    .with_max_depth(2)
    .with_edge_filter(|e| e.label() == "follows");

for node in query.await? {
    if node.depth() == 2 {
        println!("Potential connection: {:?}", node);
    }
}
```

### 2. Property-Based Queries with Joins

```rust
// Find all posts with more than 10 likes from users Alice follows
let liked_posts = graph.query_edges(
    "likes", 
    "timestamp > $1 AND count > $2", 
    &[timestamp_24h_ago.to_string().as_str(), "10"]
).await?;

// Get the users who made these posts
let post_authors: HashSet<String> = liked_posts
    .iter()
    .filter_map(|e| e.source().ok())
    .collect();

// Get details of these users
let authors = graph.get_nodes_by_ids(&post_authors.into_iter().collect::<Vec<_>>()).await?;
```

### 3. Temporal Queries

```rust
use chrono::{DateTime, Utc};

// Find all activities in the last 24 hours
let one_day_ago = Utc::now() - chrono::Duration::hours(24);
let recent_activities = graph.query_edges(
    "activity",
    "timestamp > $1",
    &[&one_day_ago.to_rfc3339()]
).await?;

// Group activities by hour
let mut activity_by_hour = std::collections::HashMap::new();
for activity in recent_activities {
    let timestamp: DateTime<Utc> = DateTime::from_timestamp(activity.timestamp(), 0).unwrap();
    let hour = timestamp.format("%Y-%m-%d %H:00").to_string();
    *activity_by_hour.entry(hour).or_insert(0) += 1;
}
```

### 4. Recommendation Queries

```rust
// Recommend users to follow based on common interests
async fn recommend_users(
    graph: &Graph<SledStorage>,
    user_id: &str,
    limit: usize,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    // Get user's interests
    let user_interests = graph.get_node_edges(user_id, Some("has_interest")).await?;
    let interest_ids: Vec<String> = user_interests
        .iter()
        .filter_map(|e| e.target().ok())
        .collect();

    // Find users with similar interests
    let mut similar_users = std::collections::HashMap::new();
    for interest_id in interest_ids {
        let users = graph.get_edges_to(&interest_id, Some("has_interest")).await?;
        for edge in users {
            let other_user = edge.source()?;
            if other_user != user_id {
                *similar_users.entry(other_user).or_insert(0) += 1;
            }
        }
    }

    // Sort by number of common interests
    let mut recommendations: Vec<_> = similar_users.into_iter().collect();
    recommendations.sort_by(|a, b| b.1.cmp(&a.1));
    
    Ok(recommendations.into_iter()
        .take(limit)
        .map(|(user, _)| user)
        .collect())
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. High Memory Usage

**Symptoms**:
- Slow performance
- System becomes unresponsive
- High memory consumption
- Frequent garbage collection

**Solutions**:
- Reduce cache size:
  ```rust
  let storage = SledStorage::builder()
      .cache_capacity(100_000)  // Reduce from default
      .open("data/graph")?;
  ```
- Increase batch sizes to reduce memory fragmentation
- Enable compression if not already enabled
- Monitor and limit concurrent operations
- Use streaming APIs for large result sets

#### 2. Slow Queries

**Symptoms**:
- Queries take longer than expected
- High CPU usage during queries
- Inconsistent response times
- Timeout errors

**Solutions**:
- Check if queries are using appropriate indexes
- Use `explain` to analyze query plans
- Consider denormalizing frequently accessed data
- Increase cache size if working set fits in memory
- Optimize complex queries by breaking them down
- Use pagination for large result sets
- Monitor and optimize hot paths

#### 3. Database Corruption

**Symptoms**:
- Unexpected errors when reading/writing data
- Inconsistent query results
- Checksum validation failures
- Inability to open the database

**Solutions**:
1. First, create a backup:
   ```bash
   cp -r data/graph data/backup_$(date +%Y%m%d)
   ```
2. Try to repair the database:
   ```rust
   let storage = SledStorage::builder()
       .path("data/graph")
       .repair_on_open(true)
       .open()?;
   ```
3. If that fails, restore from backup
4. Check disk health and filesystem integrity
5. Verify no unexpected shutdowns occurred

#### 4. Connection Issues

**Symptoms**:
- "Database not found" errors
- Permission denied errors
- Connection timeouts
- Too many open files

**Solutions**:
- Verify the database path exists and is writable
- Check for file system permissions
- Ensure no other process has locked the database
- On Linux, check `lsof | grep data/graph` for locking processes
- Increase system limits (ulimit -n)
- Check for network issues if using remote storage
- Verify sufficient disk space and inodes

#### 5. Performance Degradation Over Time

**Symptoms**:
- Database becomes slower as more data is added
- Increased disk I/O
- Growing database size
- Longer compaction times

**Solutions**:
- Run periodic maintenance:
  ```rust
  let storage = SledStorage::open("data/graph")?;
  storage.compact()?;  // Run during low-traffic periods
  ```
- Consider archiving old data
- Review and optimize your indexing strategy
- Monitor and adjust compression settings
- Consider sharding for very large datasets
- Schedule regular database optimization

#### 6. Transaction Conflicts

**Symptoms**:
- Transaction aborted errors
- Concurrent modification conflicts
- Deadlocks
- Inconsistent read results

**Solutions**:
- Implement proper transaction retry logic
- Reduce transaction duration
- Use appropriate isolation levels
- Implement optimistic concurrency control
- Consider batching operations
- Monitor and resolve deadlocks

#### 7. Query Timeouts

**Symptoms**:
- Queries fail with timeout errors
- Incomplete results
- Client disconnections

**Solutions**:
- Optimize slow queries
- Increase timeout settings:
  ```rust
  let storage = SledStorage::builder()
      .timeout(Duration::from_secs(30))  // Increase timeout
      .open("data/graph")?;
  ```
- Use pagination for large result sets
- Monitor and optimize query performance
- Consider read replicas for heavy read loads

#### 8. Disk Space Issues

**Symptoms**:
- Out of disk space errors
- Failed writes
- Database corruption

**Solutions**:
- Monitor disk space usage
- Implement automatic cleanup of old data
- Compress historical data
- Consider using a larger disk
- Set up disk space alerts
- Enable compression if not already enabled

### Debugging Tips

1. **Enable Detailed Logging**:
   ```bash
   # Set log level for different components
   RUST_LOG=debug,sled=info,graph=debug cargo run
   
   # Log to file with rotation
   RUST_LOG=debug cargo run 2>&1 | tee -a app.log
   ```

2. **Monitor Database Metrics**:
   ```rust
   let metrics = graph.metrics();
   println!("Cache hit rate: {:.2}%", metrics.cache_hit_rate() * 100.0);
   println!("IO operations: {:?}", metrics.io_stats());
   println!("Active transactions: {}", metrics.active_transactions());
   println!("Disk usage: {:.2}MB", metrics.disk_usage_mb());
   ```

3. **Check System Resources**:
   ```bash
   # Check disk space and inodes
   df -h
   df -i
   
   # Check memory usage
   free -h
   top -o %MEM
   
   # Check I/O stats
   iostat -x 1
   ```

4. **Profile Queries**:
   ```rust
   // Enable query profiling
   let start = std::time::Instant::now();
   let result = graph.query_nodes("user", "name = $1", &["Alice"]).await?;
   let duration = start.elapsed();
   println!("Query took: {:?}", duration);
   
   // Get query plan
   let plan = graph.explain_query("user", "name = $1", &["Alice"]).await?;
   println!("Query plan: {:#?}", plan);
   ```

5. **Inspect Database State**:
   ```bash
   # List database files
   ls -lh data/graph/
   
   # Check file descriptors
   lsof -p $(pgrep your_app_name)
   
   # Monitor disk I/O
   iotop -o
   ```

## Graph Algorithms and Analytics

### 1. Shortest Path

```rust
use petgraph::algo::dijkstra;
use petgraph::prelude::*;

async fn find_shortest_path(
    graph: &Graph<SledStorage>,
    start: &str,
    end: &str,
) -> Result<Option<Vec<String>>, Box<dyn std::error::Error>> {
    // Build a temporary graph for analysis
    let mut petgraph = PetGraph::<String, f64>::new();
    let mut node_map = std::collections::HashMap::new();
    
    // Add all nodes
    let nodes = graph.get_nodes(None, None).await?;
    for node in nodes {
        let idx = petgraph.add_node(node.id.clone());
        node_map.insert(node.id, idx);
    }
    
    // Add all edges with weights
    let edges = graph.get_edges(None, None, None).await?;
    for edge in edges {
        if let (Some(&source), Some(&target)) = (
            node_map.get(&edge.source),
            node_map.get(&edge.target),
        ) {
            // Use 1.0 as default weight, or use edge property if available
            let weight = edge.properties.get("weight")
                .and_then(|v| v.as_f64())
                .unwrap_or(1.0);
            petgraph.add_edge(source, target, weight);
        }
    }
    
    // Find shortest path using Dijkstra's algorithm
    if let (Some(&start_idx), Some(&end_idx)) = (node_map.get(start), node_map.get(end)) {
        let result = dijkstra(&petgraph, start_idx, Some(end_idx), |e| *e.weight());
        if let Some(path) = result.get(&end_idx) {
            // Reconstruct path
            let mut current = end_idx;
            let mut path_nodes = vec![current];
            while current != start_idx {
                if let Some((prev, _)) = petgraph.edges_directed(*current, Direction::Incoming)
                    .map(|e| (e.source(), e.weight()))
                    .min_by(|a, b| a.1.partial_cmp(b.1).unwrap_or(std::cmp::Ordering::Equal))
                {
                    path_nodes.push(prev);
                    current = &prev;
                } else {
                    break;
                }
            }
            path_nodes.reverse();
            
            // Convert back to node IDs
            let mut id_map: HashMap<_, _> = node_map.into_iter().map(|(k, v)| (v, k)).collect();
            return Ok(Some(path_nodes.into_iter().filter_map(|n| id_map.remove(&n)).collect()));
        }
    }
    
    Ok(None)
}
```

### 2. PageRank

```rust
use petgraph::algo::page_rank;

async fn calculate_pagerank(
    graph: &Graph<SledStorage>,
    damping: f64,
    iterations: usize,
) -> Result<HashMap<String, f64>, Box<dyn std::error::Error>> {
    let mut petgraph = PetGraph::<String, ()>::new();
    let mut node_map = std::collections::HashMap::new();
    
    // Add all nodes
    let nodes = graph.get_nodes(None, None).await?;
    for node in nodes {
        let idx = petgraph.add_node(node.id.clone());
        node_map.insert(node.id, idx);
    }
    
    // Add all edges
    let edges = graph.get_edges(None, None, None).await?;
    for edge in edges {
        if let (Some(&source), Some(&target)) = (
            node_map.get(&edge.source),
            node_map.get(&edge.target),
        ) {
            petgraph.add_edge(source, target, ());
        }
    }
    
    // Calculate PageRank
    let ranks = page_rank(&petgraph, damping, iterations);
    
    // Map back to node IDs
    let mut id_map: HashMap<_, _> = node_map.into_iter().map(|(k, v)| (v, k)).collect();
    let mut result = HashMap::new();
    for (idx, rank) in ranks.into_iter() {
        if let Some(id) = id_map.remove(&idx) {
            result.insert(id, rank);
        }
    }
    
    Ok(result)
}
```

### 3. Community Detection (Louvain Method)

```rust
use rustworkx_core::community::louvain;

async fn detect_communities(
    graph: &Graph<SledStorage>,
    resolution: f64,
) -> Result<HashMap<String, usize>, Box<dyn std::error::Error>> {
    let mut petgraph = petgraph::Graph::<String, f64>::new_undirected();
    let mut node_map = std::collections::HashMap::new();
    
    // Add all nodes
    let nodes = graph.get_nodes(None, None).await?;
    for node in nodes {
        let idx = petgraph.add_node(node.id.clone());
        node_map.insert(node.id, idx);
    }
    
    // Add all edges with weights
    let edges = graph.get_edges(None, None, None).await?;
    for edge in edges {
        if let (Some(&source), Some(&target)) = (
            node_map.get(&edge.source),
            node_map.get(&edge.target),
        ) {
            let weight = edge.properties.get("weight")
                .and_then(|v| v.as_f64())
                .unwrap_or(1.0);
            petgraph.add_edge(source, target, weight);
        }
    }
    
    // Convert to rustworkx graph
    let mut rustworkx_graph = rustworkx::PetGraph::new_undirected();
    let node_indices: Vec<_> = petgraph.node_indices()
        .map(|i| rustworkx_graph.add_node(i))
        .collect();
        
    for edge in petgraph.raw_edges() {
        let source = node_indices[edge.source().index()];
        let target = node_indices[edge.target().index()];
        rustworkx_graph.add_edge(source, target, edge.weight);
    }
    
    // Run Louvain algorithm
    let communities = louvain(&rustworkx_graph, Some(resolution), None, None, None)
        .map_err(|e| format!("Community detection failed: {:?}", e))?;
    
    // Map back to node IDs
    let mut result = HashMap::new();
    for (node_idx, community) in communities.into_iter().enumerate() {
        if let Some(original_idx) = rustworkx_graph.node_weight(node_idx.into()) {
            if let Some(node_id) = petgraph.node_weight(original_idx) {
                result.insert(node_id.clone(), community);
            }
        }
    }
    
    Ok(result)
}
```

## Comprehensive Monitoring

### Key Metrics to Monitor

#### 1. Storage Metrics

| Metric | Description | Healthy Range | Alert Threshold |
|--------|-------------|---------------|-----------------|
| `disk_usage_bytes` | Total disk space used | < 80% capacity | > 90% capacity |
| `data_size_bytes` | Logical data size | N/A | N/A |
| `live_data_ratio` | Live data to total data ratio | > 0.7 | < 0.5 |
| `compaction_ratio` | Write amplification | < 10 | > 20 |

#### 2. Performance Metrics

| Metric | Description | Healthy Range | Alert Threshold |
|--------|-------------|---------------|-----------------|
| `read_latency_ms` | 99th percentile read latency | < 50ms | > 100ms |
| `write_latency_ms` | 99th percentile write latency | < 100ms | > 200ms |
| `ops_per_sec` | Operations per second | N/A | N/A |
| `cache_hit_rate` | Cache hit ratio | > 0.9 | < 0.8 |
| `active_transactions` | Number of active transactions | < 100 | > 1000 |

#### 3. Graph-Specific Metrics

| Metric | Description | Healthy Range | Alert Threshold |
|--------|-------------|---------------|-----------------|
| `node_count` | Total nodes | N/A | N/A |
| `edge_count` | Total edges | N/A | N/A |
| `avg_degree` | Average node degree | N/A | N/A |
| `diameter` | Longest shortest path | N/A | N/A |
| `density` | Edge density (0-1) | N/A | N/A |

### Monitoring Setup Example

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'maya_graph'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/metrics'

# Alert Rules
alert: HighDiskUsage
  expr: disk_usage_bytes / disk_capacity_bytes > 0.9
  for: 15m
  labels:
    severity: critical
  annotations:
    summary: "High disk usage on {{ $labels.instance }}"
    description: "Disk usage is {{ $value }}%"

alert: HighWriteLatency
  expr: rate(write_latency_seconds_sum[5m]) / rate(write_latency_seconds_count[5m]) > 0.2
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "High write latency on {{ $labels.instance }}"
    description: "Write latency is {{ $value }}s (p99)"
```

## Backup and Recovery Procedures

### 1. Backup Strategies

#### Hot Backups

```rust
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

async fn create_hot_backup(
    graph: &Graph<SledStorage>,
    backup_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)?
        .as_secs();
    
    let backup_path = backup_dir.join(format!("backup_{}", timestamp));
    
    // Create backup
    graph.backup(&backup_path).await?;
    
    // Optionally compress the backup
    let status = std::process::Command::new("tar")
        .args(["-czf", &format!("{}.tar.gz", backup_path.display()), 
               &backup_path.display()])
        .status()?;
    
    if !status.success() {
        return Err("Failed to compress backup".into());
    }
    
    // Remove uncompressed backup
    std::fs::remove_dir_all(&backup_path)?;
    
    // Clean up old backups (keep last 7 days)
    let _ = std::process::Command::new("find")
        .args([backup_dir, Path::new("-type"), Path::new("f"), 
               Path::new("-name"), Path::new("backup_*.tar.gz"),
               Path::new("-mtime"), Path::new("+7"), 
               Path::new("-delete")])
        .status();
    
    Ok(())
}
```

#### Incremental Backups

```rust
use std::collections::HashMap;

struct BackupManager {
    last_backup: HashMap<String, u64>,
    backup_dir: PathBuf,
}

impl BackupManager {
    async fn create_incremental_backup(
        &mut self,
        graph: &Graph<SledStorage>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let changes = graph.get_changes_since_last_backup().await?;
        
        if changes.is_empty() {
            return Ok(());
        }
        
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)?
            .as_secs();
        
        let backup_path = self.backup_dir.join(format!("incremental_{}", timestamp));
        std::fs::create_dir_all(&backup_path)?;
        
        // Save changes to backup
        graph.backup_incremental(&backup_path, &changes).await?;
        
        // Update last backup timestamp
        self.last_backup = graph.get_latest_timestamps().await?;
        
        Ok(())
    }
}
```

### 2. Recovery Procedures

#### Full Recovery

```rust
async fn restore_from_backup(
    backup_path: &Path,
    target_path: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    // Stop any running instances
    stop_graph_service()?;
    
    // Remove existing data
    if target_path.exists() {
        std::fs::remove_dir_all(target_path)?;
    }
    
    // Restore from backup
    Graph::restore(backup_path, target_path).await?;
    
    // Restart service
    start_graph_service()?;
    
    // Verify recovery
    let storage = SledStorage::open(target_path)?;
    let graph = Graph::new(storage);
    graph.verify_integrity().await?;
    
    Ok(())
}
```

#### Point-in-Time Recovery

```rust
async fn point_in_time_recovery(
    base_backup: &Path,
    incremental_backups: &[PathBuf],
    target_path: &Path,
    recovery_time: SystemTime,
) -> Result<(), Box<dyn std::error::Error>> {
    // Restore base backup
    restore_from_backup(base_backup, target_path).await?;
    
    // Apply incremental backups in order
    for backup in incremental_backups {
        let backup_time = get_backup_timestamp(backup)?;
        if backup_time <= recovery_time {
            apply_incremental_backup(backup, target_path).await?;
        }
    }
    
    Ok(())
}
```

### 3. Disaster Recovery Plan

1. **Recovery Time Objective (RTO)**: 1 hour
2. **Recovery Point Objective (RPO)**: 5 minutes
3. **Steps**:
   - Identify failure type (node, cluster, data center)
   - For data corruption:
     1. Restore from most recent backup
     2. Apply any available WAL (Write-Ahead Log) files
     3. Verify data integrity
   - For hardware failure:
     1. Provision new hardware
     2. Restore from backup
     3. Rejoin cluster if applicable

### 4. Backup Verification

```rust
async fn verify_backup(backup_path: &Path) -> Result<(), Box<dyn std::error::Error>> {
    // Create temporary directory
    let temp_dir = tempfile::tempdir()?;
    
    // Restore to temporary location
    Graph::restore(backup_path, temp_dir.path()).await?;
    
    // Open the restored database
    let storage = SledStorage::open(temp_dir.path())?;
    let graph = Graph::new(storage);
    
    // Run integrity checks
    graph.verify_integrity().await?;
    
    // Sample data verification
    let node_count = graph.count_nodes().await?;
    let edge_count = graph.count_edges().await?;
    
    if node_count == 0 && edge_count > 0 {
        return Err("Backup verification failed: Edges without nodes".into());
    }
    
    // Clean up
    temp_dir.close()?;
    
    Ok(())
}
```

### 5. Automated Backup Script

```bash
#!/bin/bash

# Configuration
BACKUP_DIR="/var/backups/maya"
DATA_DIR="/var/lib/maya/data"
RETENTION_DAYS=7

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"

# Create backup
maya-cli backup create --path "$BACKUP_PATH" --data-dir "$DATA_DIR"

# Compress backup
tar -czf "$BACKUP_PATH.tar.gz" -C "$BACKUP_PATH" .
rm -rf "$BACKUP_PATH"

# Clean up old backups
find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete

# Verify backup
if maya-cli backup verify "$BACKUP_PATH.tar.gz"; then
    echo "Backup successful: $BACKUP_PATH.tar.gz"
    exit 0
else
    echo "Backup verification failed" >&2
    # Alert monitoring system
    curl -X POST -H 'Content-type: application/json' \
         --data '{"text":"Backup verification failed: $BACKUP_PATH"}' \
         $SLACK_WEBHOOK_URL
    exit 1
fi
```

### 6. Monitoring Backup Health

```yaml
# Prometheus alert rules
alert: BackupFailed
  expr: increase(backup_failed_total[1h]) > 0
  for: 1h
  labels:
    severity: critical
  annotations:
    summary: "Backup failed on {{ $labels.instance }}"
    description: "{{ $value }} backup failures in the last hour"

alert: BackupTooOld
  expr: time() - backup_last_success_timestamp_seconds > 86400  # 24 hours
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "No recent backup on {{ $labels.instance }}"
    description: "Last successful backup was {{ $value }} seconds ago"
```

## Testing

Run the test suite:

```bash
cargo test --all-features
```

### Running Specific Tests

```bash
# Run a specific test
cargo test test_complex_queries -- --nocapture

# Run tests with detailed output
cargo test -- --nocapture --test-threads=1
```

## License

This project is part of the MAYA ecosystem and is proprietary software.

## Contributing

For contribution guidelines, please see the main MAYA repository.
