
const std = @import("std");
const GlimmerCore = @import("glm/core.zig").GlimmerCore;
const PatternConfig = @import("glm/pattern.zig").PatternConfig;
const PatternType = @import("glm/pattern.zig").PatternType;
const StarweaveClient = @import("starweave/client.zig").StarweaveClient;

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize GLIMMER core
    var core = try GlimmerCore.init(allocator);
    defer core.deinit();

    // Generate a sample pattern
    const config = PatternConfig{
        .pattern_type = .Quantum,
        .complexity = 0.8,
        .brightness = 0.9,
        .coherence = 0.95,
    };

    const pattern = try core.generatePattern(config);
    defer pattern.deinit();

    // Print pattern info
    std.debug.print("✨ Generated GLIMMER pattern\n", .{});
    std.debug.print("Type: {s}\n", .{@tagName(config.pattern_type)});
    std.debug.print("Vertices: {d}\n", .{pattern.vertices.items.len});

    // Connect to STARWEAVE (simulated)
    std.debug.print("\n🔌 Connecting to STARWEAVE...\n", .{});
    
    var client = StarweaveClient.init(allocator);
    defer client.deinit();

    // In a real implementation, you would connect to the actual STARWEAVE server:
    // try client.connect("starweave.example.com", 4242);
    // try client.sendPattern(pattern);
    // const ack = try client.receiveAck();
    
    std.debug.print("✅ Pattern generation complete!\n", .{});
    
    // Example: Print first few vertices
    const max_vertices = @min(3, pattern.vertices.items.len);
    std.debug.print("\nSample vertices (first {d}):\n", .{max_vertices});
    
    for (pattern.vertices.items[0..max_vertices]) |vertex, i| {
        std.debug.print("  Vertex {}: x={d:.2}, y={d:.2}, z={d:.2}, color=({d:.2}, {d:.2}, {d:.2}, {d:.2})\n", 
            .{i, vertex.x, vertex.y, vertex.z, vertex.r, vertex.g, vertex.b, vertex.a});
    }
}

test "demo test" {
    // This is just a placeholder for the test runner
    try std.testing.expect(true);
}
