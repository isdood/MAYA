@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 09:30:39",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/neural/pattern_recognition/test.zig",
    "type": "zig",
    "hash": "4c007f62a5c5f409ef38bb93cb7c60c60b993f07"
  }
}
@pattern_meta@

const std = @import("std");
const expect = std.testing.expect;
const PatternRecognizer = @import("./mod.zig").PatternRecognizer;
const Pattern = @import("./mod.zig").Pattern;

fn createTestPattern(allocator: std.mem.Allocator, id: []const u8, confidence: f32) !Pattern {
    const features = try allocator.alloc(f32, 3);
    @memcpy(features, &[_]f32{ 1.0, 2.0, 3.0 });
    
    return Pattern{
        .id = try allocator.dupe(u8, id),
        .features = features,
        .confidence = confidence,
        .last_seen = std.time.timestamp(),
        .frequency = 1,
    };
}

test "pattern recognition basic functionality" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var recognizer = PatternRecognizer.init(allocator);
    defer recognizer.deinit();
    
    // Test adding a pattern
    const pattern1 = try createTestPattern(allocator, "test1", 0.8);
    try recognizer.addPattern(pattern1);
    
    // Verify pattern was added
    try expect(recognizer.getPatternCount() == 1);
    
    // Test analyzing patterns
    try recognizer.analyzePatterns("test input");
    
    // Test getting predictions
    const predictions = try recognizer.predictNextPatterns(1);
    defer {
        for (predictions) |*p| p.deinit(allocator);
        allocator.free(predictions);
    }
    try expect(predictions.len > 0);
}

test "pattern evolution tracking" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var recognizer = PatternRecognizer.init(allocator);
    defer recognizer.deinit();
    
    // Add initial pattern
    const pattern = try createTestPattern(allocator, "evolving", 0.5);
    try recognizer.addPattern(pattern);
    
    // Analyze multiple times to trigger evolution
    for (0..3) |_| {
        try recognizer.analyzePatterns("test");
    }
    
    // Get evolution history
    const history = try recognizer.getEvolutionHistory(allocator);
    defer allocator.free(history);
    
    // Should have at least the initial creation and some updates
    const history_lines = std.mem.count(u8, history, "\n");
    try expect(history_lines >= 3);
}

test "pattern feedback adaptation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var recognizer = PatternRecognizer.init(allocator);
    defer recognizer.deinit();
    
    // Add a pattern
    const pattern = try createTestPattern(allocator, "feedback_test", 0.5);
    try recognizer.addPattern(pattern);
    
    // Provide feedback
    try recognizer.adaptFromFeedback(.{
        .pattern_id = "feedback_test",
        .confidence_adjustment = 0.2,
    });
    
    // Get predictions and verify confidence was adjusted
    const predictions = try recognizer.predictNextPatterns(1);
    defer {
        for (predictions) |*p| p.deinit(allocator);
        allocator.free(predictions);
    }
    
    try expect(predictions.len > 0);
    try expect(predictions[0].confidence >= 0.69); // 0.5 + 0.2 - epsilon for floating point
}
