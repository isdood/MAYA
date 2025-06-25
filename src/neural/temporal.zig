//! ⏱️ Temporal Processing Module
//! Provides functionality for processing time-series data

const std = @import("std");
const math = std.math;

// Import Tensor4D type directly
pub const Tensor4D = @import("tensor4d.zig").Tensor4D;

/// Configuration for temporal processing
pub const TemporalConfig = struct {
    // Window size for temporal processing (number of time steps)
    window_size: usize = 8,
    
    // Stride for sliding window (1 = no overlap, window_size = no sliding)
    stride: usize = 1,
    
    // Whether to use causal masking (only look at past time steps)
    causal: bool = true,
};

/// State for temporal processing
pub const TemporalState = struct {
    // Circular buffer for storing recent time steps
    buffer: std.ArrayList(*Tensor4D),
    
    // Current position in the circular buffer
    position: usize = 0,
    
    // Whether the buffer has been filled at least once
    filled: bool = false,
};

/// Temporal processor for HYPERCUBE
pub const TemporalProcessor = struct {
    allocator: Allocator,
    config: TemporalConfig,
    state: TemporalState,
    
    /// Initialize a new temporal processor
    pub fn init(allocator: Allocator, config: TemporalConfig) !*TemporalProcessor {
        var buffer = std.ArrayList(*Tensor4D).init(allocator);
        try buffer.resize(config.window_size);
        
        const processor = try allocator.create(TemporalProcessor);
        processor.* = .{
            .allocator = allocator,
            .config = config,
            .state = .{
                .buffer = buffer,
            },
        };
        
        return processor;
    }
    
    /// Clean up the temporal processor
    pub fn deinit(self: *TemporalProcessor) void {
        if (self.state.filled) {
            for (self.state.buffer.items) |tensor| {
                tensor.deinit();
            }
        }
        self.state.buffer.deinit();
        self.allocator.destroy(self);
    }
    
    /// Process a single time step
    pub fn processTimeStep(self: *TemporalProcessor, input: *Tensor4D) !*Tensor4D {
        // Store the input in the buffer (making a copy)
        const tensor_copy = try input.dupe(self.allocator);
        
        if (self.state.filled) {
            // Replace the oldest tensor
            self.state.buffer.items[self.state.position].deinit();
        }
        
        self.state.buffer.items[self.state.position] = tensor_copy;
        self.state.position = (self.state.position + 1) % self.config.window_size;
        
        if (!self.state.filled && self.state.position == 0) {
            self.state.filled = true;
        }
        
        // For now, just return the input as is
        // In a real implementation, we would apply temporal processing here
        return tensor_copy;
    }
};

// Tests
const testing = std.testing;

test "TemporalProcessor init and deinit" {
    var processor = try TemporalProcessor.init(testing.allocator, .{});
    defer processor.deinit();
    
    try testing.expect(!processor.state.filled);
    try testing.expectEqual(@as(usize, 0), processor.state.position);
}
