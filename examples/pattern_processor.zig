const std = @import("std");
const neural = @import("../src/neural/mod.zig");

pub fn main() !void {
    // Initialize the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize the pattern processor
    var processor = try neural.PatternProcessor.init(
        allocator,
        .{ .max_patterns = 10 },
    );
    defer processor.deinit();
    
    // Process some input patterns
    const patterns = [_]struct { id: []const u8, features: []const f32 }{
        .{ .id = "pattern_1", .features = &[_]f32{ 0.1, 0.2, 0.3 } },
        .{ .id = "pattern_2", .features = &[_]f32{ 0.4, 0.5, 0.6 } },
        .{ .id = "pattern_3", .features = &[_]f32{ 0.7, 0.8, 0.9 } },
    };
    
    // Process each pattern
    for (patterns) |p| {
        const pattern = try processor.process(p.features, p.id);
        std.debug.print("Processed pattern: {s}\n", .{pattern.id});
        std.debug.print("  Features: {any}\n", .{pattern.features});
        std.debug.print("  Confidence: {d:.2}\n", .{pattern.confidence});
    }
    
    // List all processed patterns
    std.debug.print("\nAll processed patterns ({}):\n", .{processor.getPatternCount()});
    for (processor.getAllPatterns()) |p| {
        std.debug.print("- {s} (confidence: {d:.2})\n", .{ p.id, p.confidence });
    }
}
