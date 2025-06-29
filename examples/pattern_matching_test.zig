const std = @import("std");
const Allocator = std.mem.Allocator;
const crypto = std.crypto;
const Tensor4D = @import("vulkan_compute_tensor").Tensor4D;
const VulkanContext = @import("vulkan_context").VulkanContext;
const VulkanPatternMatcher = @import("vulkan_pattern_matching").VulkanPatternMatcher;

pub fn main() !void {
    std.debug.print("Starting pattern matching test...\n", .{});
    // Initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Vulkan context
    std.debug.print("Initializing Vulkan context...\n", .{});
    var vulkan_context = try VulkanContext.init(allocator);
    errdefer {
        std.debug.print("Error initializing Vulkan context, cleaning up...\n", .{});
        vulkan_context.deinit();
    }

    // Initialize pattern matcher
    std.debug.print("Initializing pattern matcher...\n", .{});
    var matcher = try VulkanPatternMatcher.init(allocator, &vulkan_context);
    errdefer {
        std.debug.print("Error initializing pattern matcher, cleaning up...\n", .{});
        matcher.deinit();
    }

    // Create a simple test image (32x32)
    const width: u32 = 32;
    const height: u32 = 32;
    std.debug.print("Creating test image ({}x{})...\n", .{width, height});
    var image = try Tensor4D(f32).initUninitialized(&vulkan_context, .{ 1, 1, height, width }, allocator);
    errdefer {
        std.debug.print("Error creating test image, cleaning up...\n", .{});
        image.deinit();
    }

    // Create a simple pattern (8x8)
    const pattern_width: u32 = 8;
    const pattern_height: u32 = 8;
    std.debug.print("Creating pattern ({}x{})...\n", .{pattern_width, pattern_height});
    var pattern = try Tensor4D(f32).initUninitialized(&vulkan_context, .{ 1, 1, pattern_height, pattern_width }, allocator);
    errdefer {
        std.debug.print("Error creating pattern, cleaning up...\n", .{});
        pattern.deinit();
    }

    // Fill the pattern with a simple shape (a white square on black background)
    var pat_y: u32 = 0;
    while (pat_y < pattern_height) : (pat_y += 1) {
        var pat_x: u32 = 0;
        while (pat_x < pattern_width) : (pat_x += 1) {
            const val: f32 = if (pat_x >= 2 and pat_x < 6 and pat_y >= 2 and pat_y < 6) 1.0 else 0.0;
            try pattern.set(.{ 0, 0, pat_y, pat_x }, val);
        }
    }

    // Place the pattern in the image at (10, 10)
    const pattern_x: u32 = 10;
    const pattern_y: u32 = 10;
    
    var ddy: u32 = 0;
    while (ddy < pattern_height) : (ddy += 1) {
        var ddx: u32 = 0;
        while (ddx < pattern_width) : (ddx += 1) {
            const val = (try pattern.get(.{ 0, 0, ddy, ddx }));
            try image.set(.{ 0, 0, pattern_y + ddy, pattern_x + ddx }, val);
        }
    }

    // Add some noise to the image
    var img_y: u32 = 0;
    while (img_y < height) : (img_y += 1) {
        var img_x: u32 = 0;
        while (img_x < width) : (img_x += 1) {
            const current = try image.get(.{ 0, 0, img_y, img_x });
            // Use crypto.random for a random float between -0.5 and 0.5
            const rand_val = @as(f32, @floatFromInt(crypto.random.int(u16))) / 65535.0 - 0.5;
            const noise = 0.1 * rand_val;
            try image.set(.{ 0, 0, img_y, img_x }, @max(0.0, @min(1.0, current + noise)));
        }
    }

    // Perform pattern matching
    std.debug.print("Starting pattern matching...\n", .{});
    const result = try matcher.match(image, pattern, 0.5, 2.0, 3);
    std.debug.print("Pattern matching completed.\n", .{});
    
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
