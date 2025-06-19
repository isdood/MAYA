const std = @import("std");
const glimmer = @import("glimmer");
const MemoryGraph = glimmer.visualization.MemoryGraph;
const MemoryNode = glimmer.visualization.MemoryNode;
const MemoryEdge = glimmer.visualization.MemoryEdge;
const MemoryType = glimmer.visualization.MemoryType;
const MemoryRelationship = glimmer.visualization.MemoryRelationship;

pub fn main() !void {
    // Initialize memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new memory graph
    var graph = MemoryGraph.init(allocator);
    defer graph.deinit();
    
    // Set graph dimensions
    graph.width = 100;
    graph.height = 40;

    // Create a simple graph with a few nodes and edges
    const nodes = [_]struct {
        id: u32,
        content: []const u8,
        mem_type: MemoryType,
        x: f32,
        y: f32,
    } {
        .{ .id = 1, .content = "Alice", .mem_type = .UserDetail, .x = 20.0, .y = 10.0 },
        .{ .id = 2, .content = "Likes: Programming", .mem_type = .Preference, .x = 10.0, .y = 5.0 },
        .{ .id = 3, .content = "Project: MAYA", .mem_type = .Project, .x = 30.0, .y = 5.0 },
        .{ .id = 4, .content = "Task: Memory Viz", .mem_type = .Task, .x = 20.0, .y = 20.0 },
    };

    // Add nodes
    for (nodes) |node_data| {
        const node = MemoryNode{
            .id = node_data.id,
            .content = node_data.content,
            .memory_type = node_data.mem_type,
            .importance = 0.8,
            .x = node_data.x,
            .y = node_data.y,
            .vx = 0,
            .vy = 0,
        };
        try graph.nodes.put(node_data.id, node);
    }

    // Add edges
    const edges = [_]struct { source: u32, target: u32, rel: MemoryRelationship } {
        .{ .source = 1, .target = 2, .rel = .RelatedTo },
        .{ .source = 1, .target = 3, .rel = .RelatedTo },
        .{ .source = 1, .target = 4, .rel = .LeadsTo },
        .{ .source = 2, .target = 4, .rel = .Causes },
    };

    for (edges) |edge_data| {
        const edge = MemoryEdge{
            .source = edge_data.source,
            .target = edge_data.target,
            .relationship = edge_data.rel,
            .strength = 0.5,
        };
        try graph.edges.append(edge);
    }

    // Set up terminal for raw mode (non-blocking input)
    const stdout = std.io.getStdOut().writer();
    
    // Animation loop
    var frame: u32 = 0;
    while (true) {
        // Clear screen and move cursor to top-left
        try stdout.writeAll("\x1b[2J\x1b[H");
        
        // Update title and frame counter
        try std.fmt.format(stdout, "MAYA Memory Visualization (Frame: {})\n\n", .{frame});
        
        // Update node positions with force-directed layout
        graph.updateLayout();
        
        // Add some subtle animation
        if (frame % 20 == 0) {
            // Make a node move slightly
            if (graph.nodes.getPtr(4)) |node| { // Task node
                node.x += 0.5 * @sin(@as(f32, @floatFromInt(frame)) * 0.1);
            }
        }
        
        // Render the graph
        try graph.render(stdout);
        
        // Print simple controls
        try stdout.writeAll("\n\nPress 'q' to quit\n");
        
        // Check for user input
        frame += 1;
        std.time.sleep(50_000_000); // 50ms delay (20 FPS)
        
        // Non-blocking input check
        var buffer: [1]u8 = undefined;
        const read = std.io.getStdIn().read(&buffer) catch 0;
        if (read > 0 and buffer[0] == 'q') break;
    }
}
