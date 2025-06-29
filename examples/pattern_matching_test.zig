const std = @import("std");
const Allocator = std.mem.Allocator;
const Tensor4D = @import("../src/compute/tensor.zig").Tensor4D;
const VulkanContext = @import("../src/vulkan/context.zig").VulkanContext;
const VulkanPatternMatcher = @import("../src/vulkan/pattern_matching.zig").VulkanPatternMatcher;

pub fn main() !void {
    // Initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Vulkan context
    var vulkan_context = try VulkanContext.init(allocator);
    defer vulkan_context.deinit();

    // Initialize pattern matcher
    var matcher = try VulkanPatternMatcher.init(allocator, &vulkan_context);
    defer matcher.deinit();

    // Create a simple test image (32x32)
    const width: u32 = 32;
    const height: u32 = 32;
    var image = try Tensor4D(f32).init(allocator, .{ 1, 1, height, width });
    defer image.deinit();

    // Create a simple pattern (8x8)
    const pattern_width: u32 = 8;
    const pattern_height: u32 = 8;
    var pattern = try Tensor4D(f32).init(allocator, .{ 1, 1, pattern_height, pattern_width });
    defer pattern.deinit();

    // Fill the pattern with a simple shape (a white square on black background)
    for (0..pattern_height) |y| {
        for (0..pattern_width) |x| {
            const val: f32 = if (x >= 2 and x < 6 and y >= 2 and y < 6) 1.0 else 0.0;
            try pattern.set(.{ 0, 0, y, x }, val);
        }
    }

    // Place the pattern in the image at (10, 10)
    const pattern_x: u32 = 10;
    const pattern_y: u32 = 10;
    
    for (0..pattern_height) |dy| {
        for (0..pattern_width) |dx| {
            const val = (try pattern.get(.{ 0, 0, dy, dx }));
            try image.set(.{ 0, 0, pattern_y + dy, pattern_x + dx }, val);
        }
    }

    // Add some noise to the image
    var rng = std.rand.DefaultPrng.init(42);
    const rand = rng.random();
    
    for (0..height) |y| {
        for (0..width) |x| {
            const current = try image.get(.{ 0, 0, y, x });
            const noise = 0.1 * (rand.float(f32) - 0.5);
            try image.set(.{ 0, 0, y, x }, @max(0.0, @min(1.0, current + noise)));
        }
    }

    // Perform pattern matching
    const result = try matcher.match(image, pattern, 0.5, 2.0, 3);
    
    // Print results
    std.debug.print("Pattern matching results:\n", .{});
    std.debug.print("  Expected position: ({}, {})\n", .{ pattern_x, pattern_y });
    std.debug.print("  Found position:    ({}, {})\n", .{ result.x, result.y });
    std.debug.print("  Scale:             {d:.2}\n", .{result.scale});
    std.debug.print("  Score:             {d:.4}\n", .{result.score});
    
    // Simple validation
    const dx = @as(i32, @intCast(result.x)) - @as(i32, @intCast(pattern_x));
    const dy = @as(i32, @intCast(result.y)) - @as(i32, @intCast(pattern_y));
    const distance = std.math.sqrt(@as(f32, @floatFromInt(dx * dx + dy * dy)));
    
    if (distance > 2.0) {
        std.debug.print("Warning: Pattern not found at expected position\n", .{});
    } else {
        std.debug.print("Pattern found successfully!\n", .{});
    }
}
