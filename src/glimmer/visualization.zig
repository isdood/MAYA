//! 🎨 GLIMMER Visualization Module
//! Provides visualization capabilities for MAYA's memory system

const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

// ANSI color codes for terminal output
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

// Unicode box drawing characters
const Box = struct {
    pub const Horizontal = '─';
    pub const Vertical = '│';
    pub const TopLeft = '┌';
    pub const TopRight = '┐';
    pub const BottomLeft = '└';
    pub const BottomRight = '┘';
    pub const Cross = '┼';
    pub const VerticalRight = '├';
    pub const VerticalLeft = '┤';
    pub const HorizontalDown = '┬';
    pub const HorizontalUp = '┴';
};

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
    // Get the color for a memory type
    fn getMemoryTypeColor(self: *const MemoryGraph, mem_type: MemoryType) []const u8 {
        return switch (mem_type) {
            .Fact => Color.BrightCyan,
            .Preference => Color.BrightGreen,
            .Task => Color.BrightYellow,
            .UserDetail => Color.BrightMagenta,
            .Experience => Color.BrightBlue,
            .Goal => Color.BrightRed,
            .Idea => Color.BrightWhite,
            .Project => Color.BrightBlue,
            .Relationship => Color.BrightMagenta,
            .Event => Color.BrightYellow,
            .Knowledge => Color.BrightCyan,
            .Skill => Color.BrightGreen,
            else => Color.White,
        };
    }

    // Get the symbol for a memory type
    fn getMemoryTypeSymbol(self: *const MemoryGraph, mem_type: MemoryType) u21 {
        return switch (mem_type) {
            .Fact => '■',
            .Preference => '♥',
            .Task => '✓',
            .UserDetail => '☺',
            .Experience => '★',
            .Goal => '⚑',
            .Idea => '💡',
            .Project => '📁',
            .Relationship => '↔',
            .Event => '⌛',
            .Knowledge => '📚',
            .Skill => '⚡',
            else => '•',
        };
    }

    pub fn render(self: *const MemoryGraph, writer: anytype) !void {
        // Create a 2D grid for rendering with color support
        const Cell = struct { char: u21 = ' ', fg: ?[]const u8 = null };
        var grid = try std.ArrayList(std.ArrayList(Cell)).initCapacity(self.allocator, self.height);
        defer {
            for (grid.items) |*row| row.deinit();
            grid.deinit();
        }

        // Initialize empty grid
        for (0..self.height) |_| {
            var row = try std.ArrayList(Cell).initCapacity(self.allocator, self.width);
            for (0..self.width) |_| {
                try row.append(Cell{ .char = ' ' });
            }
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
                    
                    // Choose line style based on relationship type
                    const line_char: u21 = switch (edge.relationship) {
                        .RelatedTo => Box.Horizontal,
                        .ParentOf => '─',
                        .ChildOf => '─',
                        .SimilarTo => '~',
                        .LeadsTo => '→',
                        .DependsOn => '⟶',
                        .PartOf => '⊂',
                        .HasPart => '⊃',
                        .Causes => '⇒',
                        .CausedBy => '⇐',
                        .OccurredBefore => '⟲',
                        .OccurredAfter => '⟳',
                        else => '─',
                    };

                    for (0..steps + 1) |i| {
                        const xi = @as(i32, @intFromFloat(x));
                        const yi = @as(i32, @intFromFloat(y));
                        
                        if (xi >= 0 and yi >= 0 and 
                            xi < self.width and yi < self.height) {
                            // Only draw line if the cell is empty or already has a line character
                            const cell = &grid.items[@intCast(yi)].items[@intCast(xi)];
                            if (cell.char == ' ' or cell.char == line_char or 
                                cell.char == Box.Horizontal or cell.char == '~' or 
                                cell.char == '→' or cell.char == '⟶' or 
                                cell.char == '⊂' or cell.char == '⊃' or
                                cell.char == '⇒' or cell.char == '⇐' or
                                cell.char == '⟲' or cell.char == '⟳') {
                                cell.char = line_char;
                                cell.fg = Color.White; // Default line color
                            }
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
                const cell = &grid.items[y].items[x];
                cell.char = self.getMemoryTypeSymbol(node.memory_type);
                cell.fg = self.getMemoryTypeColor(node.memory_type);
                
                // Add label if there's space
                if (x + 1 < self.width and node.content.len > 0) {
                    const label = node.content;
                    const max_len = @min(self.width - x - 1, label.len);
                    for (label[0..max_len], 0..) |char, i| {
                        if (x + 1 + i < self.width) {
                            grid.items[y].items[x + 1 + i] = .{
                                .char = char,
                                .fg = self.getMemoryTypeColor(node.memory_type),
                            };
                        }
                    }
                }
            }
        }

        // Output the grid with colors
        for (grid.items) |row| {
            var current_fg: ?[]const u8 = null;
            
            for (row.items) |cell| {
                // Only change color if needed
                if (current_fg != cell.fg) {
                    if (cell.fg) |fg| {
                        try writer.writeAll(fg);
                    } else {
                        try writer.writeAll(Color.Reset);
                    }
                    current_fg = cell.fg;
                }
                
                // Write the character
                var utf8_buf: [4]u8 = undefined;
                const utf8_len = std.unicode.utf8Encode(cell.char, &utf8_buf) catch 0;
                try writer.writeAll(utf8_buf[0..utf8_len]);
            }
            
            // Reset color at the end of the line
            if (current_fg != null) {
                try writer.writeAll(Color.Reset);
            }
            try writer.writeByte('\n');
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
