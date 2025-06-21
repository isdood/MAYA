const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

// Mock implementations to avoid dependencies
pub const PatternMetrics = struct {
    pub const Pattern = struct {
        data: []const u8,
    };
    
    pub fn calculateComplexity(_: *@This(), _: Pattern) !f64 { return 0.5; }
    pub fn calculateStability(_: *@This(), _: Pattern) !f64 { return 0.8; }
    pub fn calculateCoherence(_: *@This(), _: Pattern) !f64 { return 0.7; }
};

pub const PatternRecognition = struct {
    pub const Pattern = struct {
        data: []const u8,
    };
    
    pub fn recognize(_: *@This(), _: []const u8) !Pattern { 
        return Pattern{ .data = "test" };
    }
};

pub const PatternSynthesis = struct {
    pub const SynthesisState = struct {
        progress: f64 = 0.0,
    };
    
    pub fn init(_: std.mem.Allocator) !*@This() {
        return @This();
    }
    
    pub fn deinit(_: *@This()) void {}
};

// Import the actual neural bridge with our mocks in scope
const NeuralBridge = @import("src/neural/neural_bridge.zig").NeuralBridge;
const BridgeConfig = @import("src/neural/neural_bridge.zig").BridgeConfig;
const ProtocolType = @import("src/neural/neural_bridge.zig").ProtocolType;

// Test initialization
test "neural bridge initialization" {
    const allocator = testing.allocator;
    
    // Test with all processors disabled (minimal config)
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = false,
        .enable_visual = false,
        .enable_neural = false,
    });
    defer bridge.deinit();
    
    try expect(bridge.quantum_processor == null);
    try expect(bridge.visual_processor == null);
    try expect(bridge.thread_pool == null);
}

// Test protocol management
test "protocol management" {
    const allocator = testing.allocator;
    
    // Initialize bridge with minimal configuration
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = false,
        .enable_visual = false,
        .enable_neural = false,
    });
    defer bridge.deinit();
    
    // Test starting a protocol
    const protocol = try bridge.startProtocol(.Sync);
    try expect(protocol.is_active);
    
    // Test finishing the protocol
    try bridge.finishProtocol(.Sync, true, null);
    
    // Verify protocol state
    const protocol_state = bridge.getProtocolState(.Sync) orelse return error.ProtocolStateNotFound;
    try expect(!protocol_state.is_active);
    
    // Verify protocol statistics
    const stats = bridge.getProtocolStats(.Sync) orelse return error.ProtocolStatsNotFound;
    try expect(stats.success_rate() == 1.0);
    try expect(stats.total_executions == 1);
    try expect(stats.total_success == 1);
    try expect(stats.total_errors == 0);
}

// Test error handling
test "error handling" {
    const allocator = testing.allocator;
    
    // Test invalid configuration
    try expectError(
        error.InvalidConfidenceThreshold,
        NeuralBridge.init(allocator, .{
            .min_confidence = -0.1,
            .enable_quantum = false,
            .enable_visual = false,
            .enable_neural = false,
        })
    );
    
    // Test protocol not active error
    {
        var bridge = try NeuralBridge.init(allocator, .{
            .enable_quantum = false,
            .enable_visual = false,
            .enable_neural = false,
        });
        defer bridge.deinit();
        
        try expectError(
            error.ProtocolNotActive,
            bridge.finishProtocol(.Sync, true, null)
        );
    }
}

// Test pattern processing
test "pattern processing" {
    const allocator = testing.allocator;
    
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = false,
        .enable_visual = false,
        .enable_neural = false,
    });
    defer bridge.deinit();
    
    // Start a protocol
    _ = try bridge.startProtocol(.Sync);
    
    // Process a pattern
    const result = try bridge.processPattern("test", .{ .data = "test" });
    
    // Basic validation of the result
    try expect(result.success);
    try expect(result.confidence >= 0.0);
    try expect(result.confidence <= 1.0);
    
    // Finish the protocol
    try bridge.finishProtocol(.Sync, true, null);
}

// Test memory management
test "memory management" {
    const allocator = testing.allocator;
    
    // Test initialization and deinitialization
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = false,
        .enable_visual = false,
        .enable_neural = false,
    });
    bridge.deinit();
    
    // Test with pattern processing
    {
        var bridge2 = try NeuralBridge.init(allocator, .{
            .enable_quantum = false,
            .enable_visual = false,
            .enable_neural = false,
        });
        _ = try bridge2.startProtocol(.Sync);
        _ = try bridge2.processPattern("test", .{ .data = "test" });
        try bridge2.finishProtocol(.Sync, true, null);
        bridge2.deinit();
    }
}
