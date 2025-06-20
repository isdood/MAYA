const std = @import("std");
const neural = @import("neural");
const PatternRecognizer = neural.PatternRecognizer;
const Pattern = neural.Pattern;
const PatternFeedback = neural.PatternFeedback;

pub fn main() !void {
    // Initialize the allocator and pattern recognizer
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var recognizer = PatternRecognizer.init(allocator);
    defer recognizer.deinit();

    // Example usage
    try recognizer.analyzePatterns("Example pattern data");
    
    // Create a test pattern
    const test_pattern = try createTestPattern(allocator, "test1");
    defer test_pattern.deinit(allocator);
    
    std.debug.print("Pattern '{}' created with confidence: {d:.2}\n", 
        .{test_pattern.id, test_pattern.confidence});

    // Example of giving feedback
    const feedback = PatternFeedback{
        .pattern_id = "test1",
        .is_correct = true,
        .confidence_adjustment = 0.1,
    };
    
    try recognizer.adapt(feedback);
    std.debug.print("Pattern adaptation completed.\n", .{});
}

fn createTestPattern(allocator: std.mem.Allocator, id: []const u8) !Pattern {
    // Create sample features (just random values for demonstration)
    const features = try allocator.alloc(f32, 10);
    for (features) |*feature, i| {
        feature.* = @as(f32, @floatFromInt(i)) * 0.1;
    }
    
    return Pattern{
        .id = id,
        .features = features,
        .confidence = 0.8,
        .last_seen = std.time.timestamp(),
        .frequency = 1,
    };
}
