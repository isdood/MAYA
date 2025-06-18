use criterion::{criterion_group, criterion_main, Criterion, BatchSize, BenchmarkId};
use maya_knowledge_graph::storage::{Storage, WriteBatch, WriteBatchExt};
use maya_knowledge_graph::storage::sled_store::SledStore;
use maya_knowledge_graph::storage::cached_store::CachedStore;
use tempfile::tempdir;
use rand::{Rng, SeedableRng};
use rand::rngs::StdRng;
use std::sync::Arc;

// Helper function to generate random keys and values
fn generate_kvs(count: usize, key_size: usize, value_size: usize) -> Vec<(Vec<u8>, Vec<u8>)> {
    let mut rng = StdRng::seed_from_u64(42);
    let mut kvs = Vec::with_capacity(count);
    
    for _ in 0..count {
        let key: Vec<u8> = (0..key_size).map(|_| rng.gen()).collect();
        let value: Vec<u8> = (0..value_size).map(|_| rng.gen()).collect();
        kvs.push((key, value));
    }
    
    kvs
}

// Benchmark for sequential writes
fn bench_sequential_writes(c: &mut Criterion, name: &str, storage: Arc<impl Storage + 'static + Send + Sync>) {
    let sizes = [100, 1_000, 10_000];
    
    for &size in &sizes {
        let kvs = generate_kvs(size, 16, 128);
        let storage_clone = storage.clone();
        
        c.bench_with_input(
            BenchmarkId::new(format!("{}_sequential_writes", name), size),
            &(kvs, storage_clone),
            |b, (kvs, storage)| {
                b.iter_batched(
                    || kvs.clone(),
                    |kvs| {
                        for (k, v) in kvs {
                            storage.put(&k, &v).unwrap();
                        }
                    },
                    BatchSize::SmallInput,
                )
            },
        );
    }
}

// Benchmark for batch writes
fn bench_batch_writes(c: &mut Criterion, name: &str, storage: Arc<impl Storage + WriteBatchExt + 'static + Send + Sync>) {
    let sizes = [100, 1_000, 10_000];
    
    for &size in &sizes {
        let kvs = generate_kvs(size, 16, 128);
        let storage_clone = storage.clone();
        
        c.bench_with_input(
            BenchmarkId::new(format!("{}_batch_writes", name), size),
            &(kvs, storage_clone),
            |b, (kvs, storage)| {
                b.iter_batched(
                    || kvs.clone(),
                    |kvs| {
                        let mut batch = storage.batch();
                        for (k, v) in kvs {
                            batch.put(&k, &v).unwrap();
                        }
                        batch.commit().unwrap();
                    },
                    BatchSize::SmallInput,
                )
            },
        );
    }
}

// Benchmark for reads
fn bench_reads<S: Storage + 'static>(
    c: &mut Criterion,
    name: &str,
    storage: Arc<S>,
    with_warmup: bool,
) {
    let sizes = [100, 1_000, 10_000];
    
    for &size in &sizes {
        let kvs = generate_kvs(size, 16, 128);
        
        // Create a new storage instance for this benchmark
        let storage_clone = storage.clone();
        
        // Warm up the cache if needed
        if with_warmup {
            for (k, v) in &kvs {
                storage_clone.put(k, v).unwrap();
            }
        }
        
        c.bench_with_input(
            BenchmarkId::new(
                format!(
                    "{}_{}_reads",
                    name,
                    if with_warmup { "warm" } else { "cold" }
                ),
                size
            ),
            &(kvs, storage_clone),
            |b, (kvs, storage)| {
                b.iter(|| {
                    for (k, _) in kvs {
                        let _: Option<Vec<u8>> = storage.get(k).unwrap();
                    }
                })
            },
        );
    }
}

// Benchmark for concurrent reads and writes
fn bench_concurrent<S: Storage + 'static + Send + Sync>(
    c: &mut Criterion,
    name: &str,
    storage: Arc<S>,
) {
    use std::sync::Barrier;
    use std::thread;
    
    let thread_counts = [1, 2, 4, 8];
    let ops_per_thread = 1_000;
    
    for &thread_count in &thread_counts {
        let storage_clone = storage.clone();
        
        c.bench_with_input(
            BenchmarkId::new(
                format!("{}_concurrent_rw", name),
                format!("{}_threads", thread_count),
            ),
            &(thread_count, ops_per_thread, storage_clone),
            |b, &(thread_count, ops_per_thread, ref storage)| {
                b.iter_custom(|iters| {
                    let start = std::time::Instant::now();
                    
                    for _ in 0..iters {
                        let barrier = Arc::new(Barrier::new(thread_count as usize + 1));
                        let mut handles = vec![];
                        
                        for thread_id in 0..thread_count {
                            let storage = storage.clone();
                            let barrier = barrier.clone();
                            let kvs = generate_kvs(ops_per_thread, 16, 128);
                            
                            let handle = thread::spawn(move || {
                                barrier.wait();
                                
                                for (i, (k, v)) in kvs.into_iter().enumerate() {
                                    if i % 2 == 0 {
                                        storage.put(&k, &v).unwrap();
                                    } else {
                                        let _: Option<Vec<u8>> = storage.get(&k).unwrap();
                                    }
                                }
                            });
                            
                            handles.push(handle);
                        }
                        
                        barrier.wait();
                        
                        for handle in handles {
                            handle.join().unwrap();
                        }
                    }
                    
                    start.elapsed() / iters as u32
                });
            },
        );
    }
}

// Helper function to create a new SledStore instance
fn new_sled_store() -> SledStore {
    let temp_dir = tempfile::tempdir().unwrap();
    SledStore::open(temp_dir.path()).unwrap()
}

// Benchmark for SledStore
fn bench_sled_store(c: &mut Criterion) {
        // Sequential writes
    let sled_store = Arc::new(new_sled_store());
    bench_sequential_writes(c, "sled", Arc::clone(&sled_store));
    
    // Batch writes
    let sled_store = Arc::new(new_sled_store());
    bench_batch_writes(c, "sled", Arc::clone(&sled_store));
    
    // Cold reads
    let sled_store = Arc::new(new_sled_store());
    bench_reads(c, "sled", Arc::clone(&sled_store), false);
    
    // Warm reads
    let sled_store = Arc::new(new_sled_store());
    bench_reads(c, "sled_warm", Arc::clone(&sled_store), true);
    
    // Concurrent access
    bench_concurrent(c, "sled", sled_store);
}

// Helper function to create a new CachedStore instance
fn new_cached_store() -> CachedStore<SledStore> {
    let sled_store = new_sled_store();
    CachedStore::new(sled_store)
}

// Benchmark for CachedStore with SledStore backend
fn bench_cached_store(c: &mut Criterion) {
    // Sequential writes
    let cached_store = Arc::new(new_cached_store());
    bench_sequential_writes(c, "cached", Arc::clone(&cached_store));
    
    // Batch writes
    let cached_store = Arc::new(new_cached_store());
    bench_batch_writes(c, "cached", Arc::clone(&cached_store));
    
    // Cold reads
    let cached_store = Arc::new(new_cached_store());
    bench_reads(c, "cached", Arc::clone(&cached_store), false);
    
    // Warm reads
    let cached_store = Arc::new(new_cached_store());
    bench_reads(c, "cached_warm", Arc::clone(&cached_store), true);
    
    // Concurrent access
    bench_concurrent(c, "cached", cached_store);
}

// Benchmark for concurrent access
fn bench_concurrent_access(c: &mut Criterion) {
    let sled_store = Arc::new(new_sled_store());
    let cached_store = Arc::new(new_cached_store());
    
    bench_concurrent(c, "sled", Arc::clone(&sled_store));
    bench_concurrent(c, "cached", Arc::clone(&cached_store));
}

criterion_group!(
    benches,
    bench_sled_store,
    bench_cached_store,
    bench_concurrent_access
);
criterion_main!(benches);
