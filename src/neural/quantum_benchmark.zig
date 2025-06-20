const std = @import("std");
const time = std.time;
const print = std.debug.print;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const QuantumProcessor = @import("quantum_processor.zig").QuantumProcessor;
const QuantumState = @import("quantum_types.zig").QuantumState;

const BENCHMARK_ITERATIONS = 1000;

pub fn benchmarkQuantumOperations(allocator: Allocator) !void {
    print("\n=== Quantum Processor Performance Benchmark ===\n", .{});
    
    // Initialize processor
    var processor = try QuantumProcessor.init(allocator, .{});
    defer processor.deinit();
    
    // Benchmark qubit operations
    try benchmarkQubitOperations(&processor);
    
    // Benchmark state operations
    try benchmarkStateOperations(&processor);
    
    // Benchmark pattern processing
    try benchmarkPatternProcessing(&processor);
}

fn benchmarkQubitOperations(processor: *QuantumProcessor) !void {
    const start = time.nanoTimestamp();
    
    for (0..BENCHMARK_ITERATIONS) |_| {
        // Test single qubit operations
        processor.reset();
        
        // Apply a series of gates
        processor.applyGate(.X, 0);
        processor.applyGate(.H, 0);
        processor.applyGate(.Z, 0);
        processor.measure(0);
    }
    
    const elapsed_ns = time.nanoTimestamp() - start;
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));
    
    print("Qubit Operations: {d:.2} ns/op\n", .{ns_per_op});
}

fn benchmarkStateOperations(processor: *QuantumProcessor) !void {
    const start = time.nanoTimestamp();
    
    for (0..BENCHMARK_ITERATIONS) |i| {
        // Create a test state
        const state = QuantumState{
            .coherence = 0.9,
            .entanglement = 0.5,
            .superposition = 0.3,
            .qubits = undefined, // Will be set by setState
        };
        
        // Test state setting
        try processor.setState(state);
        
        // Test state getting
        _ = processor.getState();
    }
    
    const elapsed_ns = time.nanoTimestamp() - start;
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));
    
    print("State Operations: {d:.2} ns/op\n", .{ns_per_op});
}

fn benchmarkPatternProcessing(processor: *QuantumProcessor) !void {
    const test_pattern = "test_quantum_pattern";
    var results: [BENCHMARK_ITERATIONS]u64 = undefined;
    
    const start = time.nanoTimestamp();
    
    for (0..BENCHMARK_ITERATIONS) |i| {
        // Process a pattern and measure time
        const result = try processor.processPattern(test_pattern);
        results[i] = result.confidence;
    }
    
    const elapsed_ns = time.nanoTimestamp() - start;
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));
    
    print("Pattern Processing: {d:.2} ns/op\n", .{ns_per_op});
}

test "benchmark quantum operations" {
    // This test is marked as skipped by default to avoid running in normal test runs
    // Run it explicitly with: zig test src/neural/quantum_benchmark.zig --test-filter benchmark
    if (true) return error.SkipZigTest;
    
    try benchmarkQuantumOperations(testing.allocator);
}
