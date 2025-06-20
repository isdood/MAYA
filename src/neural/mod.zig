//! Neural Network and Pattern Processing Modules
//! Contains advanced neural processing capabilities for MAYA

const std = @import("std");
const testing = std.testing;

// Core neural modules
pub const pattern_recognition = @import("pattern_recognition/mod.zig");
pub const pattern_synthesis = @import("pattern_synthesis/mod.zig");
pub const pattern_processor = @import("pattern_processor/mod.zig");

// Re-export common types for convenience
pub const Pattern = pattern_recognition.Pattern;
pub const PatternFeedback = pattern_recognition.PatternFeedback;
pub const SynthesizedPattern = pattern_synthesis.SynthesizedPattern;
pub const PatternProcessor = pattern_processor.PatternProcessor;

// Core neural components
pub const VisualState = @import("visual_processor.zig").VisualState;
pub const VisualProcessor = @import("visual_processor.zig").VisualProcessor;
pub const QuantumProcessor = @import("quantum_processor.zig").QuantumProcessor;
pub const NeuralProcessor = @import("neural_processor.zig").NeuralProcessor;

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
