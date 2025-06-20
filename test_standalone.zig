@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 11:10:05",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./test_standalone.zig",
    "type": "zig",
    "hash": "e19be3fc56a994f76d65f3c150927ae717203b2a"
  }
}
@pattern_meta@

const std = @import("std");
const PatternEvolution = @import("./src/neural/pattern_evolution.zig").PatternEvolution;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize pattern evolution
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();
    
    // Simple test pattern
    const pattern = "test_pattern";
    
    // Evolve the pattern
    std.debug.print("Evolving pattern: {s}\n", .{pattern});
    const result = try evolution.evolve(pattern);
    
    // Print results
    std.debug.print("\nPattern Evolution Results:\n", .{});
    std.debug.print("  Original pattern: {s}\n", .{pattern});
    std.debug.print("  Evolved pattern ID: {s}\n", .{result.pattern_id});
    std.debug.print("  Fitness: {d:.2}\n", .{result.fitness});
    std.debug.print("  Generation: {}\n", .{result.generation});
    std.debug.print("  Diversity: {d:.2}\n", .{result.diversity});
    
    // Test error handling
    std.debug.print("\nTesting error handling with empty pattern...\n", .{});
    const err = evolution.evolve("");
    if (err) |_| {
        std.debug.print("  Error: Expected error.InvalidPatternData but got success\n", .{});
        return error.TestUnexpectedResult;
    } else |err_val| {
        std.debug.print("  Expected error: {}\n", .{err_val});
    }
}
