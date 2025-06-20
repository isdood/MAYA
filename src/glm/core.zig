@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 11:20:32",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/glm/core.zig",
    "type": "zig",
    "hash": "dfa09461606609398fc7d12688e6f46b56cf19c0"
  }
}
@pattern_meta@

const std = @import("std");
const Pattern = @import("pattern.zig").Pattern;
const PatternConfig = @import("pattern.zig").PatternConfig;

pub const GlimmerCore = struct {
    allocator: std.mem.Allocator,
    pattern_buffer: std.ArrayList(*Pattern),
    
    pub fn init(allocator: std.mem.Allocator) !*GlimmerCore {
        const self = try allocator.create(GlimmerCore);
        self.* = .{
            .allocator = allocator,
            .pattern_buffer = std.ArrayList(*Pattern).init(allocator),
        };
        return self;
    }
    
    pub fn deinit(self: *GlimmerCore) void {
        for (self.pattern_buffer.items) |pattern| {
            pattern.deinit();
        }
        self.pattern_buffer.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn generatePattern(self: *GlimmerCore, config: PatternConfig) !*Pattern {
        const pattern = try Pattern.init(self.allocator, config);
        try self.pattern_buffer.append(pattern);
        return pattern;
    }
    
    pub fn clearPatterns(self: *GlimmerCore) void {
        for (self.pattern_buffer.items) |pattern| {
            pattern.deinit();
        }
        self.pattern_buffer.clearRetainingCapacity();
    }
};

test "glimmer core initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var core = try GlimmerCore.init(arena.allocator());
    defer core.deinit();
    
    try std.testing.expect(core.pattern_buffer.items.len == 0);
}

test "pattern generation and cleanup" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var core = try GlimmerCore.init(arena.allocator());
    defer core.deinit();
    
    const config = PatternConfig{
        .pattern_type = .Quantum,
        .complexity = 0.5,
    };
    
    const pattern = try core.generatePattern(config);
    try std.testing.expect(core.pattern_buffer.items.len == 1);
    try std.testing.expect(core.pattern_buffer.items[0] == pattern);
    
    core.clearPatterns();
    try std.testing.expect(core.pattern_buffer.items.len == 0);
}
