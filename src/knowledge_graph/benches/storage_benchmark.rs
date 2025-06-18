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
fn bench_sequential_writes(c: &mut Criterion, name: &str, storage: impl Storage + Clone + 'static) {
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
fn bench_batch_writes(c: &mut Criterion, name: &str, storage: impl Storage + WriteBatchExt + Clone + 'static) {
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
fn bench_reads<S: Storage + 'static>(c: &mut Criterion, name: &str, storage: S, with_warmup: bool) {
    let sizes = [100, 1_000, 10_000];
    
    for &size in &sizes {
        let kvs = generate_kvs(size, 16, 128);
        
        // Insert test data
        for (k, v) in &kvs {
            storage.put(k, v).unwrap();
        }
        
        // Warm up the cache if needed
        if with_warmup {
            for (k, _) in &kvs {
                let _: Option<Vec<u8>> = storage.get(k).unwrap();
            }
        }
        
        c.bench_with_input(
            BenchmarkId::new(
                format!("{}_reads_{}", name, if with_warmup { "warm" } else { "cold" }),
                size
            ),
            &kvs,
            |b, kvs| {
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
                    
                    start.elapsed() / iters
                });
            },
        );
    }
}

// Benchmark for SledStore
fn bench_sled_store(c: &mut Criterion) {
    let temp_dir = tempdir().unwrap();
    let sled_store = SledStore::open(temp_dir.path()).unwrap();
    
    bench_sequential_writes(c, "sled", sled_store.clone());
    bench_batch_writes(c, "sled", sled_store.clone());
    
    // Create a new instance for reads to avoid cache effects
    let sled_store_reads = SledStore::open(temp_dir.path()).unwrap();
    bench_reads(c, "sled", sled_store_reads, false);
    
    // Another instance for warm reads
    let sled_store_warm = SledStore::open(temp_dir.path()).unwrap();
    bench_reads(c, "sled_warm", sled_store_warm, true);
    
    // Test with and without flush on commit using Arc for thread safety
    let sled_store_arc = Arc::new(sled_store);
    bench_concurrent(c, "sled_flush", Arc::clone(&sled_store_arc), true);
    bench_concurrent(c, "sled_no_flush", Arc::clone(&sled_store_arc), false);
    
    // Cleanup
    temp_dir.close().unwrap();
}

// Benchmark for CachedStore with SledStore backend
fn bench_cached_store(c: &mut Criterion) {
    let temp_dir = tempdir().unwrap();
    let sled_store = SledStore::open(temp_dir.path()).unwrap();
    let cached_store = CachedStore::new(sled_store);
    
    bench_sequential_writes(c, "cached", cached_store.clone());
    bench_batch_writes(c, "cached", cached_store.clone());
    
    // Create a new instance for reads to avoid cache effects
    let sled_store_reads = SledStore::open(temp_dir.path()).unwrap();
    let cached_store_reads = CachedStore::new(sled_store_reads);
    bench_reads(c, "cached", cached_store_reads, false);
    
    // Another instance for warm reads
    let sled_store_warm = SledStore::open(temp_dir.path()).unwrap();
    let cached_store_warm = CachedStore::new(sled_store_warm);
    bench_reads(c, "cached_warm", cached_store_warm, true);
    
    // Test with and without flush on commit using Arc for thread safety
    let cached_store_arc = Arc::new(cached_store);
    bench_concurrent(c, "cached_flush", Arc::clone(&cached_store_arc), true);
    bench_concurrent(c, "cached_no_flush", Arc::clone(&cached_store_arc), false);
    
    // Cleanup
    temp_dir.close().unwrap();
}

// Benchmark for concurrent access
fn bench_concurrent_access(c: &mut Criterion) {
    let temp_dir = tempdir().unwrap();
    let sled_store = Arc::new(SledStore::open(temp_dir.path()).unwrap());
    let cached_store = Arc::new(CachedStore::new((*sled_store).clone()));
    
    bench_concurrent(c, "sled_concurrent", sled_store);
    bench_concurrent(c, "cached_concurrent", cached_store);
    
    // Cleanup
    temp_dir.close().unwrap();
}

criterion_group!(
    benches,
    bench_sled_store,
    bench_cached_store,
    bench_concurrent_access
);
criterion_main!(benches);
