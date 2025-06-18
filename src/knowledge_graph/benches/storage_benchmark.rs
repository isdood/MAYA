use criterion::{black_box, criterion_group, criterion_main, Criterion};
use maya_knowledge_graph::storage::{SledStore, Storage, WriteBatch};
use uuid::Uuid;
use rand::{thread_rng, Rng};
use std::time::Instant;

fn generate_random_bytes(size: usize) -> Vec<u8> {
    let mut rng = thread_rng();
    (0..size).map(|_| rng.gen()).collect()
}

fn sled_store_benchmark(c: &mut Criterion) {
    let dir = tempfile::tempdir().unwrap();
    let store = SledStore::open(dir.path()).unwrap();
    
    // Benchmark: Single put operation
    c.bench_function("sled_put", |b| {
        let key = Uuid::new_v4().as_bytes().to_vec();
        let value = generate_random_bytes(1024); // 1KB value
        b.iter(|| {
            store.put(black_box(&key), black_box(&value)).unwrap();
        })
    });

    // Benchmark: Single get operation
    let key = Uuid::new_v4().as_bytes().to_vec();
    let value = generate_random_bytes(1024);
    store.put(&key, &value).unwrap();
    
    c.bench_function("sled_get", |b| {
        b.iter(|| {
            let _: Vec<u8> = black_box(store.get(black_box(&key)).unwrap().unwrap());
        })
    });

    // Benchmark: Batch operations
    c.bench_function("sled_batch_1000_puts", |b| {
        b.iter_custom(|iter| {
            let start = Instant::now();
            for _ in 0..iter {
                let mut batch = store.batch();
                for _ in 0..1000 {
                    let key = Uuid::new_v4().as_bytes().to_vec();
                    let value = generate_random_bytes(512);
                    batch.put_serialized(&key, &value).unwrap();
                }
                Box::new(batch).commit().unwrap();
            }
            start.elapsed() / 1000 // Average time per batch
        })
    });

    // Benchmark: Iteration with prefix (minimal dataset for microbenchmarking)
    const ITEM_COUNT: u32 = 10;  // Further reduced for microbenchmarking
    let prefix = b"test_prefix_";
    
    // Setup: Insert minimal test data
    {
        let mut batch = store.batch();
        for i in 0..ITEM_COUNT {
            let mut key = prefix.to_vec();
            key.extend_from_slice(&i.to_be_bytes());
            let value = generate_random_bytes(64);  // Minimal value size
            batch.put_serialized(&key, &value).unwrap();
        }
        Box::new(batch).commit().unwrap();
    }

    // Use a custom benchmark group with different settings for the iteration test
    let mut group = c.benchmark_group("iteration");
    group.sample_size(10);  // Reduce number of samples
    group.measurement_time(std::time::Duration::from_secs(5));  // Limit measurement time
    
    group.bench_function("sled_iter_prefix", |b| {
        b.iter(|| {
            // Just iterate without counting to make it faster
            let _: Vec<_> = store.iter_prefix(prefix).collect();
        })
    });
    
    group.finish();
}


criterion_group!(
    benches,
    sled_store_benchmark,
);
criterion_main!(benches);
