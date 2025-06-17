//! Tests for the storage module

use maya_knowledge_graph::{
    storage::{SledStore, Storage, WriteBatchExt},
    error::Result,
};
use serde_json::json;
use tempfile::tempdir;
use std::path::Path;

#[test]
fn test_put_and_get() -> Result<()> {
    let dir = tempfile::tempdir()?;
    let store = SledStore::open(dir.path())?;

    // Test basic put and get
    let value1 = serde_json::to_vec(&"value1")?;
    store.put_serialized(b"key1", &value1)?;
    
    let stored: Option<String> = store.get(b"key1")?;
    assert_eq!(stored, Some("value1".to_string()));

    // Test overwrite
    let new_value = serde_json::to_vec(&"new_value")?;
    store.put_serialized(b"key1", &new_value)?;
    
    let stored: Option<String> = store.get(b"key1")?;
    assert_eq!(stored, Some("new_value".to_string()));

    // Test non-existent key
    let missing: Option<String> = store.get(b"nonexistent")?;
    assert_eq!(missing, None);

    Ok(())
}

#[test]
fn test_delete() -> Result<()> {
    let dir = tempdir()?;
    let store = SledStore::open(dir.path())?;
    
    // Add a value
    let key = b"test_key";
    let value = serde_json::to_vec(&"test_value")?;
    
    store.put_serialized(key, &value)?;
    assert!(store.exists(key)?);
    
    // Delete the value
    store.delete(key)?;
    assert!(!store.exists(key)?);
    
    // Deleting non-existent key should not error
    store.delete(key)?;
    
    Ok(())
}

#[test]
fn test_iter_prefix() -> Result<()> {
    let dir = tempdir()?;
    let store = SledStore::open(dir.path())?;
    
    // Add values with different prefixes
    store.put_serialized(b"prefix:1", &serde_json::to_vec(&"value1")?)?;
    store.put_serialized(b"prefix:2", &serde_json::to_vec(&"value2")?)?;
    store.put_serialized(b"other:1", &serde_json::to_vec(&"value3")?)?;
    
    // Test prefix iteration
    let mut prefixed = Vec::new();
    for result in store.iter_prefix(b"prefix:") {
        let (key, value) = result?;
        let key = String::from_utf8(key.to_vec()).unwrap();
        let value: String = serde_json::from_slice(&value)?;
        prefixed.push((key, value));
    }
    
    prefixed.sort();
    assert_eq!(prefixed, vec![
        ("prefix:1".to_string(), "value1".to_string()),
        ("prefix:2".to_string(), "value2".to_string())
    ]);
    
    Ok(())
}

#[test]
fn test_transaction() -> Result<()> {
    let dir = tempdir()?;
    let store = SledStore::open(dir.path())?;
    
    // Create a batch of operations
    let mut batch = store.batch();
    
    // Add some operations
    batch.put_serialized(b"key1", &serde_json::to_vec(&"value1")?)?;
    batch.put_serialized(b"key2", &serde_json::to_vec(&"value2")?)?;
    batch.delete(b"key1")?;
    
    // Commit the batch
    Box::new(batch).commit()?;
    
    // Verify the results
    let val1: Option<String> = store.get(b"key1")?;
    let val2: Option<String> = store.get(b"key2")?;
    
    assert!(val1.is_none());
    assert_eq!(val2, Some("value2".to_string()));
    
    Ok(())
}
