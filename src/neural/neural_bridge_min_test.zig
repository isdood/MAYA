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

// Mock implementations to avoid dependencies
pub const PatternMetrics = struct {
    pub const Pattern = struct {};
};

pub const PatternRecognition = struct {
    pub const Pattern = struct {};
};

pub const PatternSynthesis = struct {
    pub const SynthesisState = struct {};
};

pub const PatternTransformation = struct {
    pub const TransformationState = struct {};
};

pub const PatternVisualization = struct {
    pub const VisualizationState = struct {};
};

// Test bridge initialization with different configurations
test "neural bridge initialization" {
    const allocator = testing.allocator;
    
    // Test with all processors enabled
    {
        var bridge = try NeuralBridge.init(allocator, .{
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
        var bridge = try NeuralBridge.init(allocator, .{
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
        var bridge = try NeuralBridge.init(allocator, .{
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

// Test protocol management
test "protocol management" {
    const allocator = testing.allocator;
    var bridge = try NeuralBridge.init(allocator, .{});
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
        var bridge = try NeuralBridge.init(allocator, .{});
        defer bridge.deinit();
        
        try expectError(
            error.ProtocolNotActive,
            bridge.finishProtocol(.Sync, true, null)
        );
    }
}
