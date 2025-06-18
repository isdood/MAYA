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

## Testing

Run the test suite:

```bash
cargo test --all-features
```

## License

This project is part of the MAYA ecosystem and is proprietary software.

## Contributing

For contribution guidelines, please see the main MAYA repository.
