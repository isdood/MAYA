const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectError = testing.expectError;

const NeuralBridge = @import("neural_bridge.zig").NeuralBridge;
const BridgeConfig = @import("neural_bridge.zig").BridgeConfig;
const ProtocolType = @import("neural_bridge.zig").ProtocolType;

// Mock implementations to avoid dependencies
pub const PatternMetrics = struct {
    pub const Pattern = struct {};
};

// Test bridge initialization with minimal configuration
test "minimal bridge initialization" {
    const allocator = testing.allocator;
    
    // Test with minimal configuration
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
    
    // Initialize with minimal configuration
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = false,
        .enable_visual = false,
        .enable_neural = false,
    });
    defer bridge.deinit();
    
    // Test starting a protocol
    const protocol = try bridge.startProtocol(.Sync);
    try expect(protocol.is_active);
    
    // Test finishing a protocol
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
    
    // Test with no processors enabled (should be fine with our changes)
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = false,
        .enable_visual = false,
        .enable_neural = false,
    });
    defer bridge.deinit();
    
    // Test protocol not active error
    try expectError(
        error.ProtocolNotActive,
        bridge.finishProtocol(.Sync, true, null)
    );
}
