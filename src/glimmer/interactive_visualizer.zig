const std = @import("std");
const MemoryGraph = @import("visualization.zig").MemoryGraph;
const MemoryNode = @import("visualization.zig").MemoryNode;
const MemoryEdge = @import("visualization.zig").MemoryEdge;
const MemoryType = @import("visualization.zig").MemoryType;
const MemoryRelationship = @import("visualization.zig").MemoryRelationship;

/// Interactive visualizer for memory graphs with zoom, pan, and selection
pub const InteractiveVisualizer = struct {
    allocator: std.mem.Allocator,
    graph: *MemoryGraph,
    
    // View state
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    scale: f32 = 1.0,
    
    // Interaction state
    selected_node: ?u64 = null,
    is_panning: bool = false,
    last_mouse_x: i32 = 0,
    last_mouse_y: i32 = 0,
    
    // Callbacks
    on_node_selected: ?*const fn(node_id: ?u64, userdata: ?*anyopaque) void = null,
    userdata: ?*anyopaque = null,
    
    pub fn init(allocator: std.mem.Allocator, graph: *MemoryGraph) InteractiveVisualizer {
        return .{
            .allocator = allocator,
            .graph = graph,
        };
    }
    
    /// Handle user input
    pub fn handleInput(self: *InteractiveVisualizer, input: []const u8) bool {
        if (input.len == 0) return false;
        
        const key = input[0];
        
        // Handle arrow keys for panning
        if (input.len >= 3 and input[0] == '\x1b' and input[1] == '[') {
            switch (input[2]) {
                'A' => { self.offset_y -= 10.0 / self.scale; return true; }, // Up
                'B' => { self.offset_y += 10.0 / self.scale; return true; }, // Down
                'C' => { self.offset_x += 10.0 / self.scale; return true; }, // Right
                'D' => { self.offset_x -= 10.0 / self.scale; return true; }, // Left
                else => {},
            }
        }
        
        // Handle zoom in/out with +/-
        switch (key) {
            '+' => { 
                self.scale *= 1.2; 
                return true; 
            },
            '-' => { 
                self.scale = @max(0.1, self.scale / 1.2);
                return true; 
            },
            'r' => { 
                // Reset view
                self.offset_x = 0;
                self.offset_y = 0;
                self.scale = 1.0;
                return true;
            },
            'q' => {
                return false; // Signal to quit
            },
            else => {}
        }
        
        return false;
    }
    
    /// Transform screen coordinates to graph coordinates
    fn screenToGraph(self: *const InteractiveVisualizer, screen_x: f32, screen_y: f32) struct { x: f32, y: f32 } {
        return .{
            .x = (screen_x - @as(f32, @floatFromInt(self.graph.width)) / 2.0 - self.offset_x) / self.scale,
            .y = (screen_y - @as(f32, @floatFromInt(self.graph.height)) / 2.0 - self.offset_y) / self.scale,
        };
    }
    
    /// Check if a point is near a node
    fn getNodeAt(self: *InteractiveVisualizer, x: f32, y: f32) ?u64 {
        const graph_pos = self.screenToGraph(x, y);
        const node_radius = 2.0; // Radius to check around the point
        
        var it = self.graph.nodes.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr;
            const dx = node.x - graph_pos.x;
            const dy = node.y - graph_pos.y;
            const distance = std.math.sqrt(dx * dx + dy * dy);
            
            if (distance < node_radius) {
                return node.id;
            }
        }
        
        return null;
    }
    
    /// Render the graph with the current view transform
    pub fn render(self: *const InteractiveVisualizer, writer: anytype) !void {
        // Save current graph state
        const original_nodes = self.graph.nodes;
        
        // Apply view transform to a copy of the graph
        var transformed_graph = try self.graph.clone();
        defer transformed_graph.deinit();
        
        // Apply scale and offset to all nodes
        var it = transformed_graph.nodes.iterator();
        while (it.next()) |entry| {
            var node = entry.value_ptr;
            node.x = node.x * self.scale + self.offset_x + @as(f32, @floatFromInt(transformed_graph.width)) / 2.0;
            node.y = node.y * self.scale + self.offset_y + @as(f32, @floatFromInt(transformed_graph.height)) / 2.0;
        }
        
        // Render the transformed graph
        try transformed_graph.render(writer);
        
        // Draw UI overlay
        try writer.writeAll("\n");
        try writer.writeAll("Controls: [Arrows] Pan  [+/-] Zoom  [R] Reset  [Q] Quit\n");
        
        // Show selected node info
        if (self.selected_node) |node_id| {
            if (self.graph.nodes.get(node_id)) |node| {
                try writer.print("Selected: {s} (ID: {d}, Type: {s})\n", .{
                    node.content,
                    node.id,
                    @tagName(node.memory_type),
                });
            }
        }
    }
}
