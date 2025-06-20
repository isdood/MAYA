
const std = @import("std");
const PatternEvolution = @import("../src/neural/pattern_evolution.zig").PatternEvolution;
const PatternVisualizer = @import("visualization").PatternVisualizer;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize pattern evolution and visualizer
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();
    
    var visualizer = PatternVisualizer.init(allocator);
    defer visualizer.deinit();
    
    // Run evolution for a few generations
    const num_generations = 20;
    
    std.debug.print("Starting pattern evolution...\n\n", .{});
    
    for (0..num_generations) |generation| {
        // Evolve the pattern
        _ = try evolution.evolve("initial_pattern");
        
        // Visualize the current state
        try visualizer.visualizeEvolution(&evolution);
        
        // Small delay to see the evolution
        std.time.sleep(100_000_000); // 100ms
        
        // Clear screen for next frame
        if (generation < num_generations - 1) {
            // Use ANSI escape code to clear screen and move cursor to top-left
            std.debug.print("\x1b[2J\x1b[H", .{});
        }
    }
    
    std.debug.print("\nPattern evolution complete!\n", .{});
}

// Test to ensure the example compiles
test "pattern visualization example compiles" {
    // This test just verifies that the example code compiles
    try std.testing.expect(true);
}
