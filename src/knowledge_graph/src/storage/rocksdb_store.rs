
//! RocksDB storage implementation for the knowledge graph

use std::path::Path;
use std::sync::Arc;

use rocksdb::{
    DB, IteratorMode, Options, WriteBatch as RocksWriteBatch, DBCompressionType, Cache,
    BlockBasedOptions, ReadOptions
};
use serde::{Serialize, de::DeserializeOwned};
use log::warn;

use crate::error::{Result, KnowledgeGraphError};
use super::{Storage, WriteBatch};

/// RocksDB storage implementation
pub struct RocksDBStore {
    db: Arc<DB>,
    cache: Option<Cache>,
}

impl RocksDBStore {
    /// Open or create a new RocksDB database at the given path
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self> {
        let mut opts = Options::default();
        
        // Configure RocksDB options
        opts.create_if_missing(true);
        opts.create_missing_column_families(true);
        opts.set_compression_type(DBCompressionType::Lz4);
        opts.set_use_fsync(false);
        opts.set_manual_wal_flush(true);
        
        // Configure block-based table options
        let mut block_opts = BlockBasedOptions::default();
        let cache = Cache::new_lru_cache(128 * 1024 * 1024); // 128MB cache
        block_opts.set_block_cache(&cache);
        block_opts.set_block_size(16 * 1024); // 16KB block size
        
        // Open the database
        let db = DB::open_cf(
            &opts,
            path,
            &["default", "nodes", "edges", "indices"],
        )?;
        
        Ok(Self {
            db: Arc::new(db),
            cache: Some(cache),
        })
    }
    
    /// Get a reference to the underlying RocksDB instance
    pub fn inner(&self) -> &DB {
        &self.db
    }
}

impl Storage for RocksDBStore {
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
        self.db.put(key, bytes)?;
        Ok(())
    }

    fn delete(&self, key: &[u8]) -> Result<()> {
        self.db.delete(key)?;
        Ok(())
    }

    fn exists(&self, key: &[u8]) -> Result<bool> {
        Ok(self.db.get_pinned(key)?.is_some())
    }

    fn iter_prefix<'a>(&'a self, prefix: &[u8]) -> Box<dyn Iterator<Item = (Vec<u8>, Vec<u8>)> + 'a> {
        let iter = self.db.iterator(IteratorMode::From(prefix, rocksdb::Direction::Forward));
        
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
        Box::new(RocksWriteBatchWrapper {
            batch: RocksWriteBatch::default(),
            db: Arc::clone(&self.db),
        })
    }
}

/// RocksDB write batch wrapper
struct RocksWriteBatchWrapper {
    batch: RocksWriteBatch,
    db: Arc<DB>,
}

impl WriteBatch for RocksWriteBatchWrapper {
    fn put<T: Serialize>(&mut self, key: &[u8], value: &T) -> Result<()> {
        let bytes = serialize(value)?;
        self.batch.put(key, &bytes);
        Ok(())
    }

    fn delete(&mut self, key: &[u8]) -> Result<()> {
        self.batch.delete(key);
        Ok(())
    }

    fn commit(mut self: Box<Self>) -> Result<()> {
        self.db.write(self.batch)?;
        Ok(())
    }
}

// Re-export serialization functions from the parent module
use super::{serialize, deserialize};
