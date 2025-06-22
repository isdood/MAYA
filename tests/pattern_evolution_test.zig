const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const PatternEvolution = @import("../src/neural/pattern_evolution.zig").PatternEvolution;
const PatternSynthesis = @import("../src/neural/pattern_synthesis.zig").PatternSynthesis;

// Simple fitness function for testing
fn testFitness(_: ?*anyopaque, data: []const u8) f64 {
    // Count the number of 1-bits as a simple fitness measure
    var count: usize = 0;
    for (data) |byte| {
        count += @popCount(byte);
    }
    return @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(data.len * 8));
}

test "pattern evolution basic functionality" {
    const allocator = testing.allocator;
    
    // Initialize pattern evolution
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();
    
    // Set up fitness function
    evolution.state.fitness_fn = testFitness;
    evolution.state.fitness_ctx = null;
    
    // Create initial pattern (all zeros)
    const pattern_len = 32;
    var pattern = try allocator.alloc(u8, pattern_len);
    defer allocator.free(pattern);
    @memset(pattern, 0);
    
    // Set initial best pattern
    evolution.current_best = try allocator.dupe(u8, pattern);
    
    // Run evolution for a few steps
    for (0..10) |_| {
        const metrics = try evolution.evolveStep();
        std.debug.print("Generation {}: fitness={d:.3}, diversity={d:.3}, convergence={d:.3}\n", .{
            evolution.state.generation,
            evolution.state.fitness,
            metrics.diversity,
            metrics.convergence,
        });
    }
    
    // Verify that fitness improved
    try testing.expect(evolution.state.fitness > 0.0);
}

test "quantum-enhanced pattern evolution" {
    const allocator = testing.allocator;
    
    // Initialize quantum-enhanced pattern evolution
    var evolution = try PatternEvolution.initWithType(allocator, .quantum_enhanced);
    defer evolution.deinit();
    
    // Set up fitness function
    evolution.state.fitness_fn = testFitness;
    evolution.state.fitness_ctx = null;
    
    // Create initial pattern (all zeros)
    const pattern_len = 32;
    var pattern = try allocator.alloc(u8, pattern_len);
    defer allocator.free(pattern);
    @memset(pattern, 0);
    
    // Set initial best pattern
    evolution.current_best = try allocator.dupe(u8, pattern);
    
    // Run evolution for a few steps
    for (0..5) |_| {
        const metrics = try evolution.evolveStep();
        std.debug.print("Quantum Generation {}: fitness={d:.3}, quantum_entanglement={d:.3}\n", .{
            evolution.state.generation,
            evolution.state.fitness,
            metrics.quantum_entanglement,
        });
    }
    
    // Verify that fitness improved
    try testing.expect(evolution.state.fitness > 0.0);
}

test "crystal computing pattern evolution" {
    const allocator = testing.allocator;
    
    // Initialize crystal computing pattern evolution
    var evolution = try PatternEvolution.initWithType(allocator, .crystal_computing);
    defer evolution.deinit();
    
    // Set up fitness function
    evolution.state.fitness_fn = testFitness;
    evolution.state.fitness_ctx = null;
    
    // Create initial pattern (all zeros)
    const pattern_len = 32;
    var pattern = try allocator.alloc(u8, pattern_len);
    defer allocator.free(pattern);
    @memset(pattern, 0);
    
    // Set initial best pattern
    evolution.current_best = try allocator.dupe(u8, pattern);
    
    // Run evolution for a few steps
    for (0..5) |_| {
        const metrics = try evolution.evolveStep();
        std.debug.print("Crystal Generation {}: fitness={d:.3}, crystal_coherence={d:.3}\n", .{
            evolution.state.generation,
            evolution.state.fitness,
            metrics.crystal_coherence,
        });
    }
    
    // Verify that fitness improved
    try testing.expect(evolution.state.fitness > 0.0);
}

// Main function to run benchmarks
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("Running Pattern Evolution Tests...\n", .{});
    
    // Run standard tests
    try testing.runTestFn(0, testing.allocator, testing.runner, .{});
    
    // Run benchmarks
    try stdout.print("\nRunning Benchmarks...\n", .{});
    
    const allocator = std.heap.page_allocator;
    
    // Benchmark standard evolution
    {
        var evolution = try PatternEvolution.init(allocator);
        defer evolution.deinit();
        
        const pattern_len = 64;
        var pattern = try allocator.alloc(u8, pattern_len);
        defer allocator.free(pattern);
        @memset(pattern, 0);
        
        evolution.state.fitness_fn = testFitness;
        evolution.current_best = try allocator.dupe(u8, pattern);
        
        const start_time = std.time.nanoTimestamp();
        const num_generations = 100;
        
        for (0..num_generations) |_| {
            _ = try evolution.evolveStep();
        }
        
        const end_time = std.time.nanoTimestamp();
        const avg_time = @as(f64, @floatFromInt(end_time - start_time)) / @as(f64, @floatFromInt(num_generations));
        
        try stdout.print("Standard Evolution: {d:.2} ns/generation\n", .{avg_time});
    }
    
    // Benchmark quantum-enhanced evolution
    {
        var evolution = try PatternEvolution.initWithType(allocator, .quantum_enhanced);
        defer evolution.deinit();
        
        const pattern_len = 64;
        var pattern = try allocator.alloc(u8, pattern_len);
        defer allocator.free(pattern);
        @memset(pattern, 0);
        
        evolution.state.fitness_fn = testFitness;
        evolution.current_best = try allocator.dupe(u8, pattern);
        
        const start_time = std.time.nanoTimestamp();
        const num_generations = 50; // Fewer generations due to higher complexity
        
        for (0..num_generations) |_| {
            _ = try evolution.evolveStep();
        }
        
        const end_time = std.time.nanoTimestamp();
        const avg_time = @as(f64, @floatFromInt(end_time - start_time)) / @as(f64, @floatFromInt(num_generations));
        
        try stdout.print("Quantum-Enhanced Evolution: {d:.2} ns/generation\n", .{avg_time});
    }
}
