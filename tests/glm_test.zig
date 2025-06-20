@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 11:21:27",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./tests/glm_test.zig",
    "type": "zig",
    "hash": "072da7f02f9938cbcea9ed73c25a8d9631a5ce5d"
  }
}
@pattern_meta@

const std = @import("std");
const GlimmerCore = @import("../src/glm/core.zig").GlimmerCore;
const PatternConfig = @import("../src/glm/pattern.zig").PatternConfig;
const PatternType = @import("../src/glm/pattern.zig").PatternType;

test "glimmer core integration" {
    // Initialize test allocator
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Initialize GLIMMER core
    var core = try GlimmerCore.init(arena.allocator());
    
    // Test pattern generation
    const config = PatternConfig{
        .pattern_type = .Quantum,
        .complexity = 0.5,
    };
    
    const pattern = try core.generatePattern(config);
    try std.testing.expect(pattern.vertices.items.len > 0);
    
    // Test pattern clearing
    core.clearPatterns();
    try std.testing.expect(core.pattern_buffer.items.len == 0);
}

test "pattern validation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var core = try GlimmerCore.init(arena.allocator());
    
    // Test different pattern types
    const types = [_]PatternType{ .Stellar, .Quantum, .Neural, .Universal };
    
    for (types) |pattern_type| {
        const config = PatternConfig{
            .pattern_type = pattern_type,
            .complexity = 0.3,
        };
        
        const pattern = try core.generatePattern(config);
        try std.testing.expect(pattern.vertices.items.len > 0);
    }
    
    // Test complexity scaling
    const complexities = [_]f32{ 0.1, 0.5, 1.0 };
    var last_vertex_count: usize = 0;
    
    for (complexities) |complexity| {
        const config = PatternConfig{ .complexity = complexity };
        const pattern = try core.generatePattern(config);
        
        if (last_vertex_count > 0) {
            try std.testing.expect(pattern.vertices.items.len >= last_vertex_count);
        }
        
        last_vertex_count = pattern.vertices.items.len;
    }
}
