@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 15:56:36",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/knowledge_graph/tests/prefetch_test.rs",
    "type": "rs",
    "hash": "2e33c6236cbccc1d812042d2d65e25e82fb3904b"
  }
}
@pattern_meta@

use maya_knowledge_graph::storage::{
    Storage, PrefetchConfig, PrefetchExt, SledStore
};
use tempfile::tempdir;

#[test]
fn test_prefetching_iterator() -> anyhow::Result<()> {
    // Create a temporary directory for the test database
    let dir = tempdir()?;
    let store = SledStore::open(dir.path())?;
    
    // Insert test data
    for i in 0..1000 {
        let key = format!("key{:04}", i).into_bytes();
        let value = format!("value{}", i).into_bytes();
        store.put_serialized(&key, &value)?;
    }
    
    // Create a prefetching iterator
    let config = PrefetchConfig {
        prefetch_size: 32,
        max_buffers: 4,
        buffer_size: 64,
        prefetch_timeout_ms: 100,
    };
    
    let prefetch_iter = store.iter_prefix_prefetch(b"key", config)?;
    
    // Convert to a standard iterator for easier testing
    let mut count = 0;
    for result in prefetch_iter {
        let (key, value) = result?;
        let key_str = String::from_utf8_lossy(&key);
        let value_str = String::from_utf8_lossy(&value);
        assert!(key_str.starts_with("key"));
        assert!(value_str.starts_with("value"));
        count += 1;
    }
    
    assert_eq!(count, 1000);
    
    Ok(())
}

#[test]
fn test_prefetching_performance() -> anyhow::Result<()> {
    use std::time::Instant;
    
    // Create a temporary directory for the test database
    let dir = tempdir()?;
    let store = SledStore::open(dir.path())?;
    
    // Insert a large amount of test data
    let start = Instant::now();
    for i in 0..10_000 {
        let key = format!("item_{:08}", i).into_bytes();
        let value = vec![0u8; 1024]; // 1KB per value
        store.put_serialized(&key, &value)?;
    }
    println!("Inserted 10,000 items in {:?}", start.elapsed());
    
    // Test with prefetching
    let start = Instant::now();
    let config = PrefetchConfig {
        prefetch_size: 128,
        max_buffers: 8,
        buffer_size: 256,
        prefetch_timeout_ms: 100,
    };
    
    let prefetch_iter = store.iter_prefix_prefetch(b"item_", config)?;
    let mut count = 0;
    for result in prefetch_iter {
        result?; // Just count, ignore the actual values
        count += 1;
    }
    let prefetch_time = start.elapsed();
    println!("Prefetching iterator processed {} items in {:?}", count, prefetch_time);
    
    // Test without prefetching
    let start = Instant::now();
    let mut count = 0;
    for _ in store.iter_prefix(b"item_") {
        count += 1;
    }
    let normal_time = start.elapsed();
    println!("Normal iterator processed {} items in {:?}", count, normal_time);
    
    // Prefetching should be faster for large scans
    if prefetch_time < normal_time {
        println!("Prefetching was {:.2}x faster", 
            normal_time.as_secs_f64() / prefetch_time.as_secs_f64());
    } else {
        println!("Prefetching was {:.2}x slower", 
            prefetch_time.as_secs_f64() / normal_time.as_secs_f64());
    }
    
    Ok(())
}
