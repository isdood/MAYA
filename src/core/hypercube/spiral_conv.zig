const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Tensor4D = @import("tensor4d.zig").Tensor4D;

/// Parameters for spiral convolution
pub const SpiralConvParams = struct {
    kernel_size: usize = 3,
    stride: usize = 1,
    padding: usize = 1,
    dilation: usize = 1,
    groups: usize = 1,
    use_bias: bool = true,
};

/// Spiral Convolution layer for processing 4D tensors along Fibonacci spirals
pub const SpiralConv = struct {
    weights: *Tensor4D,
    bias: ?[]f32,
    params: SpiralConvParams,
    allocator: Allocator,

    /// Creates a new spiral convolution layer
    pub fn init(
        allocator: Allocator,
        in_channels: usize,
        out_channels: usize,
        params: SpiralConvParams,
    ) !*@This() {
        const kernel_shape = [4]usize{
            out_channels,
            in_channels / params.groups,
            params.kernel_size,
            params.kernel_size,
        };

        const weights = try Tensor4D.init(allocator, kernel_shape);
        try weights.randomFill(-0.1, 0.1);

        var bias: ?[]f32 = null;
        if (params.use_bias) {
            bias = try allocator.alloc(f32, out_channels);
            for (bias.?) |*b| {
                b.* = 0.0; // Initialize bias to zero
            }
        }

        const self = try allocator.create(@This());
        self.* = .{
            .weights = weights,
            .bias = bias,
            .params = params,
            .allocator = allocator,
        };
        return self;
    }

    /// Frees the convolution layer's memory
    pub fn deinit(self: *@This()) void {
        self.weights.deinit();
        if (self.bias) |b| {
            self.allocator.free(b);
        }
        self.allocator.destroy(self);
    }

    /// Applies spiral convolution to the input tensor
    pub fn forward(self: *const @This(), input: *const Tensor4D) !*Tensor4D {
        const batch_size = input.shape[0];
        const in_channels = input.shape[1];
        const in_height = input.shape[2];
        const in_width = input.shape[3];
        
        const out_channels = self.weights.shape[0];
        const kernel_size = self.weights.shape[2];
        
        // Calculate output dimensions
        const out_height = (in_height + 2 * self.params.padding - 
                          kernel_size) / self.params.stride + 1;
        const out_width = (in_width + 2 * self.params.padding - 
                         kernel_size) / self.params.stride + 1;
        
        // Create output tensor
        const output = try Tensor4D.init(
            self.allocator,
            [4]usize{ batch_size, out_channels, out_height, out_width }
        );
        output.fill(0.0);

        // Generate Fibonacci spiral coordinates for the kernel
        const spiral_coords = try self.generateSpiralCoords(kernel_size);
        defer self.allocator.free(spiral_coords);

        // Perform spiral convolution
        for (0..batch_size) |b| {
            for (0..out_channels) |oc| {
                for (0..out_height) |oh| {
                    for (0..out_width) |ow| {
                        var sum: f32 = 0.0;
                        
                        // Apply spiral kernel
                        for (spiral_coords) |coord| {
                            const kh = coord[0];
                            const kw = coord[1];
                            
                            // Calculate coordinates with proper signed arithmetic
                            const h = @as(isize, @intCast(oh * self.params.stride)) + 
                                    @as(isize, @intCast(kh)) - 
                                    @as(isize, @intCast(self.params.padding));
                            const w = @as(isize, @intCast(ow * self.params.stride)) + 
                                    @as(isize, @intCast(kw)) - 
                                    @as(isize, @intCast(self.params.padding));
                            
                            // Skip if out of bounds (implicit padding with zeros)
                            if (h >= 0 and h < @as(isize, @intCast(in_height)) and 
                                w >= 0 and w < @as(isize, @intCast(in_width))) 
                            {
                                const h_safe = @as(usize, @intCast(h));
                                const w_safe = @as(usize, @intCast(w));
                                
                                for (0..in_channels) |ic| {
                                    const weight = self.weights.get(oc, ic, kh, kw);
                                    const val = input.get(b, ic, h_safe, w_safe);
                                    sum += weight * val;
                                }
                            }
                        }
                        
                        // Add bias if enabled
                        if (self.bias) |bias| {
                            sum += bias[oc];
                        }
                        
                        output.set(b, oc, oh, ow, sum);
                    }
                }
            }
        }
        
        return output;
    }

    /// Generates Fibonacci spiral coordinates for the kernel
    fn generateSpiralCoords(self: *const @This(), size: usize) ![]const struct { usize, usize } {
        const center = @as(f32, @floatFromInt(size - 1)) / 2.0;
        var coords = std.ArrayList(struct { usize, usize }).init(self.allocator);
        
        // Generate Fibonacci spiral points
        const n = size * size;
        const golden_angle = math.pi * (3.0 - math.sqrt(5.0));
        
        for (0..n) |i| {
            const radius = math.sqrt(@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(n)));
            const theta = golden_angle * @as(f32, @floatFromInt(i));
            
            // Convert polar to cartesian coordinates
            const x = center + radius * math.cos(theta) * center;
            const y = center + radius * math.sin(theta) * center;
            
            // Round to nearest integer coordinates
            const xi = @as(usize, @intFromFloat(x + 0.5));
            const yi = @as(usize, @intFromFloat(y + 0.5));
            
            // Ensure coordinates are within bounds
            if (xi < size and yi < size) {
                try coords.append(.{ xi, yi });
            }
        }
        
        return coords.toOwnedSlice();
    }
};

// Tests for SpiralConv
const testing = std.testing;

test "SpiralConv initialization" {
    const allocator = testing.allocator;
    
    const params = SpiralConvParams{
        .kernel_size = 3,
        .stride = 1,
        .padding = 1,
        .use_bias = true,
    };
    
    var conv = try SpiralConv.init(allocator, 3, 6, params);
    defer conv.deinit();
    
    // Verify weights shape
    try testing.expectEqual(@as(usize, 6), conv.weights.shape[0]); // out_channels
    try testing.expectEqual(@as(usize, 3), conv.weights.shape[1]); // in_channels / groups
    try testing.expectEqual(@as(usize, 3), conv.weights.shape[2]); // kernel_size
    try testing.expectEqual(@as(usize, 3), conv.weights.shape[3]); // kernel_size
    
    // Verify bias
    try testing.expect(conv.bias != null);
    if (conv.bias) |b| {
        try testing.expectEqual(@as(usize, 6), b.len); // out_channels
    }
}

test "SpiralConv forward pass" {
    const allocator = testing.allocator;
    
    // Create a simple 3x3x3x3 input tensor
    const input_shape = [4]usize{ 1, 3, 5, 5 }; // batch=1, channels=3, height=5, width=5
    var input = try Tensor4D.init(allocator, input_shape);
    defer input.deinit();
    input.fill(1.0); // Fill with ones
    
    // Create spiral convolution layer
    const params = SpiralConvParams{
        .kernel_size = 3,
        .stride = 1,
        .padding = 1,
        .use_bias = false, // Easier to test without bias
    };
    
    var conv = try SpiralConv.init(allocator, 3, 6, params);
    defer conv.deinit();
    
    // Set all weights to 1.0 for predictable output
    for (0..6) |oc| {
        for (0..3) |ic| {
            for (0..3) |h| {
                for (0..3) |w| {
                    conv.weights.set(oc, ic, h, w, 1.0);
                }
            }
        }
    }
    
    // Perform forward pass
    const output = try conv.forward(&input);
    defer output.deinit();
    
    // Verify output shape
    try testing.expectEqual(@as(usize, 1), output.shape[0]); // batch
    try testing.expectEqual(@as(usize, 6), output.shape[1]); // channels
    try testing.expectEqual(@as(usize, 5), output.shape[2]); // height
    try testing.expectEqual(@as(usize, 5), output.shape[3]); // width
    
    // For input filled with ones and all weights=1.0, the output should be 27 at each position
    // (3 input channels * 3x3 kernel = 27)
    try testing.expectEqual(@as(f32, 27.0), output.get(0, 0, 2, 2));
}
