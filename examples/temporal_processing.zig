//! Example of using HYPERCUBE's temporal processing
//! This example shows how to process time-series data using HYPERCUBE's 4D neural architecture

const std = @import("std");
const print = std.debug.print;
const math = std.math;
const Allocator = std.mem.Allocator;

// Import types directly from source files
const Tensor4D = @import("../src/neural/tensor4d.zig").Tensor4D;
const HypercubeBridge = @import("../src/neural/hypercube_bridge.zig").HypercubeBridge;

// Simple moving average for demonstration
fn generateSineWave(allocator: std.mem.Allocator, num_points: usize, phase: f32) ![]f32 {
    const data = try allocator.alloc(f32, num_points);
    for (data, 0..) |*val, i| {
        val.* = 0.5 + 0.5 * @sin(2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(num_points)) + phase);
    }
    return data;
}

// Convert time series data to a 4D tensor
fn seriesToTensor(allocator: Allocator, data: []const f32) !*Tensor4D {
    // Create a 4D tensor with shape [1, 1, 1, data.len]
    const tensor = try Tensor4D.init(allocator, .{1, 1, 1, @intCast(data.len)});
    
    // Copy data into the tensor
    for (data, 0..) |value, i| {
        tensor.set(0, 0, 0, @as(usize, @intCast(i)), value);
    }
    
    return tensor;
}

// Visualize a 1D slice of a 4D tensor as a time series
fn visualizeTensorAsSeries(tensor: *const Tensor4D, width: usize, height: usize) !void {
    const len = tensor.shape[3];
    const allocator = std.heap.page_allocator;
    const data = try allocator.alloc(f32, len);
    defer allocator.free(data);
    
    // Extract 1D slice
    for (0..len) |i| {
        data[i] = tensor.get(0, 0, 0, @as(usize, @intCast(i)));
    }

    // Find min/max for scaling
    var max_val: f32 = -std.math.f32_max;
    var min_val: f32 = std.math.f32_max;
    for (data) |value| {
        max_val = @max(max_val, value);
        min_val = @min(min_val, value);
    }
    const range = max_val - min_val;
    
    // Simple ASCII visualization
    for (0..height) |row| {
        const value = max_val - (row * range) / @max(1, height - 1);
        
        // Print value label
        std.debug.print("{d:4.2f} |", .{value});
        
        for (0..width) |col| {
            const t = (col * len) / width;
            const t_next = ((col + 1) * len) / width;
            
            // Average values in this time window
            var sum: f32 = 0.0;
            var count: usize = 0;
            for (t..t_next) |i| {
                if (i < data.len) {
                    sum += data[i];
                    count += 1;
                }
            }
            
            const avg = if (count > 0) sum / @as(f32, @floatFromInt(count)) else 0.0;
            
            // Simple ASCII art visualization
            const row_value = max_val - (row * range) / @max(1, height - 1);
            if (math.fabs(avg - row_value) < (range / @as(f32, @floatFromInt(height)))) {
                std.debug.print("*", .{});
            } else if (row == height / 2) {
                std.debug.print("-", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        
        std.debug.print("\n", .{});
    }
}

pub fn main() !void {
    // Initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Generate test data (sine wave with phase shift)
    const num_points = 100;
    const input_data = try generateSineWave(allocator, num_points, 0.0);
    defer allocator.free(input_data);
    
    // Initialize HYPERCUBE bridge with temporal processing
    var bridge = try HypercubeBridge.init(allocator, .{
        .temporal = .{
            .window_size = 10,
            .stride = 1,
            .causal = true,
            .attention = .{
                .gravitational_scale = 1.0,
                .min_distance = 0.1,
                .temperature = 0.5,
                .use_softmax = true,
            },
        },
        .enable_temporal = true,
        .enable_attention = true,
        .enable_tunneling = false, // Disable for this example
    });
    defer bridge.deinit();
    
    // Process the time series
    std.debug.print("Processing time series with {} points...\n\n", .{num_points});
    
    // Process in a sliding window
    const window_size = 20;
    const step = 5;
    
    for (0..(num_points - window_size + 1) / step) |i| {
        const start = i * step;
        const end = @min(start + window_size, num_points);
        const window = input_data[start..end];
        
        // Convert window to tensor
        var tensor = try seriesToTensor(allocator, window);
        defer tensor.deinit();
        
        // Process with HYPERCUBE
        const processed = try bridge.processPattern(try std.fmt.allocPrint(allocator, "{any}", .{window}));
        defer allocator.free(processed);
        
        if (i % 5 == 0) {
            std.debug.print("\nWindow {} (t={} to t={}):\n", .{ i + 1, start, end - 1 });
            try visualizeTensorAsSeries(tensor, 60, 10);
            std.debug.print("\n", .{});
        }
    }
    
    std.debug.print("\nTemporal processing complete!\n", .{});
}
