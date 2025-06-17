//! Sled storage implementation for the knowledge graph

use std::path::Path;
use std::sync::Arc;

use sled::{Db, IVec};
use serde::{Serialize, de::DeserializeOwned};
use log::info;

use crate::error::Result;
use super::{Storage, WriteBatch, WriteBatchExt, serialize, deserialize};

/// Sled storage implementation
pub struct SledStore {
    db: Arc<Db>,
}

impl Storage for SledStore {
    type Batch = SledWriteBatch;
    
    fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let db = sled::open(path)?;
        info!("Opened Sled database");
        Ok(Self {
            db: Arc::new(db),
        })
    }
    
    fn get<T: DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>> {
        match self.db.get(key)? {
            Some(bytes) => {
                let value = deserialize(&bytes)?;
                Ok(Some(value))
            }
            None => Ok(None),
        }
    }
    
    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = serialize(value)?;
        self.db.insert(key, bytes)?;
        self.db.flush()?;
        Ok(())
    }
    
    fn delete(&self, key: &[u8]) -> Result<()> {
        self.db.remove(key)?;
        self.db.flush()?;
        Ok(())
    }
    
    fn exists(&self, key: &[u8]) -> Result<bool> {
        Ok(self.db.contains_key(key)?)
    }
    
    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        let iter = self.db.range(prefix..);
        let prefix_vec = prefix.to_vec();
        
        let filtered = iter.filter_map(move |item| {
            match item {
                Ok((key, value)) if key.starts_with(&prefix_vec) => {
                    Some((key.to_vec(), value.to_vec()))
                }
                _ => None,
            }
        });
        
        Box::new(filtered)
    }
    
    fn batch(&self) -> Self::Batch {
        SledWriteBatch::new(Arc::clone(&self.db))
    }
}

impl WriteBatchExt for SledStore {
    type Batch = SledWriteBatch;
    
    fn batch(&self) -> Self::Batch {
        Storage::batch(self)
    }
}

impl SledStore {
    /// Open or create a new Sled database at the given path
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let db = sled::open(path)?;
        info!("Opened Sled database");
        Ok(Self {
            db: Arc::new(db),
        })
    }
    
    /// Get a reference to the underlying Sled database
    pub fn inner(&self) -> &Db {
        &self.db
    }
}

impl Storage for SledStore {
    fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        SledStore::open(path)
    }

    fn get<T: DeserializeOwned>(&self, key: &[u8]) -> Result<Option<T>> {
        match self.db.get(key)? {
            Some(bytes) => {
                let value = deserialize(&bytes)?;
                Ok(Some(value))
            }
            None => Ok(None),
        }
    }

    fn put<T: Serialize>(&self, key: &[u8], value: &T) -> Result<()> {
        let bytes = serialize(value)?;
        self.db.insert(key, bytes)?;
        self.db.flush()?;
        Ok(())
    }

    fn delete(&self, key: &[u8]) -> Result<()> {
        self.db.remove(key)?;
        self.db.flush()?;
        Ok(())
    }

    fn exists(&self, key: &[u8]) -> Result<bool> {
        Ok(self.db.contains_key(key)?)
    }

    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        let iter = self.db.range(prefix..);
        let prefix_vec = prefix.to_vec();
        
        let filtered = iter.filter_map(move |item| {
            match item {
                Ok((key, value)) if key.starts_with(&prefix_vec) => {
                    Some((key.to_vec(), value.to_vec()))
                }
                _ => None,
            }
        });
        
        Box::new(filtered)
    }

    fn batch(&self) -> Box<dyn WriteBatch> {
        Box::new(SledWriteBatch::new(Arc::clone(&self.db)))
    }
}

/// Sled write batch wrapper
pub struct SledWriteBatch {
    ops: Vec<BatchOp>,
    db: Arc<Db>,
}

enum BatchOp {
    Put(Vec<u8>, Vec<u8>),
    Delete(Vec<u8>),
}

impl WriteBatch for SledWriteBatch {
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.ops.push(BatchOp::Put(key.to_vec(), value.to_vec()));
        Ok(())
    }
    
    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.ops.push(BatchOp::Delete(key.to_vec()));
        Ok(())
    }
    
    fn commit(self: Box<Self>) -> Result<()> {
        use sled::transaction::TransactionError;
        
        let ops = self.ops;
        let db = self.db.clone();
        
        let result: std::result::Result<(), TransactionError<Box<dyn std::error::Error + Send + Sync>>> = db.transaction(|tx| {
            for op in ops {
                match op {
                    BatchOp::Put(key, value) => {
                        tx.insert(key, value)?;
                    }
                    BatchOp::Delete(key) => {
                        tx.remove(key)?;
                    }
                }
            }
            Ok::<(), TransactionError<Box<dyn std::error::Error + Send + Sync>>>(())
        });
        
        result.map_err(|e| crate::error::KnowledgeGraphError::TransactionError(format!("{:?}", e)))?;
        
        db.flush()?;
        Ok(())
    }
}

impl SledWriteBatch {
    /// Create a new write batch
    pub fn new(db: Arc<Db>) -> Self {
        Self {
            ops: Vec::new(),
            db,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;
    use serde_json::json;

    #[test]
    fn test_put_and_get() -> Result<()> {
        let dir = tempdir()?;
        let store = SledStore::open(dir.path())?;
        
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
        let store = SledStore::open(dir.path())?;
        
        // Add a value
        let key = b"test_key";
        store.put(key, &"test_value")?;
        
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
        let store = SledStore::open(dir.path())?;
        
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
        let store = SledStore::open(dir.path())?;

        // Test successful transaction
        let mut batch = store.batch();
        batch.put_serialized(b"key1", &[1, 2, 3])?;
        batch.put_serialized(b"key2", &[4, 5, 6])?;
        batch.commit()?;

        assert_eq!(store.get::<Vec<u8>>(b"key1")?, Some(vec![1, 2, 3]));
        assert_eq!(store.get::<Vec<u8>>(b"key2")?, Some(vec![4, 5, 6]));

        // Test delete in transaction
        let mut batch = store.batch();
        batch.delete(b"key1")?;
        batch.put_serialized(b"key3", &[7, 8, 9])?;
        batch.commit()?;

        assert_eq!(store.get::<Vec<u8>>(b"key1")?, None);
        assert_eq!(store.get::<Vec<u8>>(b"key3")?, Some(vec![7, 8, 9]));

        // Test rollback on panic
        let result = std::panic::catch_unwind(|| {
            let mut batch = store.batch();
            batch.put_serialized(b"key4", &[10, 11, 12]).unwrap();
            panic!("Simulated panic");
        });

        assert!(result.is_err());
        assert_eq!(store.get::<Vec<u8>>(b"key4")?, None);

        Ok(())
    }
}
