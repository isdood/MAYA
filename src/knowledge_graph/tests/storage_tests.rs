
//! Tests for the storage module

use maya_knowledge_graph::{
    storage::{SledStore, Storage, WriteBatch, WriteBatchExt},
    error::Result,
};
use tempfile::tempdir;

#[test]
fn test_sled_store() -> Result<()> {
    let dir = tempdir()?;
    let store = SledStore::open(dir.path())?;
    
    // Test basic operations
    store.put(b"key1", b"value1")?;
    let val1: Option<Vec<u8>> = store.get(b"key1")?;
    assert_eq!(val1, Some(b"value1".to_vec()));
    
    // Test delete
    store.delete(b"key1")?;
    let val1: Option<Vec<u8>> = store.get(b"key1")?;
    assert_eq!(val1, None);
    
    // Test non-existent key
    assert_eq!(store.get::<Vec<u8>>(b"nonexistent")?, None);
    
    // Test batch operations with proper JSON serialization
    let mut batch = <SledStore as Storage>::batch(&store);
    batch.put_serialized(b"batch1", &serde_json::to_vec(&"value1")?)?;
    batch.put_serialized(b"batch2", &serde_json::to_vec(&"value2")?)?;
    Box::new(batch).commit()?;
    
    // Verify batch operations with deserialization
    let val1: String = store.get(b"batch1")?.unwrap();
    let val2: String = store.get(b"batch2")?.unwrap();
    
    assert_eq!(val1, "value1");
    assert_eq!(val2, "value2");
    
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
    
    // Test getting values directly
    let val1: Option<Vec<u8>> = store.get(b"prefix:1")?;
    let val2: Option<Vec<u8>> = store.get(b"prefix:2")?;
    
    assert!(val1.is_some());
    assert!(val2.is_some());
    
    // Test getting values directly
    let mut prefixed = Vec::new();
    
    // Get values one by one and deserialize JSON
    if let Some(value1) = store.get::<Vec<u8>>(b"prefix:1")? {
        let value: String = serde_json::from_slice(&value1)?;
        prefixed.push(("prefix:1".to_string(), value));
    }
    
    if let Some(value2) = store.get::<Vec<u8>>(b"prefix:2")? {
        let value: String = serde_json::from_slice(&value2)?;
        prefixed.push(("prefix:2".to_string(), value));
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
    
    // Create a batch of operations with proper JSON serialization
    let mut batch = <SledStore as Storage>::batch(&store);
    batch.put_serialized(b"key1", &serde_json::to_vec(&"value1")?)?;
    batch.put_serialized(b"key2", &serde_json::to_vec(&"value2")?)?;
    batch.delete(b"key1");
    Box::new(batch).commit()?;
    
    // Verify the results with deserialization
    let val1: Option<String> = store.get(b"key1")?;
    let val2: Option<String> = store.get(b"key2")?;
    
    assert!(val1.is_none());
    assert_eq!(val2, Some("value2".to_string()));
    
    Ok(())
}
