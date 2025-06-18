//! Cached storage implementation for the knowledge graph

use std::sync::Arc;
use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use parking_lot::RwLock;
use rayon::prelude::*;
use crate::storage::batch_optimizer::{BatchConfig, BatchStats};
use std::fmt;
use bincode;

// ... [rest of the imports and code remains the same until the test module]

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::sled_store::SledStore;
    use tempfile::tempdir;
    use std::sync::Arc;
    use parking_lot::RwLock;
    use std::time::Duration;
    use std::thread;

    #[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
    struct TestValue {
        data: String,
        count: u64,
    }
    
    impl TestValue {
        fn new(data: &str, count: u64) -> Self {
            Self {
                data: data.to_string(),
                count,
            }
        }
        
        fn to_bytes(&self) -> Vec<u8> {
            bincode::serialize(self).expect("Failed to serialize TestValue")
        }
        
        fn from_bytes(bytes: &[u8]) -> Result<Self> {
            bincode::deserialize(bytes).map_err(|e| KnowledgeGraphError::SerializationError(e.to_string()).into())
        }
    }

    // ... [rest of the test functions remain the same until test_batch_configuration]

    #[test]
    fn test_batch_configuration() -> Result<()> {
        // Create a temporary directory for the test
        let temp_dir = tempdir()?;
        
        // Create a custom batch configuration
        let batch_config = BatchConfig {
            initial_batch_size: 100,
            min_batch_size: 10,
            max_batch_size: 500,
            target_batch_duration_ms: 50,
            stats_window_size: 10,
            enable_parallel: true,
        };
        
        // Create a cache config
        let cache_config = CacheConfig {
            capacity: 1024 * 1024, // 1MB
            read_ahead: true,
            read_ahead_size: 10,
            enable_compression: true,
        };
        
        // Create a CachedStore with the custom configs
        let inner = SledStore::open(temp_dir.path())?;
        let mut cached_store = CachedStore::with_config(
            inner,
            cache_config,
            batch_config.clone(),
        );
        
        // Set the read_ahead_window
        cached_store.read_ahead_window = 100; // Example value
        
        let cache = Arc::new(RwLock::new(cached_store));
        
        // Verify the batch config was set correctly
        {
            let store = cache.read();
            let config = store.batch_config();
            assert_eq!(config.initial_batch_size, 100);
            assert_eq!(config.min_batch_size, 10);
            assert_eq!(config.max_batch_size, 500);
            assert_eq!(config.target_batch_duration_ms, 50);
            assert_eq!(config.stats_window_size, 10);
            assert!(config.enable_parallel);
        }
        
        // Create a batch and verify it uses the config
        let mut batch = cache.write().create_batch();
        
        // Add multiple items to the batch
        for i in 0..150 {  // More than initial_batch_size
            let key = format!("key_{}", i).into_bytes();
            let value = TestValue::new(&format!("value_{}", i), i as u64);
            let serialized = value.to_bytes();
            batch.put_serialized(&key, &serialized)?;
        }
        
        // Commit the batch
        batch.commit()?;
        
        // Verify the data was written
        for i in 0..150 {
            let key = format!("key_{}", i).into_bytes();
            let bytes = cache.read().get_raw(&key)?.ok_or_else(|| 
                KnowledgeGraphError::KeyNotFound(String::from_utf8_lossy(&key).to_string())
            )?;
            let value = TestValue::from_bytes(&bytes)?;
            assert_eq!(value.data, format!("value_{}", i));
            assert_eq!(value.count, i as u64);
        }
        
        // Test batch configuration update
        let new_batch_config = BatchConfig {
            initial_batch_size: 200,
            ..batch_config.clone()
        };
        
        // Update the batch config
        cache.write().set_batch_config(new_batch_config);
        
        // Verify the update was applied
        let updated_config = cache.read().batch_config();
        assert_eq!(updated_config.initial_batch_size, 200);
        
        // Test batch operations with updated config
        let mut new_batch = cache.write().create_batch();
        
        // Add more items to test the new batch size
        for i in 150..300 {
            let key = format!("key_{}", i).into_bytes();
            let value = TestValue::new(&format!("value_{}", i), i as u64);
            let serialized = value.to_bytes();
            new_batch.put_serialized(&key, &serialized)?;
        }
        
        // Commit the new batch
        new_batch.commit()?;
        
        // Verify the new data was written
        for i in 150..300 {
            let key = format!("key_{}", i).into_bytes();
            let bytes = cache.read().get_raw(&key)?.ok_or_else(|| 
                KnowledgeGraphError::KeyNotFound(String::from_utf8_lossy(&key).to_string())
            )?;
            let value = TestValue::from_bytes(&bytes)?;
            assert_eq!(value.data, format!("value_{}", i));
            assert_eq!(value.count, i as u64);
        }
        
        Ok(())
    }
    
    // ... [rest of the test functions remain the same]
}
