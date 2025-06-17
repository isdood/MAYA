//! Tests for the storage module

use super::test_utils::*;
use maya_knowledge_graph::{
    prelude::*,
    storage::RocksDBStore,
};
use serde_json::json;
use tempfile::tempdir;

#[test]
fn test_put_and_get() -> Result<()> {
    let dir = tempdir()?;
    let store = RocksDBStore::open(dir.path())?;
    
    // Test basic put and get
    let key = b"test_key";
    let value = json!({ "name": "test", "value": 42 });
    
    store.put(key, &value)?;
    let retrieved: serde_json::Value = store.get(key)?.expect("Value not found");
    
    assert_eq!(retrieved, value);
    Ok(())
}

#[test]
fn test_delete() -> Result<()> {
    let dir = tempdir()?;
    let store = RocksDBStore::open(dir.path())?;
    
    // Add a value
    let key = b"test_key";
    store.put(key, &json!("test_value"))?;
    
    // Verify it exists
    assert!(store.exists(key)?);
    
    // Delete it
    store.delete(key)?;
    
    // Verify it's gone
    assert!(!store.exists(key)?);
    assert!(store.get::<String>(key)?.is_none());
    
    Ok(())
}

#[test]
fn test_iter_prefix() -> Result<()> {
    let dir = tempdir()?;
    let store = RocksDBStore::open(dir.path())?;
    
    // Add some test data
    let data = [
        (b"prefix:1", "value1"),
        (b"prefix:2", "value2"),
        (b"other:1", "value3"),
    ];
    
    for (key, value) in &data {
        store.put(key, value)?;
    }
    
    // Test prefix iteration
    let prefix = b"prefix:";
    let mut results: Vec<_> = store.iter_prefix(prefix)
        .map(|(k, v)| (k, String::from_utf8_lossy(&v).into_owned()))
        .collect();
    
    // Sort for consistent ordering
    results.sort_by_key(|(k, _)| k.clone());
    
    // Verify results
    assert_eq!(results.len(), 2);
    assert_eq!(results[0], (b"prefix:1".to_vec(), "\"value1\"".to_string()));
    assert_eq!(results[1], (b"prefix:2".to_vec(), "\"value2\"".to_string()));
    
    Ok(())
}

#[test]
fn test_transaction() -> Result<()> {
    let dir = tempdir()?;
    let store = RocksDBStore::open(dir.path())?;
    
    // Create a batch of operations
    let mut batch = store.batch();
    
    // Add some operations
    batch.put(b"key1", &"value1")?;
    batch.put(b"key2", &"value2")?;
    batch.delete(b"key1")?;
    
    // Commit the batch
    batch.commit()?;
    
    // Verify the results
    assert!(store.get::<String>(b"key1")?.is_none());
    assert_eq!(store.get::<String>(b"key2")?, Some("\"value2\"".to_string()));
    
    Ok(())
}
