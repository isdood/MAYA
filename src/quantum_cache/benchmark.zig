const std = @import("std");
const QuantumCache = @import("./quantum_cache.zig").QuantumCache;
const Pattern = @import("../neural/pattern.zig").Pattern;
const test_patterns = @import("./test_patterns.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    // Initialize cache with default options
    var cache = try QuantumCache.init(allocator, .{});
    defer cache.deinit();

    // Create test patterns
    const num_patterns = 100;
    const pattern_width = 64;
    const pattern_height = 64;
    
    try stdout.print("Generating {} test patterns...\n", .{num_patterns});
    
    // Generate test patterns
    var patterns = try allocator.alloc(*Pattern, num_patterns);
    defer {
        for (patterns) |p| {
            p.deinit();
            allocator.destroy(p);
        }
        allocator.free(patterns);
    }
    
    for (0..num_patterns) |i| {
        // Alternate between different pattern types
        patterns[i] = switch (i % 3) {
            0 => try test_patterns.createSimplePattern(allocator, try std.fmt.allocPrint(allocator, "simple_{}", .{i}), pattern_width, pattern_height),
            1 => try test_patterns.createRandomPattern(allocator, try std.fmt.allocPrint(allocator, "random_{}", .{i}), pattern_width, pattern_height),
            else => try test_patterns.createCheckerboardPattern(allocator, try std.fmt.allocPrint(allocator, "checker_{}", .{i}), pattern_width, pattern_height, 8),
        };
    }
    
    // Benchmark without cache
    try stdout.print("\nBenchmarking without cache...\n", .{});
    const start_no_cache = std.time.nanoTimestamp();
    
    for (patterns) |pattern| {
        // Simulate pattern processing - calculate average color
        var sum_r: u32 = 0;
        var sum_g: u32 = 0;
        var sum_b: u32 = 0;
        const data = pattern.data;
        
        for (0..pattern.height) |y| {
            for (0..pattern.width) |x| {
                const idx = (y * pattern.width + x) * 4;
                sum_r += data[idx];
                sum_g += data[idx + 1];
                sum_b += data[idx + 2];
            }
        }
        
        const total_pixels = pattern.width * pattern.height;
        const avg_r = @as(u8, @intCast(sum_r / total_pixels));
        const avg_g = @as(u8, @intCast(sum_g / total_pixels));
        const avg_b = @as(u8, @intCast(sum_b / total_pixels));
        
        _ = .{ avg_r, avg_g, avg_b }; // Prevent optimization
    }
    
    const end_no_cache = std.time.nanoTimestamp();
    const time_no_cache = @as(f64, @floatFromInt(end_no_cache - start_no_cache)) / 1_000_000.0;
    
    // Benchmark with cache
    try stdout.print("\nBenchmarking with QuantumCache...\n", .{});
    
    // Pre-shatter patterns into cache
    for (patterns) |pattern| {
        try cache.preShatter(pattern);
    }
    
    const start_with_cache = std.time.nanoTimestamp();
    
    for (patterns) |pattern| {
        if (cache.getShard(pattern.id)) |data| {
            // Simulate processing with cached data - calculate average color
            var sum_r: u32 = 0;
            var sum_g: u32 = 0;
            var sum_b: u32 = 0;
            
            for (0..pattern.height) |y| {
                for (0..pattern.width) |x| {
                    const idx = (y * pattern.width + x) * 4;
                    sum_r += data[idx];
                    sum_g += data[idx + 1];
                    sum_b += data[idx + 2];
                }
            }
            
            const total_pixels = pattern.width * pattern.height;
            const avg_r = @as(u8, @intCast(sum_r / total_pixels));
            const avg_g = @as(u8, @intCast(sum_g / total_pixels));
            const avg_b = @as(u8, @intCast(sum_b / total_pixels));
            
            _ = .{ avg_r, avg_g, avg_b }; // Prevent optimization
        }
    }
    
    const end_with_cache = std.time.nanoTimestamp();
    const time_with_cache = @as(f64, @floatFromInt(end_with_cache - start_with_cache)) / 1_000_000.0;
    
    // Print results
    try stdout.print("\nResults:\n", .{});
    try stdout.print("Without cache: {d:.2}ms\n", .{time_no_cache});
    try stdout.print("With QuantumCache: {d:.2}ms\n", .{time_with_cache});
    try stdout.print("Speedup: {d:.2}x\n", .{time_no_cache / time_with_cache});
    try stdout.print("Cache coherence: {d:.2}%\n", .{cache.coherence * 100});
}
