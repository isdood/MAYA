//! Neural Network and Pattern Recognition Modules
//! Contains advanced neural processing capabilities for MAYA

pub const pattern_recognition = @import("neural/pattern_recognition/mod.zig");

// Re-export for easier access
pub const PatternRecognizer = pattern_recognition.PatternRecognizer;
pub const Pattern = pattern_recognition.Pattern;
pub const PatternFeedback = pattern_recognition.PatternFeedback;
pub const PatternEvolution = pattern_recognition.PatternEvolution;

// Test the neural module
const testing = @import("std").testing;

test "neural module imports" {
    // Just verify that the module compiles and imports correctly
    try testing.expect(true);
}
