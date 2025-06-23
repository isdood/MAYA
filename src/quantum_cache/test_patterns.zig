const std = @import("std");
const builtin = @import("builtin");
const neural = @import("neural");
const Pattern = neural.Pattern;

// Use the PatternType from neural module
const PatternType = neural.PatternType;

// Initialize random number generator
var rng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));

pub fn createSimplePattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    
    const pixel_count = width * height * 4; // RGBA
    var data = try allocator.alloc(u8, pixel_count);
    defer allocator.free(data); // Will be duplicated by Pattern.init
    
    // Simple gradient from top to bottom
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = (y * width + x) * 4;
            data[idx] = @as(u8, @intFromFloat(255.0 * (@as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(width)))));     // R
            data[idx + 1] = @as(u8, @intFromFloat(255.0 * (@as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(height)))));  // G
            data[idx + 2] = 128;  // B
            data[idx + 3] = 255;  // A
        }
    }
    
    const pattern = try Pattern.init(allocator, data, width, height);
    pattern.pattern_type = .Visual;
    pattern.complexity = 0.5;
    pattern.stability = 0.8;
    
    return pattern;
}

pub fn createRandomPattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    
    const pixel_count = width * height * 4; // RGBA
    var data = try allocator.alloc(u8, pixel_count);
    defer allocator.free(data); // Will be duplicated by Pattern.init
    
    // Fill with random noise
    for (0..pixel_count) |i| {
        data[i] = rng.random().int(u8);
    }
    
    const pattern = try Pattern.init(allocator, data, width, height);
    pattern.pattern_type = @intFromEnum(PatternType.Quantum);
    pattern.complexity = 0.9;
    pattern.stability = 0.1;
    
    return pattern;
}

pub fn createCheckerboardPattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize, tile_size: usize) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    
    const pixel_count = width * height * 4; // RGBA
    var data = try allocator.alloc(u8, pixel_count);
    defer allocator.free(data); // Will be duplicated by Pattern.init
    
    // Create checkerboard pattern
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = (y * width + x) * 4;
            const tile_x = x / tile_size;
            const tile_y = y / tile_size;
            const is_white = (tile_x + tile_y) % 2 == 0;
            const value: u8 = if (is_white) 255 else 0;
            
            data[idx] = value;     // R
            data[idx + 1] = value; // G
            data[idx + 2] = value; // B
            data[idx + 3] = 255;   // A
        }
    }
    
    const pattern = try Pattern.init(allocator, data, width, height);
    const local_pattern_type = PatternType;
    pattern.pattern_type = @intFromEnum(local_pattern_type.Hybrid);
    pattern.complexity = 0.7;
    pattern.stability = 0.6;
    
    return pattern;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize global pattern pool
    try neural.initGlobalPool(allocator);
    defer neural.deinitGlobalPool();
    
    std.debug.print("Generating test patterns...\n", .{});
    
    // Create and free each pattern type
    {
        std.debug.print("Creating simple gradient pattern...\n", .{});
        const pattern = try createSimplePattern(allocator, "gradient", 100, 100);
        defer pattern.deinit(allocator);
        std.debug.print("  - Created pattern: {}x{} ({} bytes)\n", .{pattern.width, pattern.height, pattern.data.len});
    }
    
    {
        std.debug.print("Creating random noise pattern...\n", .{});
        const pattern = try createRandomPattern(allocator, "random", 100, 100);
        defer pattern.deinit(allocator);
        std.debug.print("  - Created pattern: {}x{} ({} bytes)\n", .{pattern.width, pattern.height, pattern.data.len});
    }
    
    {
        std.debug.print("Creating checkerboard pattern...\n", .{});
        const pattern = try createCheckerboardPattern(allocator, "checker", 100, 100, 10);
        defer pattern.deinit(allocator);
        std.debug.print("  - Created pattern: {}x{} ({} bytes)\n", .{pattern.width, pattern.height, pattern.data.len});
    }
    
    std.debug.print("All test patterns generated successfully!\n", .{});
}
