use std::collections::VecDeque;
use std::sync::{Arc, Mutex, Condvar};
use std::thread::{self, JoinHandle};
use std::sync::atomic::{AtomicBool, Ordering};
use super::{Result, Storage, KnowledgeGraphError};
use crossbeam_channel::{bounded, Sender, Receiver};
use log::{debug, error, info, warn};
use parking_lot::{Mutex, Condvar};
use std::collections::VecDeque;
use std::fmt::Debug;
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Duration;

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
pub struct PrefetchingIterator<K, V, I> {
    // Channel for receiving prefetched items
    rx: crossbeam_channel::Receiver<Option<Vec<(K, V)>>>,
    // Channel for sending requests to the worker
    tx: crossbeam_channel::Sender<PrefetchMessage>,
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

// Safe because we ensure thread safety through channels
unsafe impl<K: Send, V: Send> Send for PrefetchingIterator<K, V> {}
unsafe impl<K: Send, V: Send> Sync for PrefetchingIterator<K, V> {}

impl<K, V> PrefetchingIterator<K, V> 
where
    K: Send + 'static + Clone,
    V: Send + 'static + Clone,
{
    /// Create a new prefetching iterator
    pub fn new(
        iterator: I,
        config: PrefetchConfig,
    ) -> Result<Self> 
    where
        I: Iterator<Item = (K, V)> + Send + 'static,
    {
        let (tx, rx) = crossbeam_channel::bounded(1); // Single item channel for results
        let (control_tx, control_rx) = crossbeam_channel::bounded(1); // Control channel for commands
        let notifier = PrefetchNotifier::new();
        
        // Create the buffer with some initial capacity
        let buffer = VecDeque::with_capacity(config.buffer_size * 2);
        
        // Spawn the worker thread
        let worker_thread = thread::spawn(move || {
            let mut iterator = iterator;
            let mut batch = Vec::with_capacity(config.buffer_size);
            
            // Process messages from the main thread
            while let Ok(msg) = control_rx.recv() {
                match msg {
                    PrefetchMessage::Prefetch => {
                        // Prefetch the next batch
                        batch.clear();
                        for _ in 0..config.buffer_size {
                            if let Some(item) = iterator.next() {
                                batch.push(item);
                            } else {
                                break;
                            }
                        }
                        
                        if !batch.is_empty() {
                            // Send the batch through the result channel
                            if let Err(e) = tx.send(Some(batch.clone())) {
                                error!("Failed to send prefetched batch: {}", e);
                                break;
                            }
                            worker_notifier.notify();
                        } else {
                            // No more items, signal end of stream
                            let _ = tx.send(None);
                            break;
                        }
                    }
                    PrefetchMessage::Shutdown => break,
                    _ => {}
                }
            }
        });
        
        // Request initial prefetch
        if let Err(e) = control_tx.send(PrefetchMessage::Prefetch) {
            error!("Failed to send initial prefetch request: {}", e);
            return Err(KnowledgeGraphError::StorageError(
                "Failed to initialize prefetching".to_string()
            ));
        }
        
        Ok(Self {
            rx,
            tx: control_tx,
            buffer,
            config,
            worker_thread: Some(worker_thread),
            notifier,
            _marker: std::marker::PhantomData,
        })
    }
    
    /// Fill the buffer with more items
    fn fill_buffer(&mut self) -> Result<()> {
        // Request the next batch
        if let Err(e) = self.tx.send(PrefetchMessage::Prefetch) {
            return Err(KnowledgeGraphError::StorageError(
                format!("Failed to request prefetch: {}", e)
            ));
        }
        
        // Wait for the next batch
        match self.rx.recv() {
            Ok(Some(batch)) => {
                self.buffer.extend(batch);
                Ok(())
            }
            Ok(None) => {
                // End of stream
                Ok(())
            }
            Err(e) => Err(KnowledgeGraphError::StorageError(
                format!("Failed to receive prefetched batch: {}", e)
            )),
        }
    }
}

impl<K, V> Drop for PrefetchingIterator<K, V> {
    fn drop(&mut self) {
        // Signal worker to shut down
        let _ = self.tx.send(PrefetchMessage::Shutdown);
        
        // Wait for worker thread to finish
        if let Some(thread) = self.worker_thread.take() {
            if let Err(e) = thread.join() {
                log::error!("Error joining prefetch worker thread: {:?}", e);
            }
        }
    }
}

// The PrefetchingIterator implementation has been moved above and is now a standalone type
// that doesn't depend on the Storage trait directly, making it more flexible and easier to use.

/// Extension trait for adding prefetching to Storage iterators
pub trait PrefetchExt: Storage {
    /// Create a prefetching iterator for a key prefix
    fn iter_prefix_prefetch(
        &self, 
        prefix: &[u8], 
        config: PrefetchConfig
    ) -> Result<PrefetchingIterator<Vec<u8>, Vec<u8>>> {
        // Create a standard iterator first
        let iterator = self.iter_prefix(prefix);
        
        // Convert the iterator to a Vec to ensure it's 'static
        let items: Vec<(Vec<u8>, Vec<u8>)> = iterator.collect();
        
        // Create a new iterator from the collected items
        let iterator = items.into_iter();
        
        // Create the prefetching iterator
        PrefetchingIterator::new(iterator, config)
            .map_err(|e| KnowledgeGraphError::StorageError(format!("Failed to create prefetching iterator: {}", e)))
    }
}

// Implement PrefetchExt for all types that implement Storage
impl<T: Storage> PrefetchExt for T {}
