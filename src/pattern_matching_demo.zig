const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

// Import the pattern matching module
const pattern_matching = @import("neural/pattern_matching.zig");
const MultiScaleMatcher = pattern_matching.MultiScaleMatcher;
const Image = pattern_matching.Image;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a simple pattern (a small square)
    const pattern_size = 16;
    var pattern = try Image.init(allocator, pattern_size, pattern_size);
    defer pattern.deinit();
    
    // Fill pattern (a white square on black background)
    for (0..pattern_size) |y| {
        for (0..pattern_size) |x| {
            const val: f32 = if (x >= 4 and x < 12 and y >= 4 and y < 12) 1.0 else 0.0;
            pattern.setPixel(x, y, val);
        }
    }
    
    // Create a larger image with the pattern
    const width = 128;
    const height = 128;
    var image = try Image.init(allocator, width, height);
    defer image.deinit();
    
    // Initialize with zeros
    for (0..height) |y| {
        for (0..width) |x| {
            image.setPixel(x, y, 0.0);
        }
    }
    
    // Place pattern in the image at a specific location
    const offset_x = 30;
    const offset_y = 50;
    for (0..pattern_size) |y| {
        for (0..pattern_size) |x| {
            const val = pattern.getPixel(x, y);
            image.setPixel(offset_x + x, offset_y + y, val);
        }
    }
    
    // Add some deterministic noise to make it more realistic
    for (0..height) |y| {
        for (0..width) |x| {
            // Simple deterministic noise based on position
            const noise = 0.1 * @sin(@as(f32, @floatFromInt(x * 3 + y * 5)) * 0.5);
            const current = image.getPixel(x, y);
            image.setPixel(x, y, @max(0.0, @min(1.0, current + noise)));
        }
    }
    
    // Initialize the matcher
    var matcher = MultiScaleMatcher.init(allocator);
    defer matcher.deinit();
    
    // Find the pattern in the image
    std.debug.print("Searching for pattern in image...\n", .{});
    const result = try matcher.findBestMatch(image, pattern, null);
    
    // Print the results
    std.debug.print("\nPattern matching results:\n", .{});
    std.debug.print("  Found at: x={}, y={}\n", .{result.x, result.y});
    std.debug.print("  Scale: {d:.2}\n", .{result.scale});
    std.debug.print("  Score: {d:.4}\n", .{result.score});
    
    // The pattern matcher returns the top-left corner of the match
    const expected_x = offset_x;
    const expected_y = offset_y;
    
    // Calculate the position error
    const dx = @as(i64, @intCast(result.x)) - @as(i64, @intCast(expected_x));
    const dy = @as(i64, @intCast(result.y)) - @as(i64, @intCast(expected_y));
    const position_error = @sqrt(@as(f64, @floatFromInt(dx*dx + dy*dy)));
    
    std.debug.print("  Expected position: x={}, y={}\n", .{expected_x, expected_y});
    std.debug.print("  Position error: {d:.2} pixels\n", .{position_error});
    
    // Check if the pattern was found at the expected location within a small tolerance
    const tolerance = 5.0;
    if (position_error <= tolerance) {
        std.debug.print("✅ Pattern found at the expected location!\n", .{});
    } else {
        std.debug.print("❌ Pattern not found at the expected location!\n", .{});
    }
}
