//! HYPERCUBE: 4D Neural Architecture for MAYA
//! 
//! This module implements the core 4D tensor operations, spiral convolution,
//! and GLIMMER visualization for the HYPERCUBE architecture.

const std = @import("std");

pub const Tensor4D = @import("tensor4d.zig").Tensor4D;
pub const SpiralConv = @import("spiral_conv.zig").SpiralConv;
pub const glimmer = @import("glimmer.zig");

// Core error set for HYPERCUBE operations
pub const Error = error{
    OutOfMemory,
    InvalidShape,
    InvalidAxis,
    DimensionMismatch,
    InvalidSpiralParameters,
};

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
}
