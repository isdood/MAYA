const std = @import("std");
const neural = @import("../src/neural/mod.zig");

pub fn main() !void {
    // Initialize the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize the pattern synthesizer
    var synthesizer = try neural.pattern_synthesis.PatternSynthesizer.init(
        allocator,
        .{ .max_patterns = 10 },
    );
    defer synthesizer.deinit();
    
    // Create a simple input pattern
    const input_features = [_]f32{ 0.1, 0.2, 0.3, 0.4, 0.5 };
    
    // Synthesize a new pattern
    const pattern = try synthesizer.synthesize(
        &input_features,
        "test_pattern",
    );
    
    // Print the results
    std.debug.print("Synthesized Pattern: {s}\n", .{pattern.id});
    std.debug.print("  Features: {any}\n", .{pattern.features});
    std.debug.print("  Confidence: {d:.2}\n", .{pattern.confidence});
    std.debug.print("  Coherence: {d:.2}\n", .{pattern.coherence});
    std.debug.print("  Stability: {d:.2}\n", .{pattern.stability});
    std.debug.print("  Evolution: {d:.2}\n", .{pattern.evolution});
    
    // Clean up
    pattern.deinit(allocator);
    allocator.destroy(pattern);
}
