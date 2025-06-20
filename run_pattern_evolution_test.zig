const std = @import("std");
const testing = std.testing;

// Import our pattern evolution module
const PatternEvolution = @import("src/neural/pattern_evolution.zig").PatternEvolution;

test "pattern evolution basic functionality" {
    const allocator = testing.allocator;
    
    // Initialize pattern evolution
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();
    
    // Test evolution with a simple pattern
    const result = try evolution.evolve("test_pattern");
    
    // Verify basic properties
    try testing.expect(result.fitness >= 0.0 and result.fitness <= 1.0);
    try testing.expect(result.generation > 0);
    try testing.expect(result.pattern_id.len > 0);
}

test "pattern evolution error handling" {
    const allocator = testing.allocator;
    
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();
    
    // Test with empty pattern
    try testing.expectError(
        error.InvalidPatternData,
        evolution.evolve("")
    );
}

pub fn main() !void {
    std.log.info("Running pattern evolution tests...", .{});
    
    // Run tests programmatically
    const tests = @import("std").testing;
    const test_names = [_][]const u8{
        "pattern evolution basic functionality",
        "pattern evolution error handling",
    };
    
    for (test_names) |test_name| {
        std.log.info("Running test: {s}", .{test_name});
        try testing.testOneFn(@field(@This(), test_name));
    }
    
    std.log.info("All tests passed!", .{});
}
