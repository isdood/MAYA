//! Neural Network and Pattern Processing Modules
//! Contains advanced neural processing capabilities for MAYA

const std = @import("std");
const testing = std.testing;
const pattern = @import("pattern.zig");

// Core neural modules
pub const pattern_recognition = @import("pattern_recognition.zig");
pub const pattern_synthesis = @import("pattern_synthesis.zig");
pub const pattern_processor = @import("pattern_processor.zig");
pub const pattern_generator = @import("pattern_generator.zig");
pub const visual_synthesis = @import("visual_synthesis.zig");
pub const pattern_visualization = @import("pattern_visualization.zig");

// Export GPU options for other modules to use
pub const gpu_options = @import("build_options").gpu_options;

// Build options
pub const build_options = @import("build_options").options;

// Provide a dummy implementation for GPU evolution
pub const gpu_evolution = struct {
    pub const GPUEvolution = struct {
        pub fn init() @This() { return .{}; }
        pub fn deinit(self: *@This()) void { _ = self; }
    };
};

// Re-export common types and functions for convenience
pub const Pattern = @import("pattern.zig").Pattern;
pub const PatternType = @import("pattern.zig").PatternType;
pub const initGlobalPool = pattern.initGlobalPool;
pub const deinitGlobalPool = pattern.deinitGlobalPool;
pub const PatternFeedback = pattern_recognition.PatternFeedback;
pub const SynthesizedPattern = pattern_synthesis.SynthesizedPattern;
pub const PatternProcessor = pattern_processor.PatternProcessor;

// Core neural components
pub const VisualState = @import("visual_processor.zig").VisualState;
pub const VisualProcessor = @import("visual_processor.zig").VisualProcessor;

/// Bridge provides connectivity between neural components and the rest of the system.
pub const Bridge = struct {
    /// Connect to the neural bridge.
    pub fn connect() !void {
        // TODO: Implement actual bridge connection logic
        return;
    }
};
pub const QuantumProcessor = @import("quantum_processor.zig").QuantumProcessor;
pub const NeuralProcessor = @import("neural_processor.zig").NeuralProcessor;
pub const NeuralBridge = @import("neural_bridge.zig").NeuralBridge;

/// Initialize all neural components
pub fn init(allocator: std.mem.Allocator) !void {
    // Initialize pattern recognition
    try pattern_recognition.init(allocator);
    
    // Initialize pattern synthesis
    try pattern_synthesis.init(allocator);
    
    // Initialize pattern processor
    try pattern_processor.init(allocator);
}

/// Run all neural tests
pub fn runTests() !void {
    std.debug.print("\n=== Running Neural Module Tests ===\n", .{});
    
    // Run pattern recognition tests
    try pattern_recognition.runTests();
    
    // Run pattern synthesis tests
    try pattern_synthesis.runTests();
    
    // Run pattern processor tests
    try pattern_processor.runTests();
    
    std.debug.print("\n✅ All Neural Module Tests Passed!\n", .{});
}

// Test the neural module
test "neural module imports" {
    // Basic test to verify module imports
    try testing.expect(true);
}
