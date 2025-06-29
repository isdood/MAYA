const std = @import("std");
const Allocator = std.mem.Allocator;

// Import our predictive vectoring system
const pvs = @import("quantum_cache/predictive_vectoring.zig");
const Pattern = pvs.Pattern;
const PredictiveVectoringSystem = pvs.PredictiveVectoringSystem;
const Image = @import("neural/pattern_matching.zig").Image;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize the predictive vectoring system
    var pv_system = try PredictiveVectoringSystem.init(allocator);
    defer pv_system.deinit();
    
    // Create a test pattern (a simple square)
    const pattern_size = 16;
    var pattern = try Pattern.init(allocator, "test_square", pattern_size, pattern_size);
    defer pattern.deinit();
    
    // Fill the pattern (a white square on black background)
    for (0..pattern_size) |y| {
        for (0..pattern_size) |x| {
            const val: f32 = if (x >= 4 and x < 12 and y >= 4 and y < 12) 1.0 else 0.0;
            pattern.setPixel(x, y, val);
        }
    }
    
    // Register the pattern with the system
    try pv_system.registerPattern("test_square", &pattern);
    
    // Create a test image with the pattern
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
    
    // Place the pattern in the image at a specific location
    const offset_x = 30;
    const offset_y = 50;
    for (0..pattern_size) |y| {
        for (0..pattern_size) |x| {
            const val = pattern.getPixel(x, y);
            image.setPixel(offset_x + x, offset_y + y, val);
        }
    }
    
    // Add some deterministic noise
    for (0..height) |y| {
        for (0..width) |x| {
            // Simple deterministic noise based on position
            const noise = 0.1 * @sin(@as(f32, @floatFromInt(x * 3 + y * 5)) * 0.5);
            const current = image.getPixel(x, y);
            image.setPixel(x, y, @max(0.0, @min(1.0, current + noise)));
        }
    }
    
    // Find patterns in the image
    std.debug.print("Searching for patterns in image...\n", .{});
    const matches = try pv_system.findPatterns(&image, 0.8); // Minimum score of 0.8
    defer matches.deinit();
    
    // Print the results
    std.debug.print("\nFound {} matches:\n", .{matches.items.len});
    for (matches.items) |match| {
        std.debug.print("  - Pattern: {s}\n", .{match.pattern_key});
        std.debug.print("    Position: ({}, {})\n", .{match.x, match.y});
        std.debug.print("    Scale: {d:.2}\n", .{match.scale});
        std.debug.print("    Score: {d:.4}\n", .{match.score});
        std.debug.print("    Coherence: {s}\n", .{@tagName(match.signature.coherence_state)});
    }
    
    // Expected position
    std.debug.print("\nExpected position: ({}, {})\n", .{offset_x, offset_y});
    
    if (matches.items.len > 0) {
        const match = matches.items[0];
        const dx = @as(i64, @intCast(match.x)) - @as(i64, @intCast(offset_x));
        const dy = @as(i64, @intCast(match.y)) - @as(i64, @intCast(offset_y));
        const position_error = @sqrt(@as(f64, @floatFromInt(dx*dx + dy*dy)));
        std.debug.print("Position error: {d:.2} pixels\n", .{position_error});
        
        if (position_error < 5.0) {
            std.debug.print("✅ Pattern found at the expected location!\n", .{});
        } else {
            std.debug.print("❌ Pattern not found at the expected location!\n", .{});
        }
    } else {
        std.debug.print("❌ No patterns found!\n", .{});
    }
}
