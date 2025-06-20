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
