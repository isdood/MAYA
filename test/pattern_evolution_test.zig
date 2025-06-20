const std = @import("std");
const testing = std.testing;
const PatternEvolution = @import("../src/neural/pattern_evolution.zig").PatternEvolution;

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

// Test error handling with invalid patterns
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
