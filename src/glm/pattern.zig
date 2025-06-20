@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 11:20:18",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/glm/pattern.zig",
    "type": "zig",
    "hash": "299760e12ffaeba9344bb264bde5c826f2902105"
  }
}
@pattern_meta@

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

pub const PatternType = enum {
    Stellar,
    Quantum,
    Neural,
    Universal,
};

pub const PatternConfig = struct {
    pattern_type: PatternType = .Quantum,
    complexity: f32 = 1.0,
    brightness: f32 = 1.0,
    coherence: f32 = 1.0,
};

pub const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Pattern = struct {
    allocator: Allocator,
    vertices: std.ArrayList(Vertex),
    config: PatternConfig,
    
    pub fn init(allocator: Allocator, config: PatternConfig) !*Pattern {
        const self = try allocator.create(Pattern);
        self.* = .{
            .allocator = allocator,
            .vertices = std.ArrayList(Vertex).init(allocator),
            .config = config,
        };
        
        try self.generateVertices();
        return self;
    }
    
    pub fn deinit(self: *Pattern) void {
        self.vertices.deinit();
        self.allocator.destroy(self);
    }
    
    fn generateVertices(self: *Pattern) !void {
        const num_vertices = @floatToInt(usize, 100 * self.config.complexity);
        
        var prng = std.rand.DefaultPrng.init(@bitCast(u64, std.time.nanoTimestamp()));
        const rand = &prng.random();
        
        var i: usize = 0;
        while (i < num_vertices) : (i += 1) {
            const vertex = Vertex{
                .x = rand.float(f32) * 2 - 1,
                .y = rand.float(f32) * 2 - 1,
                .z = 0,
                .r = rand.float(f32) * self.config.brightness,
                .g = rand.float(f32) * self.config.brightness,
                .b = rand.float(f32) * self.config.brightness,
                .a = 1.0,
            };
            
            try self.vertices.append(vertex);
        }
    }
    
    pub fn toJson(self: *const Pattern, writer: anytype) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"type\": \"{}\",\n", .{@tagName(self.config.pattern_type)});
        try writer.print("  \"complexity\": {d},\n", .{self.config.complexity});
        try writer.print("  \"brightness\": {d},\n", .{self.config.brightness});
        try writer.print("  \"coherence\": {d},\n", .{self.config.coherence});
        try writer.writeAll("  \"vertices\": [\n");
        
        for (self.vertices.items, 0..) |vertex, i| {
            try writer.print("    {{\n", .{});
            try writer.print("      \"x\": {d},\n", .{vertex.x});
            try writer.print("      \"y\": {d},\n", .{vertex.y});
            try writer.print("      \"z\": {d},\n", .{vertex.z});
            try writer.print("      \"r\": {d},\n", .{vertex.r});
            try writer.print("      \"g\": {d},\n", .{vertex.g});
            try writer.print("      \"b\": {d},\n", .{vertex.b});
            try writer.print("      \"a\": {d}\n", .{vertex.a});
            
            if (i < self.vertices.items.len - 1) {
                try writer.writeAll("    },\n");
            } else {
                try writer.writeAll("    }\n");
            }
        }
        
        try writer.writeAll("  ]\n}");
    }
};

test "pattern initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const config = PatternConfig{
        .pattern_type = .Quantum,
        .complexity = 0.5,
    };
    
    var pattern = try Pattern.init(arena.allocator(), config);
    defer pattern.deinit();
    
    try std.testing.expect(pattern.vertices.items.len > 0);
}

test "pattern json serialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const config = PatternConfig{
        .pattern_type = .Quantum,
        .complexity = 0.1,
    };
    
    var pattern = try Pattern.init(arena.allocator(), config);
    defer pattern.deinit();
    
    var buffer = std.ArrayList(u8).init(arena.allocator());
    try pattern.toJson(buffer.writer());
    
    try std.testing.expect(buffer.items.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\"type\": \"Quantum\"") != null);
}
