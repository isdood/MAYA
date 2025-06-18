//! Cached storage implementation for the knowledge graph

use std::sync::Arc;
use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use parking_lot::RwLock;
use rayon::prelude::*;
use crate::storage::batch_optimizer::{BatchConfig, BatchStats};
use std::fmt;
use serde::de::DeserializeOwned;
use serde::Serialize;
use lru::LruCache;
use crate::error::Result;
use crate::storage::{Storage, WriteBatch, WriteBatchExt, serialize, deserialize};
use crate::error::KnowledgeGraphError;

// ... [rest of the file content remains the same until the WriteBatchExt implementation]

/// A batch of operations that will be applied atomically to the storage
/// and updates the cache accordingly.
#[derive(Debug)]
pub(crate) struct CachedBatch<B> {
    inner: B,
    cache: Arc<RwLock<LruCache<Vec<u8>, Vec<u8>>>>,
    metrics: Arc<CacheMetrics>,
    pending_puts: HashMap<Vec<u8>, Vec<u8>>,
    pending_deletes: HashSet<Vec<u8>>,
    batch_config: BatchConfig,
    stats: BatchStats,
    read_ahead_window: usize,
}

impl<S> WriteBatchExt for CachedStore<S>
where
    S: Storage + WriteBatchExt + 'static,
    S::Batch<'static>: Clone + 'static,
{
    type Batch<'a> = CachedBatch<S::Batch<'a>> where Self: 'a;
    
    fn batch(&self) -> Self::Batch<'_> {
        self.create_batch()
    }
    
    fn create_batch(&self) -> Self::Batch<'_> {
        CachedBatch::with_config(
            self.inner.create_batch(),
            self.cache.clone(),
            self.metrics.clone(),
            self.batch_config.clone(),
            self.read_ahead_window,
        )
    }
    
    // ... [rest of the implementation]
}

// ... [rest of the file]
