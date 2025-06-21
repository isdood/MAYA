const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqAbs = testing.expectApproxEqAbs;
const math = std.math;
const Allocator = std.mem.Allocator;

// Import the crystal computing module
const crystal_computing = @import("crystal_computing.zig");
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
    var valid_state = CrystalState{
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
    const config = CrystalConfig{};
    const processor = try CrystalProcessor.init(allocator, config);
    defer processor.deinit();
    
    // Test with simple pattern
    const pattern = "test_pattern";
    var result = try processor.process(pattern);
    defer result.deinit(allocator);
    
    // Basic validation of results
    try expect(result.coherence >= 0.0 and result.coherence <= 1.0);
    try expect(result.entanglement >= 0.0 and result.entanglement <= 1.0);
    try expect(result.depth > 0);
    try expect(result.pattern_id.len > 0);
}

// Test CrystalProcessor with spectral analysis
test "CrystalProcessor spectral analysis" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const config = CrystalConfig{
        .enable_spectral_analysis = true,
        .enable_parallel_processing = false,
        .enable_caching = false,
    };
    
    const processor = try CrystalProcessor.init(allocator, config);
    defer processor.deinit();
    
    // Use a more complex pattern for better spectral analysis
    const pattern = "test_spectral_analysis_1234567890_!@#$%^&*()";
    var result = try processor.process(pattern);
    defer result.deinit(allocator);
    
    // Check if spectral analysis was performed and is valid
    try testing.expect(result.spectral != null);
    if (result.spectral) |spectral| {
        // Validate spectral entropy
        try testing.expect(spectral.spectral_entropy >= 0.0);
        try testing.expect(spectral.spectral_entropy <= 1.0);
        
        // Validate dominant frequency
        try testing.expect(spectral.dominant_frequency >= 0.0);
        
        // Validate harmonic energy
        if (spectral.harmonic_energy.len > 0) {
            for (spectral.harmonic_energy) |energy| {
                try testing.expect(energy >= 0.0);
            }
        }
    }
}

// Test CrystalProcessor with different pattern sizes
test "CrystalProcessor pattern size handling" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const config = CrystalConfig{};
    const processor = try CrystalProcessor.init(allocator, config);
    defer processor.deinit();
    
    // Test with various pattern sizes
    const test_patterns = [_][]const u8{
        "a",          // Single byte
        "abc",        // Small
        "abcdefghijklmnopqrstuvwxyz",  // Medium
    };
    
    for (test_patterns) |pattern| {
        var result = try processor.process(pattern);
        defer result.deinit(allocator);
        try expect(result.isValid());
    }
}

// Test performance with different pattern sizes
test "benchmark CrystalProcessor performance" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const config = CrystalConfig{};
    const processor = try CrystalProcessor.init(allocator, config);
    defer processor.deinit();
    
    // Test with various pattern sizes
    const pattern_sizes = [_]usize{ 1, 16, 64, 256, 1024, 4096 };
    
    std.debug.print("\nCrystalProcessor Performance Benchmarks\n", .{});
    std.debug.print("---------------------------------\n", .{});
    
    for (pattern_sizes) |pattern_size| {
        // Create test pattern
        const pattern = try allocator.alloc(u8, pattern_size);
        defer allocator.free(pattern);
        
        // Fill with test data
        for (pattern, 0..) |*byte, i| {
            byte.* = @as(u8, @intCast(i % 256));
        }
        
        // Warm up
        var warmup_result = try processor.process(pattern);
        defer warmup_result.deinit(allocator);
        
        // Benchmark
        const start_time = std.time.nanoTimestamp();
        const iterations = 100;
        
        for (0..iterations) |_| {
            var result = try processor.process(pattern);
            defer result.deinit(allocator);
            // Use result in a way that prevents optimization
            if (result.coherence < 0) unreachable;
        }
        
        const elapsed_ns = std.time.nanoTimestamp() - start_time;
        const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
        
        std.debug.print("Pattern size: {d:>6} bytes - {d:8.2} ns/op\n", .{
            pattern_size,
            ns_per_op,
        });
    }
    
    std.debug.print("\n", .{});
}
