@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 20:53:49",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/knowledge_graph/src/storage/prefetch.rs",
    "type": "rs",
    "hash": "e7cbc9084a23d88b3f2decebb63a334fb6c6f8c6"
  }
}
@pattern_meta@

use std::collections::VecDeque;
use std::fmt::Debug;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use crossbeam_channel::{bounded, Sender, Receiver};
use log::{debug, error, info, warn};
use parking_lot::{Mutex, Condvar};

use super::{Result, Storage, KnowledgeGraphError};

// Simple notification mechanism for prefetch thread
#[derive(Clone)]
struct PrefetchNotifier {
    condvar: Arc<(Mutex<()>, Condvar)>,
}

impl PrefetchNotifier {
    fn new() -> Self {
        Self {
            condvar: Arc::new((Mutex::new(()), Condvar::new())),
        }
    }
    
    fn notify(&self) {
        let (lock, cvar) = &*self.condvar;
        let _guard = lock.lock().unwrap();
        cvar.notify_all();
    }
    
    fn wait_timeout(&self, timeout: Duration) -> bool {
        let (lock, cvar) = &*self.condvar;
        let guard = lock.lock().unwrap();
        cvar.wait_timeout(guard, timeout).is_ok()
    }
}

/// Configuration for prefetching behavior
#[derive(Clone, Debug)]
pub struct PrefetchConfig {
    /// Number of items to prefetch ahead
    pub prefetch_size: usize,
    /// Maximum number of prefetch buffers to keep
    pub max_buffers: usize,
    /// Size of each prefetch buffer
    pub buffer_size: usize,
    /// Time to wait for prefetch to complete (in ms)
    pub prefetch_timeout_ms: u64,
}

impl Default for PrefetchConfig {
    fn default() -> Self {
        Self {
            prefetch_size: 32,
            max_buffers: 4,
            buffer_size: 1024,
            prefetch_timeout_ms: 100,
        }
    }
}

/// A message sent to the prefetch worker thread
enum PrefetchMessage<K, V> {
    /// Request to prefetch the next batch of items
    Prefetch,
    /// Shut down the worker thread
    Shutdown,
    /// A batch of prefetched items
    Batch(Vec<(K, V)>),
}

/// A prefetching iterator that reads ahead in a background thread
pub struct PrefetchingIterator<K, V, I> 
where
    K: Send + 'static + Clone,
    V: Send + 'static + Clone,
    I: Iterator<Item = (K, V)> + Send + 'static,
{
    // Channel for receiving prefetched items
    rx: crossbeam_channel::Receiver<Option<Vec<(K, V)>>>,
    // Channel for sending requests to the worker
    tx: crossbeam_channel::Sender<PrefetchMessage<K, V>>,
    // Current buffer of prefetched items
    buffer: VecDeque<(K, V)>,
    // Configuration
    config: PrefetchConfig,
    // Worker thread handle
    worker_thread: Option<thread::JoinHandle<()>>,
    // Notification mechanism
    notifier: PrefetchNotifier,
    // Marker for Send + Sync
    _marker: std::marker::PhantomData<fn() -> I>,
}

impl<K, V, I> Iterator for PrefetchingIterator<K, V, I> 
where
    K: Send + 'static + Clone,
    V: Send + 'static + Clone,
    I: Iterator<Item = (K, V)> + Send + 'static,
{
    type Item = Result<(K, V)>;
    
    fn next(&mut self) -> Option<Self::Item> {
        // If buffer is empty, try to fill it
        if self.buffer.is_empty() {
            if let Err(e) = self.fill_buffer() {
                return Some(Err(e));
            }
            
            // If still empty after filling, we're done
            if self.buffer.is_empty() {
                return None;
            }
        }
        
        // Return the next item from the buffer
        self.buffer.pop_front().map(Ok)
    }
}

// Safe to send between threads
unsafe impl<K: Send + 'static + Clone, V: Send + 'static + Clone, I: Iterator<Item = (K, V)> + Send + 'static> Send for PrefetchingIterator<K, V, I> {}

// Safe to share between threads
unsafe impl<K: Send + Sync + 'static + Clone, V: Send + Sync + 'static + Clone, I: Iterator<Item = (K, V)> + Send + Sync + 'static> Sync for PrefetchingIterator<K, V, I> {}

impl<K, V, I> PrefetchingIterator<K, V, I> 
where
    K: Send + 'static + Clone,
    V: Send + 'static + Clone,
    I: Iterator<Item = (K, V)> + Send + 'static,
{
    /// Create a new prefetching iterator
    pub fn new(
        iterator: I,
        config: PrefetchConfig,
    ) -> Result<Self> 
    where
        I: Iterator<Item = (K, V)> + Send + 'static,
    {
        let (tx, rx) = crossbeam_channel::bounded(1);
        let (worker_tx, worker_rx) = crossbeam_channel::bounded(1);
        
        let notifier = PrefetchNotifier::new();
        let notifier_clone = notifier.clone();
        
        let worker_thread = thread::spawn(move || {
            let mut iter = iterator;
            
            loop {
                match worker_rx.recv() {
                    Ok(PrefetchMessage::Prefetch) => {
                        let mut batch = Vec::with_capacity(config.buffer_size);
                        
                        // Prefetch the next batch of items
                        for _ in 0..config.buffer_size {
                            match iter.next() {
                                Some(item) => batch.push(item),
                                None => break,
                            }
                        }
                        
                        // Send the batch back to the main thread
                        if !batch.is_empty() {
                            if let Err(e) = tx.send(Some(batch)) {
                                log::error!("Failed to send prefetched batch: {}", e);
                                break;
                            }
                        } else {
                            // No more items to prefetch
                            let _ = tx.send(None);
                            break;
                        }
                    }
                    Ok(PrefetchMessage::Batch(_)) => {
                        // This variant is not used in this context, but we need to handle it
                        log::warn!("Unexpected Batch message received in prefetch worker");
                    }
                    Ok(PrefetchMessage::Shutdown) => {
                        // Shutdown signal received
                        break;
                    }
                    Err(_) => {
                        // Channel disconnected
                        break;
                    }
                }
            }
        });
        
        // Request the first batch
        let _ = worker_tx.send(PrefetchMessage::Prefetch);
        
        Ok(Self {
            rx,
            tx: worker_tx,
            buffer: VecDeque::with_capacity(config.buffer_size),
            config,
            worker_thread: Some(worker_thread),
            notifier,
            _marker: std::marker::PhantomData,
        })
    }
    
    /// Fill the buffer with more items
    fn fill_buffer(&mut self) -> Result<()> 
    where
        K: Send + 'static + Clone,
        V: Send + 'static + Clone,
        I: Iterator<Item = (K, V)> + Send + 'static,
    {
        // Request the next batch if we're running low
        if self.buffer.len() <= self.config.prefetch_size / 2 {
            if let Err(e) = self.tx.send(PrefetchMessage::Prefetch) {
                return Err(KnowledgeGraphError::StorageError(
                    format!("Failed to request prefetch: {}", e)
                ));
            }
        }
        
        // Wait for the next batch with a timeout
        match self.rx.recv_timeout(Duration::from_millis(self.config.prefetch_timeout_ms)) {
            Ok(Some(batch)) => {
                self.buffer.extend(batch);
                Ok(())
            }
            Ok(None) => {
                // End of stream
                Ok(())
            }
            Err(crossbeam_channel::RecvTimeoutError::Timeout) => {
                // No data available yet, but not an error
                Ok(())
            }
            Err(e) => {
                Err(KnowledgeGraphError::StorageError(
                    format!("Failed to receive prefetched data: {}", e)
                ))
            }
        }
    }
}

impl<K, V, I> Drop for PrefetchingIterator<K, V, I> 
where
    K: Send + 'static + Clone,
    V: Send + 'static + Clone,
    I: Iterator<Item = (K, V)> + Send + 'static,
{
    fn drop(&mut self) {
        // Signal the worker thread to shut down
        let _ = self.tx.send(PrefetchMessage::Shutdown);
        
        // Wait for the worker thread to finish
        if let Some(handle) = self.worker_thread.take() {
            let _ = handle.join();
        }
    }
}
// that doesn't depend on the Storage trait directly, making it more flexible and easier to use.

/// Extension trait for adding prefetching to Storage iterators
pub trait PrefetchExt: Storage {
    /// Create a prefetching iterator for a key prefix
    /// 
    /// This is an alias for `iter_prefix_prefetch` for backward compatibility.
    fn prefetch(
        &self, 
        prefix: &[u8], 
        config: PrefetchConfig
    ) -> Result<PrefetchingIterator<Vec<u8>, Vec<u8>, std::vec::IntoIter<(Vec<u8>, Vec<u8>)>>> {
        self.iter_prefix_prefetch(prefix, config)
    }
    
    /// Create a prefetching iterator for a key prefix
    fn iter_prefix_prefetch(
        &self,
        prefix: &[u8],
        config: PrefetchConfig
    ) -> Result<PrefetchingIterator<Vec<u8>, Vec<u8>, std::vec::IntoIter<(Vec<u8>, Vec<u8>)>>> {
        // Create a standard iterator first and collect it into a Vec to ensure 'static lifetime
        let items: Vec<(Vec<u8>, Vec<u8>)> = self.iter_prefix(prefix).collect();
        
        // Create a new owned iterator from the collected items
        let iterator = items.into_iter();
        
        // Create the prefetching iterator
        PrefetchingIterator::new(iterator, config)
            .map_err(|e| KnowledgeGraphError::StorageError(format!("Failed to create prefetching iterator: {}", e)))
    }
}

// Implement PrefetchExt for all types that implement Storage
impl<T: Storage> PrefetchExt for T {}
