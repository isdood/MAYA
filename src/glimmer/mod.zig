@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 08:42:10",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/glimmer/mod.zig",
    "type": "zig",
    "hash": "d5f0d9840ac4ebce8227103acdc3c3d0a14ce37f"
  }
}
@pattern_meta@

//! ✨ GLIMMER: Visual Pattern Synthesis for MAYA
//! 
//! Provides visual pattern generation and memory visualization capabilities

pub const colors = @import("glimmer/colors.zig");
pub const patterns = @import("glimmer/patterns.zig");
pub const visualization = @import("glimmer/visualization.zig");
pub const interactive_visualizer = @import("glimmer/interactive_visualizer.zig");

// Re-export commonly used types for easier access
pub const MemoryNode = visualization.MemoryNode;
pub const MemoryEdge = visualization.MemoryEdge;
pub const MemoryGraph = visualization.MemoryGraph;
pub const MemoryType = visualization.MemoryType;
pub const MemoryRelationship = visualization.MemoryRelationship;
pub const InteractiveVisualizer = interactive_visualizer.InteractiveVisualizer;

/// Initialize the GLIMMER system
pub fn init(allocator: std.mem.Allocator) !void {
    _ = allocator;
    // Future initialization code will go here
}

/// Deinitialize the GLIMMER system
pub fn deinit() void {
    // Future cleanup code will go here
}

// Import standard library for re-export
const std = @import("std");

// Test module
const testing = std.testing;
test "GLIMMER module tests" {
    // Basic test to ensure the module compiles
    try testing.expect(true);
}
