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
    type Batch = SledWriteBatch;

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

    fn batch(&self) -> Self::Batch {
        SledWriteBatch::new(Arc::clone(&self.db))
    }
}

impl WriteBatchExt for SledStore {
    type Batch = SledWriteBatch;

    fn batch(&self) -> Self::Batch {
        SledWriteBatch::new(Arc::clone(&self.db))
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
        
        // Execute the transaction
        let result = db.transaction(|tx| {
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
            Ok(())
        });
        
        // Convert the transaction error to our error type
        match result {
            Ok(_) => {
                // Ensure all changes are persisted to disk
                db.flush()?;
                Ok(())
            }
            Err(e) => Err(crate::error::KnowledgeGraphError::TransactionError(format!("{:?}", e)))
        }
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
        
        // Test put and get
        let key = b"test_key";
        let value = b"test_value";
        
        store.put(key, &value.to_vec())?;
        let retrieved: Option<Vec<u8>> = store.get(key)?;
        
        assert_eq!(retrieved, Some(value.to_vec()));
        
        // Test non-existent key
        let non_existent: Option<Vec<u8>> = store.get(b"non_existent")?;
        assert_eq!(non_existent, None);
        
        Ok(())
    }

    #[test]
    fn test_delete() -> Result<()> {
        let dir = tempdir()?;
        let store = SledStore::open(dir.path())?;
        
        // Add a value
        let key = b"test_key";
        let value = b"test_value";
        store.put(key, &value.to_vec())?;
        
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
        
        // Insert some test data
        store.put(b"prefix:1", &b"value1".to_vec())?;
        store.put(b"prefix:2", &b"value2".to_vec())?;
        store.put(b"other:1", &b"other1".to_vec())?;
        
        // Test prefix iteration
        let mut results: Vec<_> = store.iter_prefix(b"prefix:").collect();
        results.sort();
        
        let expected = vec![
            (b"prefix:1".to_vec(), b"value1".to_vec()),
            (b"prefix:2".to_vec(), b"value2".to_vec()),
        ];
        
        assert_eq!(results, expected);
        
        // Test empty prefix
        let results: Vec<_> = store.iter_prefix(b"nonexistent").collect();
        assert!(results.is_empty());
        
        Ok(())
    }

    #[test]
    fn test_transaction() -> Result<()> {
        let dir = tempdir()?;
        let store = SledStore::open(dir.path())?;

        // Test successful transaction
        let mut batch = <SledStore as Storage>::batch(&store);
        batch.put_serialized(b"key1", &b"value1".to_vec())?;
        batch.put_serialized(b"key2", &b"value2".to_vec())?;
        Box::new(batch).commit()?;

        assert_eq!(store.get::<Vec<u8>>(b"key1")?, Some(b"value1".to_vec()));
        assert_eq!(store.get::<Vec<u8>>(b"key2")?, Some(b"value2".to_vec()));

        // Test delete in transaction
        let mut batch = <SledStore as Storage>::batch(&store);
        batch.put_serialized(b"key1", &b"value1".to_vec())?;
        batch.delete(b"key1")?;
        Box::new(batch).commit()?;

        assert_eq!(store.get::<Vec<u8>>(b"key1")?, None);

        // Test transaction with error (duplicate key in the same batch)
        let mut batch = <SledStore as Storage>::batch(&store);
        batch.put_serialized(b"key1", &b"value1".to_vec())?;
        batch.put_serialized(b"key1", &b"value2".to_vec())?; // Duplicate key
        let result = Box::new(batch).commit();
        assert!(result.is_err());

        // Verify no partial updates
        assert_eq!(store.get::<Vec<u8>>(b"key1")?, None);
        
        Ok(())
    }
}
