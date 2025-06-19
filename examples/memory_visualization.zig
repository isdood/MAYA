const std = @import("std");
const glimmer = @import("glimmer");

pub fn main() !void {
    // Initialize memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new memory graph
    var graph = glimmer.visualization.MemoryGraph.init(allocator);
    defer graph.deinit();
    
    // Set graph dimensions
    graph.width = 120;
    graph.height = 40;

    // Add memory nodes with different types and positions
    const user_node: u32 = 1;
    _ = try graph.addNode(.{
        .id = user_node,
        .content = "User: Alice",
        .memory_type = .UserDetail,
        .importance = 1.0,
        .x = 20.0,
        .y = 10.0,
    });

    const pref_nodes = try allocator.alloc(usize, 5);
    defer allocator.free(pref_nodes);
    
    // Add preference nodes in a circle around the user
    for (0..5, 0..) |i, idx| {
        const angle = std.math.pi * 2 * @as(f32, @floatFromInt(i)) / 5.0;
        const node_id = @as(u32, @intCast(i + 10));
        _ = try graph.addNode(.{
            .id = node_id,
            .content = switch (i) {
                0 => "Likes: Programming",
                1 => "Likes: AI/ML",
                2 => "Project: MAYA",
                3 => "Skill: Zig",
                else => "Skill: Rust",
            },
            .memory_type = .Preference,
            .importance = 0.7 + @as(f32, @floatFromInt(i)) * 0.05,
            .x = 20.0 + 15.0 * @cos(angle),
            .y = 10.0 + 8.0 * @sin(angle),
        });
        pref_nodes[idx] = node_id;
        
        // Connect preferences to user
        try graph.addEdge(.{
            .source = user_node,
            .target = node_id,
            .relationship = .RelatedTo,
            .strength = 0.7 + @as(f32, @floatFromInt(i)) * 0.05,
        });
    }

    // Add task nodes
    const task1: u32 = 20;
    _ = try graph.addNode(.{
        .id = task1,
        .content = "Task: Implement memory visualization",
        .memory_type = .Task,
        .importance = 0.9,
        .x = 60.0,
        .y = 10.0,
    });

    const task2: u32 = 21;
    _ = try graph.addNode(.{
        .id = task2,
        .content = "Task: Add interactive controls",
        .memory_type = .Task,
        .importance = 0.8,
        .x = 80.0,
        .y = 15.0,
    });

    // Connect tasks
    try graph.addEdge(.{
        .source = task1,
        .target = task2,
        .relationship = .ParentOf,
        .strength = 0.8,
    });

    // Connect tasks to relevant preferences
    try graph.addEdge(.{
        .source = pref_nodes[0],  // Programming
        .target = task1,
        .relationship = .RelatedTo,
        .strength = 0.9,
    });

    // Set up terminal for raw mode (non-blocking input)
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    
    // Main animation loop
    var frame: u32 = 0;
    while (true) {
        frame += 1;
        
        // Clear screen and move cursor to top-left
        try stdout.writeAll("\x1b[2J\x1b[H");
        
        // Update graph layout
        graph.updateLayout();
        
        // Add some animation to the nodes
        if (frame % 10 == 0) {
            if (graph.nodes.getPtr(task1)) |node| {
                node.x += 5.0 * @sin(@as(f32, @floatFromInt(frame)) * 0.1);
            }
        }
        
        // Render the graph
        try stdout.print("MAYA Memory Visualization (Frame: {})\n\n", .{frame});
        try graph.render(stdout);
        
        // Instructions
        try stdout.writeAll("\n\nPress 'q' to quit, 'r' to reset layout\n");
        
        // Non-blocking input check
        if (stdin.readByte() catch null) |char| {
            if (char == 'q') break;
            if (char == 'r') {
                // Reset node positions
                if (graph.nodes.getPtr(user_node)) |node| {
                    node.x = 20.0;
                    node.y = 10.0;
                }
                for (pref_nodes, 0..) |node_id, i| {
                    if (graph.nodes.getPtr(node_id)) |node| {
                        const angle = std.math.pi * 2 * @as(f32, @floatFromInt(i)) / 5.0;
                        node.x = 20.0 + 15.0 * @cos(angle);
                        node.y = 10.0 + 8.0 * @sin(angle);
                    }
                }
                if (graph.nodes.getPtr(task1)) |node| {
                    node.x = 60.0;
                    node.y = 10.0;
                }
                if (graph.nodes.getPtr(task2)) |node| {
                    node.x = 80.0;
                    node.y = 15.0;
                }
            }
        }
        
        // Small delay to control animation speed
        std.time.sleep(50 * std.time.ns_per_ms);
    }
}

// Add these test relationships to the MemoryRelationship enum for the example
const MemoryRelationship = enum {
    HasPreference,
    CreatedTask,
};
