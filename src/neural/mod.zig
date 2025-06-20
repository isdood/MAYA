//! Neural Network and Pattern Recognition Modules
//! Contains advanced neural processing capabilities for MAYA

// Common types
pub const VisualState = struct {
    brightness: f64 = 0.0,
    contrast: f64 = 1.0,
    saturation: f64 = 0.0,
};

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
