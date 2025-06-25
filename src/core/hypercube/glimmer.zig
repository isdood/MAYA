const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Tensor4D = @import("tensor4d.zig").Tensor4D;

/// Color in RGBA format
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

/// Visualization parameters for GLIMMER
pub const GlimmerParams = struct {
    /// Color map to use for visualization
    color_map: []const Color = &DEFAULT_COLORMAP,
    
    /// Gamma correction for color mapping
    gamma: f32 = 1.0,
    
    /// Whether to normalize values before visualization
    normalize: bool = true,
    
    /// Whether to use log scaling for better visualization of small values
    use_log_scale: bool = false,
};

/// Default color map (rainbow)
pub const DEFAULT_COLORMAP = [_]Color{
    .{ .r = 0, .g = 0, .b = 255 },   // Blue
    .{ .r = 0, .g = 255, .b = 255 }, // Cyan
    .{ .r = 0, .g = 255, .b = 0 },   // Green
    .{ .r = 255, .g = 255, .b = 0 }, // Yellow
    .{ .r = 255, .g = 128, .b = 0 }, // Orange
    .{ .r = 255, .g = 0, .b = 0 },   // Red
};

/// Renders a 4D tensor as an image using GLIMMER visualization
pub fn renderTensor4D(
    allocator: Allocator,
    tensor: *const Tensor4D,
    params: GlimmerParams,
) ![]const u8 {
    // For now, we'll render a 2D slice of the 4D tensor
    // In a real implementation, this would be more sophisticated
    
    const batch = 0; // Only render first batch
    const channel = 0; // Only render first channel
    
    const width = tensor.shape[3];
    const height = tensor.shape[2];
    
    // Find min/max for normalization
    var min_val: f32 = std.math.floatMax(f32);
    var max_val: f32 = -std.math.floatMax(f32);
    
    if (params.normalize) {
        for (0..height) |y| {
            for (0..width) |x| {
                const val = tensor.get(batch, channel, y, x);
                min_val = @min(min_val, val);
                max_val = @max(max_val, val);
            }
        }
    } else {
        min_val = 0.0;
        max_val = 1.0;
    }
    
    const range = if (max_val > min_val) max_val - min_val else 1.0;
    
    // Create PPM image in memory
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    // Write PPM header
    try buffer.writer().print("P6\n{d} {d}\n255\n", .{ width, height });
    
    // Write pixel data
    for (0..height) |y| {
        for (0..width) |x| {
            var val = tensor.get(batch, channel, y, x);
            
            // Normalize to [0, 1]
            val = (val - min_val) / range;
            
            // Apply gamma correction
            val = std.math.pow(f32, val, 1.0 / params.gamma);
            
            // Get color from colormap
            const color_idx = @as(usize, @intFromFloat(val * @as(f32, @floatFromInt(params.color_map.len - 1))));
            const color = params.color_map[@min(color_idx, params.color_map.len - 1)];
            
            // Write RGB values
            try buffer.appendSlice(&[_]u8{ color.r, color.g, color.b });
        }
    }
    
    return buffer.toOwnedSlice();
}

/// Creates an animated GIF showing the evolution of a 4D tensor over time
pub fn createTensorAnimation(
    allocator: Allocator,
    tensors: []const *const Tensor4D,
    frame_delay_ms: u16,
) ![]const u8 {
    // In a real implementation, this would use a GIF encoding library
    // For now, we'll just return a simple text representation
    
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    try buffer.writer().print(
        "GLIMMER Animation ({d} frames, {d}ms delay)\n",
        .{ tensors.len, frame_delay_ms },
    );
    
    for (tensors, 0..) |tensor, i| {
        try buffer.writer().print("Frame {d}: [{d}x{d}x{d}x{d}]\n", .{
            i,
            tensor.shape[0],
            tensor.shape[1],
            tensor.shape[2],
            tensor.shape[3],
        });
    }
    
    return buffer.toOwnedSlice();
}

/// Visualizes a spiral convolution kernel
pub fn visualizeSpiralKernel(
    allocator: std.mem.Allocator,
    kernel_size: usize,
    num_rotations: f32,
) ![]const u8 {
    // Create a simple ASCII art representation of the spiral kernel
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    const center = @as(f32, @floatFromInt(kernel_size - 1)) / 2.0;
    
    for (0..kernel_size) |y| {
        for (0..kernel_size) |x| {
            const dx = @as(f32, @floatFromInt(x)) - center;
            const dy = @as(f32, @floatFromInt(y)) - center;
            const dist = math.sqrt(dx * dx + dy * dy);
            const angle = math.atan2(dy, dx);
            
            // Calculate spiral value
            const spiral_angle = angle + math.pi; // Map to [0, 2π]
            const spiral_radius = spiral_angle / (2.0 * math.pi * num_rotations);
            
            // Simple visualization
            if (dist <= spiral_radius * center * 1.5) {
                try buffer.append('#');
            } else {
                try buffer.append('.');
            }
        }
        try buffer.append('\n');
    }
    
    return buffer.toOwnedSlice();
}

// Tests for GLIMMER visualization
const testing = std.testing;

test "renderTensor4D with simple tensor" {
    const allocator = testing.allocator;
    
    // Create a simple 1x1x3x3 tensor (batch=1, channels=1, height=3, width=3)
    var tensor = try Tensor4D.init(allocator, [4]usize{1, 1, 3, 3});
    defer tensor.deinit();
    
    // Fill with a gradient
    tensor.set(0, 0, 0, 0, 0.1);
    tensor.set(0, 0, 0, 1, 0.3);
    tensor.set(0, 0, 0, 2, 0.5);
    tensor.set(0, 0, 1, 0, 0.7);
    tensor.set(0, 0, 1, 1, 0.9);
    tensor.set(0, 0, 1, 2, 1.0);
    tensor.set(0, 0, 2, 0, 0.8);
    tensor.set(0, 0, 2, 1, 0.6);
    tensor.set(0, 0, 2, 2, 0.4);
    
    // Render with default parameters
    const ppm_data = try renderTensor4D(allocator, &tensor, .{});
    defer allocator.free(ppm_data);
    
    // Basic validation of PPM output
    try testing.expect(std.mem.startsWith(u8, ppm_data, "P6\n"));
    try testing.expect(std.mem.containsAtLeast(u8, ppm_data, 1, "3 3\n"));
    
    // Should have 3x3x3 = 27 bytes of pixel data
    try testing.expect(ppm_data.len > 27);
}

test "visualizeSpiralKernel" {
    const allocator = testing.allocator;
    
    const kernel_size = 11;
    const num_rotations = 2.0;
    
    const visualization = try visualizeSpiralKernel(
        allocator,
        kernel_size,
        num_rotations,
    );
    defer allocator.free(visualization);
    
    // Should have kernel_size lines, each with kernel_size characters + newline
    const expected_length = kernel_size * (kernel_size + 1);
    try testing.expectEqual(expected_length, visualization.len);
}
