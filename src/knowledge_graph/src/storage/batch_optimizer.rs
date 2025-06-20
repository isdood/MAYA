@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 17:16:00",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/knowledge_graph/src/storage/batch_optimizer.rs",
    "type": "rs",
    "hash": "9a0425348bdabef6611853c091770554910c990a"
  }
}
@pattern_meta@

//! Batch processing optimizations for storage operations

use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};
use std::time::Instant;
use parking_lot::RwLock;
use rayon::prelude::*;
use serde::{Serialize, de::DeserializeOwned};
use super::*;

/// Configuration for batch processing
#[derive(Debug, Clone)]
pub struct BatchConfig {
    /// Initial batch size before auto-tuning kicks in
    pub initial_batch_size: usize,
    /// Maximum batch size
    pub max_batch_size: usize,
    /// Minimum batch size
    pub min_batch_size: usize,
    /// Target duration for batch processing in milliseconds
    pub target_batch_duration_ms: u64,
    /// Number of samples to keep for statistics
    pub stats_window_size: usize,
    /// Whether to enable parallel processing
    pub enable_parallel: bool,
}

impl Default for BatchConfig {
    fn default() -> Self {
        Self {
            initial_batch_size: 1_000,
            max_batch_size: 100_000,
            min_batch_size: 100,
            target_batch_duration_ms: 10, // 10ms target
            stats_window_size: 100,
            enable_parallel: true,
        }
    }
}

/// Statistics for batch processing
#[derive(Debug, Default, Clone)]
struct BatchStats {
    /// Operation durations in microseconds
    durations: Vec<u64>,
    /// Batch sizes
    batch_sizes: Vec<usize>,
    /// Current batch size
    current_batch_size: usize,
    /// Total operations processed
    total_ops: AtomicUsize,
    /// Total time spent in processing (microseconds)
    total_duration: AtomicUsize,
}

impl BatchStats {
    fn new(initial_batch_size: usize) -> Self {
        Self {
            durations: Vec::with_capacity(100),
            batch_sizes: Vec::with_capacity(100),
            current_batch_size: initial_batch_size,
            total_ops: AtomicUsize::new(0),
            total_duration: AtomicUsize::new(0),
        }
    }

    /// Record a batch operation
    fn record_batch(&mut self, size: usize, duration: std::time::Duration) {
        let duration_us = duration.as_micros() as u64;
        
        // Update statistics
        if self.durations.len() >= 100 {
            self.durations.remove(0);
            self.batch_sizes.remove(0);
        }
        
        self.durations.push(duration_us);
        self.batch_sizes.push(size);
        
        // Update totals
        self.total_ops.fetch_add(size, Ordering::Relaxed);
        self.total_duration
            .fetch_add(duration_us as usize, Ordering::Relaxed);
            
        // Adjust batch size based on performance
        self.adjust_batch_size(duration);
    }
    
    /// Adjust batch size based on recent performance
    fn adjust_batch_size(&mut self, duration: std::time::Duration) {
        if self.durations.len() < 5 {
            // Not enough data yet
            return;
        }
        
        let target_duration = std::time::Duration::from_millis(10); // 10ms target
        let current_duration = duration.as_millis() as u64;
        
        if current_duration > target_duration.as_millis() as u64 * 2 {
            // Too slow, reduce batch size
            self.current_batch_size = (self.current_batch_size as f64 * 0.8).max(100.0) as usize;
        } else if current_duration < target_duration.as_millis() as u64 / 2 {
            // Too fast, increase batch size
            self.current_batch_size = (self.current_batch_size as f64 * 1.2).min(100_000.0) as usize;
        }
    }
    
    /// Get the current recommended batch size
    fn batch_size(&self) -> usize {
        self.current_batch_size
    }
    
    /// Get the average operations per second
    fn ops_per_second(&self) -> f64 {
        let total_ops = self.total_ops.load(Ordering::Relaxed) as f64;
        let total_duration = self.total_duration.load(Ordering::Relaxed) as f64 / 1_000_000.0; // to seconds
        
        if total_duration > 0.0 {
            total_ops / total_duration
        } else {
            0.0
        }
    }
}

/// A batch processor that handles batching and parallel execution
pub struct BatchProcessor<S> {
    inner: S,
    config: BatchConfig,
    stats: RwLock<BatchStats>,
}

impl<S> BatchProcessor<S> {
    /// Create a new batch processor with default configuration
    pub fn new(inner: S) -> Self {
        Self::with_config(inner, BatchConfig::default())
    }
    
    /// Create a new batch processor with custom configuration
    pub fn with_config(inner: S, config: BatchConfig) -> Self {
        Self {
            inner,
            stats: RwLock::new(BatchStats::new(config.initial_batch_size)),
            config,
        }
    }
    
    /// Process a batch of operations
    pub fn process_batch<F, T, R>(&self, items: &[T], process_fn: F) -> Vec<R>
    where
        F: Fn(&S, &T) -> R + Send + Sync,
        T: Send + Sync,
        R: Send,
    {
        let start_time = Instant::now();
        let batch_size = self.stats.read().batch_size();
        let config = &self.config;
        
        let results = if config.enable_parallel && items.len() > batch_size {
            // Process in parallel chunks
            items
                .par_chunks(batch_size)
                .flat_map(|chunk| {
                    chunk
                        .par_iter()
                        .map(|item| process_fn(&self.inner, item))
                        .collect::<Vec<_>>()
                })
                .collect()
        } else {
            // Process sequentially in chunks
            items
                .chunks(batch_size)
                .flat_map(|chunk| {
                    chunk
                        .iter()
                        .map(|item| process_fn(&self.inner, item))
                        .collect::<Vec<_>>()
                })
                .collect()
        };
        
        // Update statistics
        let duration = start_time.elapsed();
        self.stats.write().record_batch(items.len(), duration);
        
        results
    }
    
    /// Get current statistics
    pub fn stats(&self) -> (usize, f64) {
        let stats = self.stats.read();
        (stats.batch_size(), stats.ops_per_second())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_batch_processor() {
        let processor = BatchProcessor::new(());
        let items: Vec<_> = (0..1000).collect();
        
        let results = processor.process_batch(&items, |_, x| x * 2);
        
        assert_eq!(results.len(), 1000);
        assert_eq!(results[0], 0);
        assert_eq!(results[999], 1998);
        
        let (batch_size, _) = processor.stats();
        assert!(batch_size >= 100);
    }
    
    #[test]
    fn test_parallel_processing() {
        let config = BatchConfig {
            enable_parallel: true,
            initial_batch_size: 100,
            ..Default::default()
        };
        
        let processor = BatchProcessor::with_config((), config);
        let items: Vec<_> = (0..10_000).collect();
        
        let results = processor.process_batch(&items, |_, x| x * 2);
        
        assert_eq!(results.len(), 10_000);
        assert_eq!(results[0], 0);
        assert_eq!(results[9999], 19_998);
    }
}
