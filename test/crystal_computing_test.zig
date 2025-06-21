const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqAbs = testing.expectApproxEqAbs;
const math = std.math;
const Allocator = std.mem.Allocator;

// Import the crystal computing module
const crystal_computing = @import("../src/neural/crystal_computing.zig");
const CrystalProcessor = crystal_computing.CrystalProcessor;
const CrystalConfig = crystal_computing.CrystalConfig;
const CrystalState = crystal_computing.CrystalState;

// Test CrystalConfig defaults
test "CrystalConfig defaults" {
    const config = CrystalConfig{};
    
    try expectEqual(@as(f64, 0.95), config.min_crystal_coherence);
    try expectEqual(@as(f64, 1.0), config.max_crystal_entanglement);
    try expectEqual(@as(usize, 8), config.crystal_depth);
    try expectEqual(@as(usize, 32), config.batch_size);
    try expectEqual(@as(u32, 500), config.timeout_ms);
    try expect(config.enable_spectral_analysis);
    try expect(config.enable_parallel_processing);
    try expect(config.enable_caching);
}

// Test CrystalState initialization and validation
test "CrystalState initialization" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Test valid state
    const valid_state = CrystalState{
        .coherence = 0.8,
        .entanglement = 0.6,
        .depth = 4,
        .pattern_id = try allocator.dupe(u8, "test_pattern"),
    };
    defer valid_state.deinit(allocator);
    
    try expect(valid_state.isValid());
    
    // Test invalid coherence
    var invalid_coherence = CrystalState{
        .coherence = 1.5,
        .entanglement = 0.5,
        .depth = 4,
        .pattern_id = try allocator.dupe(u8, "invalid_coherence"),
    };
    defer invalid_coherence.deinit(allocator);
    
    try expect(!invalid_coherence.isValid());
}

// Test CrystalProcessor initialization and basic processing
test "CrystalProcessor basic processing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Initialize with default config
    const processor = try CrystalProcessor.init(allocator, .{});
    defer processor.deinit();
    
    // Test with simple pattern
    const pattern = "test_pattern";
    const result = try processor.process(pattern);
    
    // Basic validation of results
    try expect(result.coherence >= 0.0 and result.coherence <= 1.0);
    try expect(result.entanglement >= 0.0 and result.entanglement <= 1.0);
    try expect(result.depth > 0);
    try expect(result.pattern_id.len > 0);
    
    // Clean up allocated memory
    result.deinit(allocator);
}

// Test CrystalProcessor with spectral analysis
test "CrystalProcessor spectral analysis" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Initialize with spectral analysis enabled
    var config = CrystalConfig{};
    config.enable_spectral_analysis = true;
    
    const processor = try CrystalProcessor.init(allocator, config);
    defer processor.deinit();
    
    const pattern = "test_spectral_analysis";
    const result = try processor.process(pattern);
    
    // Check if spectral analysis was performed
    try expect(result.spectral != null);
    if (result.spectral) |spectral| {
        try expect(spectral.spectral_entropy >= 0.0 and spectral.spectral_entropy <= 1.0);
    }
}

// Test CrystalProcessor caching
test "CrystalProcessor caching" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Initialize with caching enabled
    var config = CrystalConfig{};
    config.enable_caching = true;
    
    const processor = try CrystalProcessor.init(allocator, config);
    defer processor.deinit();
    
    const pattern = "test_caching";
    
    // First process (should miss cache)
    const result1 = try processor.process(pattern);
    defer result1.deinit(allocator);
    
    var initial_hits: usize = 0;
    var initial_misses: usize = 0;
    
    if (processor.stats) |stats| {
        initial_hits = stats.cache_hits.load(.Monotonic);
        initial_misses = stats.cache_misses.load(.Monotonic);
    }
    
    // Process same pattern again (should hit cache)
    const result2 = try processor.process(pattern);
    defer result2.deinit(allocator);
    
    // Verify cache hit
    if (processor.stats) |stats| {
        try expect(stats.cache_hits.load(.Monotonic) > initial_hits);
        try expect(stats.cache_misses.load(.Monotonic) == initial_misses);
    }
}

// Test CrystalProcessor with different pattern sizes
test "CrystalProcessor pattern size handling" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const processor = try CrystalProcessor.init(allocator, .{});
    defer processor.deinit();
    
    // Test with various pattern sizes
    const test_patterns = [_][]const u8{
        "",           // Empty
        "a",          // Single byte
        "abc",        // Small
        "abcdefghijklmnopqrstuvwxyz",  // Medium
    };
    
    for (test_patterns) |pattern| {
        const result = try processor.process(pattern);
        try expect(result.isValid());
    }
}

// Test CrystalProcessor with parallel processing
test "CrystalProcessor parallel processing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Initialize with parallel processing enabled
    var config = CrystalConfig{};
    config.enable_parallel_processing = true;
    config.batch_size = 1024; // Force parallel processing
    
    const processor = try CrystalProcessor.init(allocator, config);
    defer processor.deinit();
    
    // Create a large pattern
    const large_pattern = try allocator.alloc(u8, 4096);
    defer allocator.free(large_pattern);
    
    // Fill with test data
    for (large_pattern, 0..) |*byte, i| {
        byte.* = @as(u8, @intCast(i % 256));
    }
    
    const result = try processor.process(large_pattern);
    try expect(result.isValid());
}

// Test CrystalProcessor error handling
test "CrystalProcessor error handling" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const processor = try CrystalProcessor.init(allocator, .{});
    defer processor.deinit();
    
    // Test with empty pattern
    const result = processor.process("");
    try testing.expectError(error.InvalidPattern, result);
}

// Test performance with different pattern sizes
fn benchmarkCrystalProcessor(comptime pattern_size: usize) !void {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const processor = try CrystalProcessor.init(allocator, .{});
    defer processor.deinit();
    
    // Create test pattern
    const pattern = try allocator.alloc(u8, pattern_size);
    defer allocator.free(pattern);
    
    // Fill with test data
    for (pattern, 0..) |*byte, i| {
        byte.* = @as(u8, @intCast(i % 256));
    }
    
    // Warm up
    _ = try processor.process(pattern);
    
    // Benchmark
    const start_time = std.time.nanoTimestamp();
    const iterations = 100;
    
    for (0..iterations) |_| {
        _ = try processor.process(pattern);
    }
    
    const elapsed_ns = std.time.nanoTimestamp() - start_time;
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    
    std.debug.print("Pattern size: {d:>6} bytes - {d:8.2} ns/op\n", .{
        pattern_size,
        ns_per_op,
    });
}

test "benchmark CrystalProcessor performance" {
    // Test with various pattern sizes
    const pattern_sizes = [_]usize{ 1, 16, 64, 256, 1024, 4096, 16384 };
    
    std.debug.print("\nCrystalProcessor Performance Benchmarks\n", .{});
    std.debug.print("---------------------------------\n", .{});
    
    for (pattern_sizes) |size| {
        try benchmarkCrystalProcessor(size);
    }
    
    std.debug.print("\n", .{});
}
