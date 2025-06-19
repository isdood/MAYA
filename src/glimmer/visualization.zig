//! 🎨 GLIMMER Visualization Module
//! Provides visualization capabilities for MAYA's memory system

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

/// Represents a node in the memory graph
pub const MemoryNode = struct {
    id: u64,
    content: []const u8,
    memory_type: MemoryType,
    importance: f32,
    x: f32 = 0,
    y: f32 = 0,
    vx: f32 = 0, // velocity x
    vy: f32 = 0, // velocity y
};

/// Represents a relationship between memory nodes
pub const MemoryEdge = struct {
    source: u64,
    target: u64,
    relationship: MemoryRelationship,
    strength: f32 = 0.5,
};

/// The main graph structure for memory visualization
pub const MemoryGraph = struct {
    allocator: Allocator,
    nodes: std.AutoHashMap(u64, MemoryNode),
    edges: std.ArrayList(MemoryEdge),
    width: u32 = 100,  // Default width of the visualization
    height: u32 = 50,  // Default height of the visualization

    pub fn init(allocator: Allocator) MemoryGraph {
        return .{
            .allocator = allocator,
            .nodes = std.AutoHashMap(u64, MemoryNode).init(allocator),
            .edges = std.ArrayList(MemoryEdge).init(allocator),
        };
    }

    pub fn deinit(self: *MemoryGraph) void {
        self.nodes.deinit();
        self.edges.deinit();
    }

    /// Add a new memory node to the graph
    pub fn addNode(self: *MemoryGraph, node: MemoryNode) !void {
        try self.nodes.put(node.id, node);
    }

    /// Add a relationship between two memory nodes
    pub fn addEdge(self: *MemoryGraph, edge: MemoryEdge) !void {
        try self.edges.append(edge);
    }

    /// Update the graph layout using a force-directed algorithm
    pub fn updateLayout(self: *MemoryGraph) void {
        // Simple force-directed layout implementation
        // This is a placeholder - will be enhanced with a proper algorithm
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            // Simple random movement for now
            const node = entry.value_ptr;
            const rand_val = @as(f32, @floatFromInt(std.crypto.random.int(u8) % 3)) - 1.0;
            node.x += rand_val;
            node.y += rand_val;
            
            // Keep within bounds
            node.x = @max(0, @min(@as(f32, @floatFromInt(self.width)) - 1, node.x));
            node.y = @max(0, @min(@as(f32, @floatFromInt(self.height)) - 1, node.y));
        }
    }

    /// Render the graph to a string for terminal display
    pub fn render(self: *const MemoryGraph, writer: anytype) !void {
        // Create a 2D grid for rendering
        var grid = try std.ArrayList(std.ArrayList(u8)).initCapacity(self.allocator, self.height);
        defer {
            for (grid.items) |*row| row.deinit();
            grid.deinit();
        }

        // Initialize empty grid
        for (0..self.height) |_| {
            var row = try std.ArrayList(u8).initCapacity(self.allocator, self.width);
            try row.appendNTimes(' ', self.width);
            try grid.append(row);
        }

        // Draw edges first (so nodes appear on top)
        for (self.edges.items) |edge| {
            if (self.nodes.get(edge.source)) |source| {
                if (self.nodes.get(edge.target)) |target| {
                    // Simple line drawing with bounds checking
                    const x0 = @as(i32, @intFromFloat(source.x));
                    const y0 = @as(i32, @intFromFloat(source.y));
                    const x1 = @as(i32, @intFromFloat(target.x));
                    const y1 = @as(i32, @intFromFloat(target.y));
                    
                    // Simple DDA line drawing algorithm
                    const dx = @abs(x1 - x0);
                    const dy = @abs(y1 - y0);
                    const steps = @max(dx, dy);
                    
                    if (steps == 0) {
                        // Single point
                        if (x0 >= 0 and y0 >= 0 and 
                            x0 < self.width and y0 < self.height) {
                            grid.items[@intCast(y0)].items[@intCast(x0)] = '*';
                        }
                        continue;
                    }
                    
                    var x = @as(f32, @floatFromInt(x0));
                    var y = @as(f32, @floatFromInt(y0));
                    const x_inc = @as(f32, @floatFromInt(x1 - x0)) / @as(f32, @floatFromInt(steps));
                    const y_inc = @as(f32, @floatFromInt(y1 - y0)) / @as(f32, @floatFromInt(steps));
                    
                    for (0..steps + 1) |_| {
                        const xi = @as(i32, @intFromFloat(x));
                        const yi = @as(i32, @intFromFloat(y));
                        
                        if (xi >= 0 and yi >= 0 and 
                            xi < self.width and yi < self.height) {
                            grid.items[@intCast(yi)].items[@intCast(xi)] = '-';
                        }
                        
                        x += x_inc;
                        y += y_inc;
                    }
                }
            }
        }

        // Draw nodes
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr;
            const x = @as(u32, @intFromFloat(node.x));
            const y = @as(u32, @intFromFloat(node.y));
            
            if (x < self.width and y < self.height) {
                // Simple node representation (just the first character of the content)
                grid.items[y].items[x] = if (node.content.len > 0) node.content[0] else '*';
            }
        }

        // Render the grid
        for (grid.items) |row| {
            try writer.writeAll(row.items);
            try writer.writeAll("\n");
        }
    }
};

// Import memory types from the main maya-llm crate
pub const MemoryType = enum {
    Fact,
    Preference,
    Task,
    UserDetail,
    Custom,
};

pub const MemoryRelationship = enum {
    ParentOf,
    ChildOf,
    HappenedBefore,
    HappenedAfter,
    CausedBy,
    Caused,
    RelatedTo,
    SimilarTo,
    OppositeOf,
    PartOf,
    DependsOn,
    Custom,
};
