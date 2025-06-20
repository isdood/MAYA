@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 11:07:31",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./examples/simple_pattern_evolution.zig",
    "type": "zig",
    "hash": "6dc19522dbb7020e67bc53d4209b8c8a5f7442c3"
  }
}
@pattern_meta@

const std = @import("std");
const PatternEvolution = @import("../src/neural/pattern_evolution.zig").PatternEvolution;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize pattern evolution
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();
    
    // Simple test pattern
    const pattern = "test_pattern";
    
    // Evolve the pattern
    const result = try evolution.evolve(pattern);
    
    // Print results
    std.debug.print("Pattern Evolution Results:\n", .{});
    std.debug.print("  Original pattern: {s}\n", .{pattern});
    std.debug.print("  Evolved pattern ID: {s}\n", .{result.pattern_id});
    std.debug.print("  Fitness: {d:.2}\n", .{result.fitness});
    std.debug.print("  Generation: {}\n", .{result.generation});
    std.debug.print("  Diversity: {d:.2}\n", .{result.diversity});
}
