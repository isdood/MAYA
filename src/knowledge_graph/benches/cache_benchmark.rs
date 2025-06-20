@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 06:36:03",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/knowledge_graph/benches/cache_benchmark.rs",
    "type": "rs",
    "hash": "e4d1791b92790e7db0611dc1c502a85c41214bd3"
  }
}
@pattern_meta@

//! Benchmark for the cached storage implementation

use criterion::{black_box, criterion_group, criterion_main, Criterion, BatchSize};
use maya_knowledge_graph::{
    storage::{SledStore, CachedStore, Storage},
};
use tempfile::tempdir;
use uuid::Uuid;

fn cache_benchmark(c: &mut Criterion) {
    // Create a temporary directory for the benchmark
    let dir = tempdir().unwrap();
    
    // Create storage backends
    let sled_store = SledStore::open(dir.path()).unwrap();
    let cached_store = CachedStore::new(sled_store, 10_000); // 10,000 item cache
    
    // Benchmark uncached gets (Sled only)
    c.bench_function("sled_get_uncached", |b| {
        let key = b"bench_key";
        let value = "bench_value".to_string();
        
        b.iter(|| {
            cached_store.inner().put(key, &value).unwrap();
            let result = cached_store.inner().get::<String>(key).unwrap();
            black_box(result);
        })
    });
    
    // Benchmark cached gets
    c.bench_function("cached_get", |b| {
        let key = b"cached_key";
        let value = "cached_value".to_string();
        
        // Prime the cache
        cached_store.put(key, &value).unwrap();
        
        b.iter(|| {
            let result = cached_store.get::<String>(key).unwrap();
            black_box(result);
        })
    });
    
    // Benchmark mixed workload (70% reads, 30% writes)
    c.bench_function("mixed_workload", |b| {
        let mut rng = rand::thread_rng();
        let keys: Vec<Vec<u8>> = (0..100)
            .map(|i| format!("key_{}", i).into_bytes())
            .collect();
            
        // Initialize data
        for key in &keys {
            let value = format!("value_{}", String::from_utf8_lossy(key));
            cached_store.put(key, &value).unwrap();
        }
        
        b.iter(|| {
            for _ in 0..100 {
                let idx = rand::random::<usize>() % 100;
                let key = &keys[idx];
                
                if rand::random::<f32>() < 0.7 {
                    // Read operation (70%)
                    let _ = cached_store.get::<String>(key).unwrap();
                } else {
                    // Write operation (30%)
                    let value = format!("new_value_{}", Uuid::new_v4());
                    cached_store.put(key, &value).unwrap();
                }
            }
        })
    });
}

criterion_group!(
    name = benches;
    config = Criterion::default().sample_size(10);
    targets = cache_benchmark
);

criterion_main!(benches);
