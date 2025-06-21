const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

const neural_bridge = @import("neural_bridge.zig");
const BridgeConfig = neural_bridge.BridgeConfig;
const NeuralBridge = neural_bridge.NeuralBridge;
const ProtocolType = neural_bridge.ProtocolType;
const PatternType = neural_bridge.PatternType;

// Helper function to create a test bridge instance
fn createTestBridge(allocator: std.mem.Allocator, config: BridgeConfig) !*NeuralBridge {
    return try NeuralBridge.init(allocator, config);
}

// Test bridge initialization with different configurations
test "neural bridge initialization" {
    const allocator = testing.allocator;
    
    // Test with all processors enabled
    {
        var bridge = try createTestBridge(allocator, .{
            .enable_quantum = true,
            .enable_visual = true,
            .enable_neural = true,
        });
        defer bridge.deinit();
        
        try expect(bridge.quantum_processor != null);
        try expect(bridge.visual_processor != null);
        try expect(bridge.thread_pool != null);
    }
    
    // Test with only quantum processing
    {
        var bridge = try createTestBridge(allocator, .{
            .enable_quantum = true,
            .enable_visual = false,
            .enable_neural = false,
        });
        defer bridge.deinit();
        
        try expect(bridge.quantum_processor != null);
        try expect(bridge.visual_processor == null);
        try expect(bridge.thread_pool == null);
    }
    
    // Test with only visual processing
    {
        var bridge = try createTestBridge(allocator, .{
            .enable_quantum = false,
            .enable_visual = true,
            .enable_neural = false,
        });
        defer bridge.deinit();
        
        try expect(bridge.quantum_processor == null);
        try expect(bridge.visual_processor != null);
        try expect(bridge.thread_pool == null);
    }
}

// Test pattern processing
test "pattern processing" {
    const allocator = testing.allocator;
    var bridge = try createTestBridge(allocator, .{});
    defer bridge.deinit();
    
    // Test quantum pattern processing
    try bridge.processPattern("quantum_data", .Quantum);
    try expect(bridge.state.quantum_state != null);
    
    // Test visual pattern processing
    try bridge.processPattern("visual_data", .Visual);
    try expect(bridge.state.visual_state != null);
    
    // Test neural pattern processing
    bridge.resetMetrics();
    try bridge.processPattern("neural_data", .Neural);
    try expect(bridge.state.sync_level > 0.8);
    
    // Test universal pattern processing
    bridge.resetMetrics();
    try bridge.processPattern("universal_data", .Universal);
    try expect(bridge.state.sync_level > 0.3);
    
    // Test error handling
    try expectError(
        error.QuantumProcessingNotEnabled,
        NeuralBridge.init(allocator, .{.enable_quantum = false}).processPattern("data", .Quantum)
    );
}

// Test protocol management
test "protocol management" {
    const allocator = testing.allocator;
    var bridge = try createTestBridge(allocator, .{});
    defer bridge.deinit();
    
    // Start a protocol
    const protocol = try bridge.startProtocol(.Sync);
    try expect(protocol.is_active);
    
    // Finish the protocol
    try bridge.finishProtocol(.Sync, true, null);
    const protocol_state = bridge.getProtocolState(.Sync) orelse return error.ProtocolStateNotFound;
    try expect(!protocol_state.is_active);
    
    // Check statistics
    const stats = bridge.getProtocolStats(.Sync) orelse return error.ProtocolStatsNotFound;
    try expect(stats.success_rate() == 1.0);
    try expect(stats.total_executions == 1);
    try expect(stats.total_success == 1);
    try expect(stats.total_errors == 0);
}

// Test concurrent pattern processing
test "concurrent pattern processing" {
    const allocator = testing.allocator;
    var bridge = try createTestBridge(allocator, .{
        .enable_neural = true, // Enable thread pool
        .batch_size = 4,
    });
    defer bridge.deinit();
    
    const test_count = 10;
    var threads: [test_count]std.Thread = undefined;
    
    // Start multiple processing threads
    for (0..test_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, struct {
            fn run(b: *NeuralBridge, idx: usize) !void {
                const pattern = try std.fmt.allocPrint(allocator, "test_pattern_{}", .{idx});
                defer allocator.free(pattern);
                
                // Process different pattern types in different threads
                const pattern_type = @as(PatternType, @enumFromInt(idx % @typeInfo(PatternType).Enum.fields.len));
                try b.processPattern(pattern, pattern_type);
                
                // Verify the pattern was processed
                try expect(b.state.success_count > 0);
            }
        }.run, .{bridge, i});
    }
    
    // Wait for all threads to complete
    for (threads) |thread| {
        thread.join();
    }
    
    // Verify all patterns were processed
    try expect(bridge.state.success_count >= test_count);
}

// Test error handling and edge cases
test "error handling and edge cases" {
    const allocator = testing.allocator;
    
    // Test invalid configuration
    try expectError(
        error.InvalidConfidenceThreshold,
        NeuralBridge.init(allocator, .{.min_confidence = -0.1})
    );
    
    // Test with no processors enabled
    try expectError(
        error.NoProcessorsEnabled,
        NeuralBridge.init(allocator, .{
            .enable_quantum = false,
            .enable_visual = false,
        })
    );
    
    // Test protocol not active error
    {
        var bridge = try createTestBridge(allocator, .{});
        defer bridge.deinit();
        
        try expectError(
            error.ProtocolNotActive,
            bridge.finishProtocol(.Sync, true, null)
        );
    }
}

// Test memory management
test "memory management" {
    const allocator = testing.allocator;
    
    // Test proper cleanup on deinit
    {
        var bridge = try createTestBridge(allocator, .{
            .enable_quantum = true,
            .enable_visual = true,
            .enable_neural = true,
        });
        
        // Process some patterns
        try bridge.processPattern("test1", .Quantum);
        try bridge.processPattern("test2", .Visual);
        
        // Start and finish a protocol
        _ = try bridge.startProtocol(.Sync);
        try bridge.finishProtocol(.Sync, true, null);
        
        // Deinit should clean up all resources
        bridge.deinit();
    }
    
    // Check for memory leaks using the testing allocator
    try expect(std.testing.allocator_instance.deinit() == .ok);
}

// Performance test for pattern processing
const PerfTestIterations = 100;

test "performance: pattern processing" {
    const allocator = testing.allocator;
    var bridge = try createTestBridge(allocator, .{
        .enable_neural = true,
        .batch_size = 32,
    });
    defer bridge.deinit();
    
    const start_time = std.time.nanoTimestamp();
    
    // Process multiple patterns to measure performance
    for (0..PerfTestIterations) |i| {
        const pattern = try std.fmt.allocPrint(allocator, "perf_test_{}", .{i});
        defer allocator.free(pattern);
        
        try bridge.processPattern(pattern, .Neural);
    }
    
    const elapsed_ns = std.time.nanoTimestamp() - start_time;
    const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(PerfTestIterations));
    
    std.debug.print("\nPerformance: {d:.2} ns/op for {d} iterations\n", .{
        ns_per_op,
        PerfTestIterations,
    });
    
    // Verify all patterns were processed
    try expect(bridge.state.success_count == PerfTestIterations);
}

// Main function to run all tests
pub fn main() !void {
    std.debug.print("\n=== Running Neural Bridge Tests ===\n", .{});
    
    // Run all tests in this file
    const tests = .{
        "neural bridge initialization",
        "pattern processing",
        "protocol management",
        "concurrent pattern processing",
        "error handling and edge cases",
        "memory management",
        "performance: pattern processing",
    };
    
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    inline for (tests) |test_name| {
        std.debug.print("Running test: {s}... ", .{test_name});
        try @field(@This(), test_name)();
        std.debug.print("PASS\n", .{});
    }
    
    std.debug.print("\nAll tests passed!\n", .{});
}
