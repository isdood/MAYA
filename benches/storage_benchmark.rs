use criterion::{black_box, criterion_group, criterion_main, Criterion};
use maya_knowledge_graph::{
    storage::{SledStore, Storage, WriteBatch},
    error::Result,
};
use tempfile::tempdir;
use uuid::Uuid;
use rand::{thread_rng, Rng};
use std::time::Instant;

fn generate_random_bytes(size: usize) -> Vec<u8> {
    let mut rng = thread_rng();
    (0..size).map(|_| rng.gen()).collect()
}

fn sled_store_benchmark(c: &mut Criterion) {
    let dir = tempdir().unwrap();
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
                batch.commit().unwrap();
            }
            start.elapsed() / 1000 // Average time per batch
        })
    });

    // Benchmark: Iteration with prefix
    // First, insert some test data
    let prefix = b"test_prefix_";
    let mut batch = store.batch();
    for i in 0..1000 {
        let mut key = prefix.to_vec();
        key.extend_from_slice(&i.to_be_bytes());
        let value = generate_random_bytes(256);
        batch.put_serialized(&key, &value).unwrap();
    }
    batch.commit().unwrap();

    c.bench_function("sled_iter_prefix_1000", |b| {
        b.iter(|| {
            let count = store.iter_prefix(prefix).count();
            assert_eq!(count, 1000);
        })
    });
}

fn setup_test_data(store: &SledStore, count: usize, value_size: usize) -> Result<()> {
    let mut batch = store.batch();
    for i in 0..count {
        let key = i.to_be_bytes().to_vec();
        let value = generate_random_bytes(value_size);
        batch.put_serialized(&key, &value)?;
    }
    batch.commit()
}

criterion_group!(
    benches,
    sled_store_benchmark,
);
criterion_main!(benches);
