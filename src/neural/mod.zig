//! Neural Network and Pattern Recognition Modules
//! Contains advanced neural processing capabilities for MAYA

// Common types
export const VisualState = @import("visual_processor.zig").VisualState;

// Export processors
export const VisualProcessor = @import("visual_processor.zig").VisualProcessor;
export const QuantumProcessor = @import("quantum_processor.zig").QuantumProcessor;
export const NeuralProcessor = @import("neural_processor.zig").NeuralProcessor;

// Export pattern recognition functionality directly
pub usingnamespace @import("pattern_recognition/mod.zig");

// Re-export for backward compatibility
pub const pattern_recognition = @This();

// Test the neural module
const testing = @import("std").testing;

test "neural module imports" {
    // Just verify that the module compiles and imports correctly
    try testing.expect(true);
}
