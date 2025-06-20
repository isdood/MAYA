@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 08:41:20",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./examples/memory_visualization.zig",
    "type": "zig",
    "hash": "23aa1528644237f9000c568f4eccb9e07c8d5ba1"
  }
}
@pattern_meta@

const std = @import("std");
const glimmer = @import("glimmer");
const MemoryGraph = glimmer.visualization.MemoryGraph;
const MemoryNode = glimmer.visualization.MemoryNode;
const MemoryEdge = glimmer.visualization.MemoryEdge;
const MemoryType = glimmer.visualization.MemoryType;
const MemoryRelationship = glimmer.visualization.MemoryRelationship;
const InteractiveVisualizer = glimmer.interactive_visualizer.InteractiveVisualizer;

// ANSI color codes
const Color = struct {
    pub const Reset = "\x1b[0m";
    pub const Red = "\x1b[31m";
    pub const Green = "\x1b[32m";
    pub const Yellow = "\x1b[33m";
    pub const Blue = "\x1b[34m";
    pub const Magenta = "\x1b[35m";
    pub const Cyan = "\x1b[36m";
    pub const White = "\x1b[37m";
    pub const BrightRed = "\x1b[91m";
    pub const BrightGreen = "\x1b[92m";
    pub const BrightYellow = "\x1b[93m";
    pub const BrightBlue = "\x1b[94m";
    pub const BrightMagenta = "\x1b[95m";
    pub const BrightCyan = "\x1b[96m";
    pub const BrightWhite = "\x1b[97m";
};

pub fn main() !void {
    // Set up stdout with line buffering for better performance
    const stdout_file = std.io.getStdOut();
    const stdout_writer = stdout_file.writer();
    
    // Check if we're in a terminal that supports ANSI colors
    const is_tty = stdout_file.isTty();
    const supports_ansi = is_tty; // Simple check - assume TTY supports ANSI
    
    if (!supports_ansi) {
        try stdout_writer.writeAll("Warning: Terminal may not support ANSI colors. Visualization may not display correctly.\n");
    }
    
    // Initialize memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a new memory graph
    var graph = MemoryGraph.init(allocator);
    defer graph.deinit();
    
    // Set graph dimensions
    graph.width = 80;  // Smaller width for better compatibility
    graph.height = 20; // Smaller height for better compatibility

    // Create a simple graph with a few nodes and edges
    const nodes = [_]struct {
        id: u64,
        content: []const u8,
        mem_type: MemoryType,
        x: f32,
        y: f32,
    } {
        .{ .id = 1, .content = "Alice", .mem_type = .UserDetail, .x = 0.0, .y = 0.0 },
        .{ .id = 2, .content = "Likes: Programming", .mem_type = .Preference, .x = -10.0, .y = -5.0 },
        .{ .id = 3, .content = "Project: MAYA", .mem_type = .Project, .x = 10.0, .y = -5.0 },
        .{ .id = 4, .content = "Task: Memory Viz", .mem_type = .Task, .x = 0.0, .y = 10.0 },
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
    const edges = [_]struct { source: u64, target: u64, rel: MemoryRelationship } {
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

    // Set up terminal handling
    const stdin = std.io.getStdIn();
    
    // For now, we'll use a simple approach without raw mode
    // This means the user will need to press Enter after each command
    // We can enhance this later with platform-specific raw mode handling
    
    // Initialize interactive visualizer
    var visualizer = InteractiveVisualizer.init(allocator, &graph);
    
    // Hide cursor
    if (supports_ansi) {
        try stdout_writer.writeAll("\x1b[?25l");
    }
    
    // Main loop
    var frame: u64 = 0;
    var running = true;
    
    while (running) {
        // Update layout
        graph.updateLayout();
        
        // Clear screen and render
        if (supports_ansi) {
            try stdout_writer.writeAll("\x1b[2J\x1b[H");
        } else {
            // Simple newlines for terminals without ANSI support
            for (0..30) |_| {
                try stdout_writer.writeAll("\n");
            }
            try stdout_writer.writeAll("\x1b[H");
        }
        
        // Render the visualization
        try visualizer.render(stdout_writer);
        
        // Print frame counter
        try stdout_writer.print("Frame: {}\n", .{frame});
        
        // Check for input (blocking for now, will make non-blocking later)
        if (frame % 10 == 0) { // Only check for input every 10 frames
            var input_buf: [16]u8 = undefined;
            if (stdin.read(&input_buf) catch null) |bytes_read| {
                const input = input_buf[0..bytes_read];
                if (!visualizer.handleInput(input)) {
                    running = false; // Quit if handleInput returns false
                }
            }
        }
        
        // Small delay to control frame rate
        std.time.sleep(50 * std.time.ns_per_ms);
        frame += 1;
    }
    
    // Clean up
    if (supports_ansi) {
        try stdout_writer.writeAll("\x1b[?25h"); // Show cursor
        try stdout_writer.writeAll("\x1b[0m");   // Reset colors
        try stdout_writer.writeAll("\x1b[2J");   // Clear screen
        try stdout_writer.writeAll("\x1b[H");    // Move cursor to top-left
    }
}
