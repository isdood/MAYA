//! HYPERCUBE: 4D Neural Architecture for MAYA
//! 
//! This module implements the core 4D tensor operations, spiral convolution,
//! and GLIMMER visualization for the HYPERCUBE architecture.

const std = @import("std");
const builtin = @import("builtin");

// Core components
pub const Tensor4D = @import("tensor4d.zig").Tensor4D;
pub const SpiralConv = @import("spiral_conv.zig").SpiralConv;
pub const glimmer = @import("glimmer.zig");
pub const attention = @import("attention.zig");

// Re-export commonly used types and functions
pub const Color = glimmer.Color;
pub const GlimmerParams = glimmer.GlimmerParams;
pub const GravityAttentionParams = attention.GravityAttentionParams;

// Core error set for HYPERCUBE operations
pub const Error = error{
    OutOfMemory,
    InvalidShape,
    InvalidAxis,
    DimensionMismatch,
    InvalidSpiralParameters,
    InvalidArgument,
    FileSystemError,
};

/// Command-line interface for HYPERCUBE
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        return printUsage();
    }
    
    if (std.mem.eql(u8, args[1], "example")) {
        try runExample(allocator);
    } else if (std.mem.eql(u8, args[1], "visualize")) {
        if (args.len < 3) {
            std.debug.print("Error: Missing visualization type\n\n", .{});
            return printUsage();
        }
        
        if (std.mem.eql(u8, args[2], "kernel")) {
            const size = if (args.len > 3) 
                try std.fmt.parseInt(usize, args[3], 10) else 11;
            const rotations = if (args.len > 4) 
                try std.fmt.parseFloat(f32, args[4]) else 2.0;
                
            const viz = try glimmer.visualizeSpiralKernel(allocator, size, rotations);
            defer allocator.free(viz);
            std.debug.print("{s}\n", .{viz});
        } else {
            std.debug.print("Error: Unknown visualization type '{s}'\n", .{args[2]});
            return printUsage();
        }
    } else {
        std.debug.print("Error: Unknown command '{s}'\n", .{args[1]});
        return printUsage();
    }
}

/// Print command-line usage information
fn printUsage() !void {
    const usage = 
        \\Usage:
        \\  hypercube example               Run the example program
        \\  hypercube visualize kernel [size=11] [rotations=2.0]  Visualize a spiral kernel
        \\
        \\Examples:
        \\  hypercube example
        \\  hypercube visualize kernel
        \\  hypercube visualize kernel 15 3.0
        \\
    ;
    
    std.debug.print("{s}", .{usage});
    return Error.InvalidArgument;
}

/// Run the example program
fn runExample(allocator: std.mem.Allocator) !void {
    std.debug.print("🚀 Starting HYPERCUBE example...\n", .{});
    
    // Create a simple 4D tensor (batch=1, channels=1, height=32, width=32)
    const input_shape = [4]usize{ 1, 1, 32, 32 };
    var input = try Tensor4D.init(allocator, input_shape);
    defer input.deinit();
    
    // Fill with a simple pattern (gradient from top-left to bottom-right)
    for (0..input_shape[2]) |y| {
        for (0..input_shape[3]) |x| {
            const value = (@as(f32, @floatFromInt(x + y)) / @as(f32, @floatFromInt(input_shape[2] + input_shape[3] - 2)));
            input.set(0, 0, y, x, value);
        }
    }
    
    // Save the input as an image
    const input_ppm = try glimmer.renderTensor4D(allocator, input, .{});
    defer allocator.free(input_ppm);
    
    try std.fs.cwd().writeFile(.{ .sub_path = "input.ppm", .data = input_ppm });
    std.debug.print("✅ Saved input image to input.ppm\n", .{});
    
    // Create a spiral convolution layer
    const in_channels = 1;
    const out_channels = 1;
    const conv = try SpiralConv.init(allocator, in_channels, out_channels, .{
        .kernel_size = 5,
        .stride = 1,
        .padding = 2,
    });
    defer conv.deinit();
    
    // Visualize the spiral kernel
    const kernel_viz = try glimmer.visualizeSpiralKernel(allocator, 11, 2.0);
    defer allocator.free(kernel_viz);
    
    std.debug.print("\nSpiral Kernel Visualization (11x11, 2 rotations):\n{any}\n", .{kernel_viz});
    
    // Apply the convolution
    const output = try conv.forward(input);
    defer output.deinit();
    
    // Save the output as an image
    const output_ppm = try glimmer.renderTensor4D(allocator, output, .{});
    defer allocator.free(output_ppm);
    
    try std.fs.cwd().writeFile(.{ .sub_path = "output.ppm", .data = output_ppm });
    std.debug.print("✅ Applied spiral convolution and saved result to output.ppm\n", .{});
    
    // Print tensor shapes
    std.debug.print("\nTensor shapes:\n", .{});
    std.debug.print("  Input:  {any}\n", .{input.shape});
    std.debug.print("  Output: {any}\n", .{output.shape});
    
    // Print some sample values
    std.debug.print("\nSample values (input[0,0,0:5,0:5]):\n", .{});
    for (0..5) |y| {
        for (0..5) |x| {
            std.debug.print("{d:4.2} ", .{input.get(0, 0, y, x)});
        }
        std.debug.print("\n", .{});
    }
    
    std.debug.print("\nSample values (output[0,0,0:5,0:5]):\n", .{});
    for (0..5) |y| {
        for (0..5) |x| {
            std.debug.print("{d:4.2} ", .{output.get(0, 0, y, x)});
        }
        std.debug.print("\n", .{});
    }
}

/// Initializes the HYPERCUBE system with the given allocator
pub fn init(allocator: std.mem.Allocator) void {
    _ = allocator;
    // Initialization logic will go here
}

/// Deinitializes the HYPERCUBE system
pub fn deinit() void {
    // Cleanup logic will go here
}

test "hypercube module tests" {
    const allocator = std.testing.allocator;
    
    // Basic test to verify module compilation
    try std.testing.expect(true);
    
    // Run the example as a test
    try runExample(allocator);
}
