use criterion::{criterion_group, criterion_main, Criterion, BatchSize, BenchmarkId};
use maya_knowledge_graph::storage::{Storage, WriteBatchExt};
use maya_knowledge_graph::storage::sled_store::SledStore;
use maya_knowledge_graph::storage::cached_store::CachedStore;
use maya_knowledge_graph::storage::hybrid_store::HybridStore;
use std::sync::Arc;
use tempfile::tempdir;

// Helper function to generate random keys and values
fn generate_kvs(count: usize, key_size: usize, value_size: usize) -> Vec<(Vec<u8>, Vec<u8>)> {
    (0..count)
        .map(|i| {
            let key = format!("{:0width$}", i, width = key_size).into_bytes();
            let value = vec![i as u8; value_size];
            (key, value)
        })
        .collect()
}

// Benchmark for sequential writes
fn bench_hybrid_sequential_writes(c: &mut Criterion) {
    let sizes = [100, 1_000, 10_000];
    
    for &size in &sizes {
        let kvs = generate_kvs(size, 16, 128);
        
        c.bench_with_input(
            BenchmarkId::new("hybrid_sequential_writes", size),
            &kvs,
            |b, kvs| {
                let temp_dir = tempdir().unwrap();
                let hybrid = HybridStore::new(temp_dir.path()).unwrap();
                
                b.iter_batched(
                    || kvs.clone(),
                    |kvs| {
                        for (k, v) in kvs {
                            hybrid.put(&k, &v).unwrap();
                        }
                    },
                    BatchSize::SmallInput,
                )
            },
        );
    }
}

// Benchmark for mixed workload
fn bench_hybrid_mixed_workload(c: &mut Criterion) {
    let sizes = [100, 1_000];
    
    for &size in &sizes {
        let kvs = generate_kvs(size, 16, 128);
        
        c.bench_with_input(
            BenchmarkId::new("hybrid_mixed_workload", size),
            &kvs,
            |b, kvs| {
                let temp_dir = tempdir().unwrap();
                let hybrid = HybridStore::new(temp_dir.path()).unwrap();
                
                // Pre-populate with data
                for (k, v) in kvs.iter() {
                    hybrid.put(k, v).unwrap();
                }
                
                b.iter(|| {
                    // Mixed workload: 70% reads, 20% writes, 10% deletes
                    for (i, (k, v)) in kvs.iter().enumerate() {
                        match i % 10 {
                            0..=6 => { let _ = hybrid.get::<Vec<u8>>(k); },
                            7..=8 => { let _ = hybrid.put(k, v); },
                            _ => { let _ = hybrid.delete(k); },
                        }
                    }
                });
            },
        );
    }
}

// Benchmark for adaptive behavior
fn bench_hybrid_adaptive(c: &mut Criterion) {
    let sizes = [1_000];
    
    for &size in &sizes {
        let kvs = generate_kvs(size, 16, 128);
        
        c.bench_function(
            &format!("hybrid_adaptive_workload_{}", size),
            |b| {
                let temp_dir = tempdir().unwrap();
                let hybrid = HybridStore::new(temp_dir.path()).unwrap();
                
                // Initial write
                for (k, v) in &kvs {
                    hybrid.put(k, v).unwrap();
                }
                
                b.iter(|| {
                    // Phase 1: Read-heavy workload
                    for (i, (k, _)) in kvs.iter().enumerate() {
                        if i % 10 < 8 { // 80% reads, 20% writes
                            let _ = hybrid.get::<Vec<u8>>(k);
                        } else {
                            let _ = hybrid.put(k, k);
                        }
                    }
                    
                    // Phase 2: Write-heavy workload
                    for (i, (k, _)) in kvs.iter().enumerate() {
                        if i % 10 < 2 { // 20% reads, 80% writes
                            let _ = hybrid.get::<Vec<u8>>(k);
                        } else {
                            let _ = hybrid.put(k, k);
                        }
                    }
                });
            },
        );
    }
}

criterion_group!(
    benches,
    bench_hybrid_sequential_writes,
    bench_hybrid_mixed_workload,
    bench_hybrid_adaptive,
);

criterion_main!(benches);
