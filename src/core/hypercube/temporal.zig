//! ⏱️ HYPERCUBE Temporal Processing
//! ✨ Version: 1.0.0
//! 📅 Created: 2025-06-25
//!
//! Implements temporal processing for HYPERCUBE 4D neural architecture

const std = @import("std");
const math = std.math;
const Tensor4D = @import("tensor4d.zig").Tensor4D;
const attention = @import("attention.zig");

/// Configuration for temporal processing
pub const TemporalConfig = struct {
    // Window size for temporal processing (number of time steps)
    window_size: usize = 8,
    
    // Stride for sliding window (1 = no overlap, window_size = no sliding)
    stride: usize = 1,
    
    // Whether to use causal masking (only look at past time steps)
    causal: bool = true,
    
    // Attention configuration for temporal attention
    attention: attention.GravityAttentionParams = .{},
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
    allocator: std.mem.Allocator,
    config: TemporalConfig,
    state: TemporalState,
    
    /// Initialize a new temporal processor
    pub fn init(allocator: std.mem.Allocator, config: TemporalConfig) !*TemporalProcessor {
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
        
        // Get the current window of tensors
        const window = self.getCurrentWindow();
        
        // Apply temporal attention
        return try self.applyTemporalAttention(window);
    }
    
    /// Get the current window of tensors
    fn getCurrentWindow(self: *TemporalProcessor) []*Tensor4D {
        if (!self.state.filled) {
            return self.state.buffer.items[0..self.state.position];
        }
        
        // For a filled buffer, return the window starting at position
        const start = self.state.position;
        const end = start + self.config.window_size;
        
        if (end <= self.state.buffer.items.len) {
            return self.state.buffer.items[start..end];
        } else {
            // Handle wrap-around
            const first_part = self.state.buffer.items[start..];
            const second_part = self.state.buffer.items[0 .. end % self.state.buffer.items.len];
            
            // Create a temporary buffer for the window
            var window = std.ArrayList(*Tensor4D).init(self.allocator);
            window.appendSliceAssumeCapacity(first_part);
            window.appendSliceAssumeCapacity(second_part);
            
            // Note: The caller must free this memory
            return window.toOwnedSlice();
        }
    }
    
    /// Apply temporal attention to the window of tensors
    fn applyTemporalAttention(self: *TemporalProcessor, window: []*Tensor4D) !*Tensor4D {
        // Use the first tensor as query
        const query = window[0];
        
        // Apply attention across time steps
        return try attention.gravityWellAttention(
            self.allocator,
            query,
            window,
            window,
            self.config.attention,
        );
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

test "TemporalProcessor processTimeStep" {
    const allocator = testing.allocator;
    var processor = try TemporalProcessor.init(allocator, .{
        .window_size = 3,
        .stride = 1,
    });
    defer processor.deinit();
    
    // Create a simple tensor
    var shape = [4]usize{1, 1, 2, 2};
    var tensor = try Tensor4D.init(allocator, shape);
    defer tensor.deinit();
    
    // Process first time step
    const result1 = try processor.processTimeStep(tensor);
    defer result1.deinit();
    
    // Process second time step
    const result2 = try processor.processTimeStep(tensor);
    defer result2.deinit();
    
    // Check that we're accumulating time steps
    try testing.expect(!processor.state.filled);
    try testing.equal(@as(usize, 2), processor.state.position);
}
