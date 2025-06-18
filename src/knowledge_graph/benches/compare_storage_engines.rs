//! Benchmark comparison between Sled and RocksDB storage backends

use criterion::{criterion_group, criterion_main, Criterion};
use maya_knowledge_graph::storage::{
    Storage, WriteBatch, WriteBatchExt, sled_store::SledStore
};
use rand::{thread_rng, Rng};
use std::time::Duration;
use uuid::Uuid;

/// Generate random bytes of specified size
fn generate_random_bytes(size: usize) -> Vec<u8> {
    let mut rng = thread_rng();
    (0..size).map(|_| rng.gen()).collect()
}

fn sled_benchmark(c: &mut Criterion) {
    // Setup: Create a temporary directory and initialize the store
    let temp_dir = tempfile::tempdir().expect("Failed to create temp dir");
    let store = SledStore::open(temp_dir.path()).expect("Failed to create SledStore");
    
    // Benchmark: Single write operation
    c.bench_function("sled_write_1kb", |b| {
        let key = Uuid::new_v4().as_bytes().to_vec();
        let value = generate_random_bytes(1024);
        b.iter(|| {
            store.put(&key, &value).expect("Write failed");
        });
    });
    
    // Benchmark: Single read operation
    c.bench_function("sled_read_1kb", |b| {
        let key = Uuid::new_v4().as_bytes().to_vec();
        let value = generate_random_bytes(1024);
        store.put(&key, &value).expect("Write failed");
        
        b.iter(|| {
            let _: Vec<u8> = store.get(&key).unwrap().expect("Read failed");
        });
    });
    
    // Benchmark: Batch write operations
    c.bench_function("sled_batch_write_100_items", |b| {
        b.iter(|| {
            let mut batch = Storage::batch(&store);
            for _ in 0..100 {
                let key = Uuid::new_v4().as_bytes().to_vec();
                let value = generate_random_bytes(512);
                batch.put_serialized(&key, &value).expect("Batch put failed");
            }
            Box::new(batch).commit().expect("Batch commit failed");
        });
    });
    
    // Benchmark: Iteration with prefix
    c.bench_function("sled_iterate_1000_items", |b| {
        // Setup: Insert test data
        let prefix = b"test_prefix_";
        let item_count = 1000;
        
        // Clear previous data
        let mut batch = Storage::batch(&store);
        for i in 0usize..item_count {
            let mut key = prefix.to_vec();
            key.extend_from_slice(&i.to_be_bytes());
            let value = generate_random_bytes(64);
            batch.put_serialized(&key, &value).expect("Batch put failed");
        }
        Box::new(batch).commit().expect("Batch commit failed");
        
        // Benchmark iteration
        b.iter(|| {
            let count = store.iter_prefix(prefix).count();
            assert_eq!(count, item_count);
        });
    });
}

criterion_group! {
    name = benches;
    config = Criterion::default()
        .sample_size(10)
        .measurement_time(Duration::from_secs(5))
        .warm_up_time(Duration::from_secs(1));
    targets = sled_benchmark
}

criterion_main!(benches);
