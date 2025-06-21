const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const mocks = @import("neural_bridge_mocks.zig");

// Import the actual NeuralBridge implementation
const neural = @import("neural");
const NeuralBridge = neural.NeuralBridge;

// Test configuration
const TestConfig = struct {
    enable_quantum: bool = true,
    enable_visual: bool = true,
    enable_neural: bool = true,
    min_confidence: f64 = 0.8,
};

test "neural bridge initialization with mocks" {
    const allocator = testing.allocator;
    
    // Initialize with test configuration
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = true,
        .enable_visual = true,
        .enable_neural = true,
        .min_confidence = 0.8,
    });
    defer bridge.deinit();
    
    // Verify initialization
    try expect(bridge.config.enable_quantum == true);
    try expect(bridge.config.enable_visual == true);
    try expect(bridge.config.enable_neural == true);
    try expect(bridge.config.min_confidence == 0.8);
}

test "neural bridge protocol management" {
    const allocator = testing.allocator;
    
    // Initialize bridge
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = true,
        .enable_visual = true,
        .enable_neural = true,
    });
    defer bridge.deinit();
    
    // Test starting a protocol
    const protocol = try bridge.startProtocol(.Sync);
    try expect(protocol.is_active == true);
    
    // Test protocol state
    if (bridge.getProtocolState(.Sync)) |state| {
        try expect(state.is_active == true);
    } else {
        return error.ProtocolStateNotFound;
    }
    
    // Test finishing the protocol
    try bridge.finishProtocol(.Sync, true);
    
    // Verify protocol statistics
    if (bridge.getProtocolStats(.Sync)) |stats| {
        try expect(stats.success_rate() > 0.0);
        try expect(stats.total_executions == 1);
        try expect(stats.total_success == 1);
    } else {
        return error.ProtocolStatsNotFound;
    }
}

test "neural bridge error handling" {
    const allocator = testing.allocator;
    
    // Test invalid configuration
    try std.testing.expectError(
        error.InvalidConfidenceThreshold,
        NeuralBridge.init(allocator, .{
            .min_confidence = -0.1,
            .enable_quantum = true,
            .enable_visual = true,
            .enable_neural = true,
        })
    );
    
    // Initialize with valid configuration
    var bridge = try NeuralBridge.init(allocator, .{
        .enable_quantum = true,
        .enable_visual = true,
        .enable_neural = true,
    });
    defer bridge.deinit();
    
    // Test protocol not active error
    try std.testing.expectError(
        error.ProtocolNotActive,
        bridge.finishProtocol(.Sync, true)
    );
}

// Run all tests
pub fn main() !void {
    std.testing.refAllDecls(@This());
}
