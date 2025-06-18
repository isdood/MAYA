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
        let iter = self.db.iter();
        let prefix = prefix.to_vec();
        
        let filtered = iter.filter_map(move |item| {
            if let Ok((key, value)) = item {
                if key.starts_with(&prefix) {
                    // Convert IVec to Vec<u8> for the key and value
                    Some((key.to_vec(), value.to_vec()))
                } else {
                    None
                }
            } else {
                None
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
        SledWriteBatch::new(self.db.clone())
    }

    fn commit(batch: Box<dyn WriteBatch>) -> Result<()> {
        if let Some(batch) = batch.as_any().downcast_ref::<SledWriteBatch>() {
            let db = batch.db.clone();
            
            // Execute the transaction
            let result = db.transaction(|tx| {
                for op in &batch.ops {
                    match op {
                        BatchOp::Put(key, value) => {
                            tx.insert(key, value)?;
                        }
                        BatchOp::Delete(key) => {
                            tx.remove(key)?;
                        }
                    }
                }
                Ok::<_, sled::transaction::ConflictableTransactionError<sled::transaction::TransactionError>>(())
            });
            
            match result {
                Ok(_) => {
                    // Ensure all changes are persisted to disk
                    db.flush()?;
                    Ok(())
                }
                Err(e) => Err(crate::error::KnowledgeGraphError::TransactionError(e.to_string()))
            }
        } else {
            Err(crate::error::KnowledgeGraphError::InvalidOperation("Invalid batch type".to_string()))
        }
    }
}

/// Sled write batch wrapper
#[derive(Debug, Clone)]
pub struct SledWriteBatch {
    db: Arc<Db>,
    ops: Vec<BatchOp>,
}

unsafe impl Send for SledWriteBatch {}
unsafe impl Sync for SledWriteBatch {}

#[derive(Debug, Clone)]
enum BatchOp {
    Put(IVec, IVec),
    Delete(IVec),
}

unsafe impl Send for BatchOp {}
unsafe impl Sync for BatchOp {}

impl WriteBatchExt for SledWriteBatch {
    type Batch = SledWriteBatch;
    
    fn batch(&self) -> Self::Batch {
        SledWriteBatch::new(Arc::clone(&self.db))
    }
    
    fn commit(batch: Box<dyn WriteBatch>) -> Result<()> {
        if let Some(batch) = batch.as_any().downcast_ref::<SledWriteBatch>() {
            let db = Arc::clone(&batch.db);
            let ops = batch.ops.clone();
            
            // Create a new sled batch
            let mut sled_batch = sled::Batch::default();
            
            // Apply all operations to the sled batch
            for op in ops {
                match op {
                    BatchOp::Put(k, v) => sled_batch.insert(k, v),
                    BatchOp::Delete(k) => sled_batch.remove(k),
                }
            }
            
            // Apply the batch to the database
            db.apply_batch(sled_batch)
                .map_err(|e| crate::error::KnowledgeGraphError::from(e))?;
            Ok(())
        } else {
            Err(crate::error::KnowledgeGraphError::from("Failed to downcast batch to SledWriteBatch"))
        }
    }
}

impl WriteBatch for SledWriteBatch {
    fn put(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.put(IVec::from(key), IVec::from(value));
        Ok(())
    }
    
    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.delete(IVec::from(key));
        Ok(())
    }
    
    fn put_serialized(&mut self, key: &[u8], value: &[u8]) -> Result<()> {
        self.put(IVec::from(key), IVec::from(value));
        Ok(())
    }
    
    fn clear(&mut self) {
        self.ops.clear();
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    
    fn commit(self: Box<Self>) -> Result<()> {
        let db = Arc::clone(&self.db);
        let ops = self.ops;
        
        // Create a new sled batch
        let mut sled_batch = sled::Batch::default();
        
        // Apply all operations to the sled batch
        for op in ops {
            match op {
                BatchOp::Put(k, v) => sled_batch.insert(k, v),
                BatchOp::Delete(k) => sled_batch.remove(k),
            Ok(_) => {
                // Ensure all changes are persisted to disk
                db.flush()?;
                Ok(())
            }
            Err(e) => Err(crate::error::KnowledgeGraphError::TransactionError(e.to_string()))
        }
    }
}

impl SledWriteBatch {
    /// Create a new write batch
    pub fn new(db: Arc<Db>) -> Self {
        Self {
            db,
            ops: Vec::new(),
        }
    }
    
    /// Add a put operation to the batch
    pub fn put(&mut self, key: impl Into<IVec>, value: impl Into<IVec>) {
        self.ops.push(BatchOp::Put(key.into(), value.into()));
    }
    
    /// Add a delete operation to the batch
    pub fn delete(&mut self, key: impl Into<IVec>) {
        self.ops.push(BatchOp::Delete(key.into()));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile;

    #[test]
    fn test_put_and_get() -> Result<()> {
        let dir = tempfile::tempdir()?;
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
        let dir = tempfile::tempdir()?;
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
        let dir = tempfile::tempdir()?;
        let store = SledStore::open(dir.path())?;
        
        // Insert some test data
        store.put(b"prefix:1", &b"value1".to_vec())?;
        store.put(b"prefix:2", &b"value2".to_vec())?;
        store.put(b"other:1", &b"other1".to_vec())?;
        
        // Test prefix iteration
        let mut results: Vec<_> = store.iter_prefix(b"prefix:")
            .map(|(k, v)| (k, deserialize::<Vec<u8>>(&v).unwrap()))
            .collect();
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
        let dir = tempfile::tempdir()?;
        let store = SledStore::open(dir.path())?;

        // Helper function to create a serialized value
        fn to_serialized(value: &[u8]) -> Vec<u8> {
            serde_json::to_vec(&value).unwrap()
        }

        // Test successful transaction with raw bytes
        let batch = <SledStore as Storage>::batch(&store);
        let value1 = b"value1";
        let value2 = b"value2";
        
        // Use put_serialized with raw bytes
        batch.put_serialized(b"key1", value1)?;
        batch.put_serialized(b"key2", value2)?;
        Box::new(batch).commit()?;

        // Verify the values were stored and can be retrieved
        let stored1: Option<Vec<u8>> = store.get(b"key1")?;
        assert_eq!(stored1.as_deref(), Some(value1.as_slice()));
        
        let stored2: Option<Vec<u8>> = store.get(b"key2")?;
        assert_eq!(stored2.as_deref(), Some(value2.as_slice()));

        // Test delete in transaction
        let mut batch = <SledStore as Storage>::batch(&store);
        batch.put_serialized(b"key1", value1)?;
        batch.delete(b"key1");  // Delete the key
        Box::new(batch).commit()?;

        // Verify the key was deleted
        assert!(store.get::<Vec<u8>>(b"key1")?.is_none());

        // Test transaction with duplicate key in the same batch
        let batch = <SledStore as Storage>::batch(&store);
        // First put
        batch.put_serialized(b"key1", value1)?;
        // Second put to the same key will overwrite
        batch.put_serialized(b"key1", value2)?;
        Box::new(batch).commit()?;

        // Verify the value was updated to the last write
        let stored: Option<Vec<u8>> = store.get(b"key1")?;
        assert_eq!(stored.as_deref(), Some(value2.as_slice()));
        
        Ok(())
    }
}
