// 🎨 MAYA Pattern Generator
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-21
// 👤 Author: isdood

const std = @import("std");
const math = std.math;
const Random = std.rand.Random;
const Allocator = std.mem.Allocator;

/// Algorithm defines the different pattern generation algorithms
pub const Algorithm = enum {
    Random,
    Gradient,
    Wave,
    Spiral,
    Checkerboard,
    Fractal,
};

// Re-export the main types for easier access
pub usingnamespace @This();

// Import required modules
const neural = @import("neural");
const pattern_recognition = neural.pattern_recognition;
const pattern_synthesis = neural.pattern_synthesis;

/// Configuration for the pattern generator
pub const GeneratorConfig = struct {
    /// Pattern generation algorithm to use
    algorithm: Algorithm = .Random,
    /// Width of the pattern in pixels
    width: u32 = 64,
    /// Height of the pattern in pixels
    height: u32 = 64,
    /// Number of color channels (1=grayscale, 3=RGB, 4=RGBA)
    channels: u8 = 3,
    /// Size of checkerboard squares (if using Checkerboard algorithm)
    checker_size: u8 = 8,
    /// Number of iterations for fractal generation (if using Fractal algorithm)
    fractal_iterations: u8 = 5,
    /// Seed for random number generation (optional)
    seed: ?u64 = null,
    // Algorithm-specific parameters
    wave_frequency: f32 = 0.1,
    spiral_turns: f32 = 3.0,
};

// Re-export the main Pattern type from pattern.zig
pub const Pattern = @import("pattern.zig").Pattern;

/// Extended pattern type with additional methods specific to pattern generation
const ExtendedPattern = struct {
    pattern: *Pattern,
    width: u32,
    height: u32,
    channels: u8,
    
    pub fn deinit(self: *ExtendedPattern) void {
        self.pattern.allocator.free(self.pattern.data);
        self.pattern.allocator.destroy(self.pattern);
    }
    
    pub fn clear(self: *ExtendedPattern, value: u8) void {
        @memset(self.pattern.data, value);
    }
    
    pub fn setPixel(self: *ExtendedPattern, x: u32, y: u32, r: u8, g: u8, b: u8) void {
        if (x >= self.width or y >= self.height) return;
        const idx = (y * self.width + x) * self.channels;
        self.pattern.data[idx] = r;
        if (self.channels > 1) self.pattern.data[idx + 1] = g;
        if (self.channels > 2) self.pattern.data[idx + 2] = b;
    }
};



/// Pattern generator
pub const PatternGenerator = struct {
    config: GeneratorConfig,
    rng: std.Random.Xoshiro256,
    random: std.Random,
    allocator: Allocator,

    pub fn init(allocator: Allocator, config: GeneratorConfig) !*PatternGenerator {
        const seed = config.seed orelse @as(u64, @intCast(std.time.milliTimestamp()));
        var rng = std.Random.Xoshiro256.init(seed);
        const random = rng.random();
        
        const gen = try allocator.create(PatternGenerator);
        gen.* = .{
            .config = config,
            .rng = rng,
            .random = random,
            .allocator = allocator,
        };
        return gen;
    }

    pub fn deinit(self: *PatternGenerator) void {
        self.allocator.destroy(self);
    }

    /// Generate a new pattern
    pub fn generate(self: *PatternGenerator, width: u32, height: u32, channels: u8) !*Pattern {
        const pattern = try Pattern.initPattern(self.allocator, width, height, channels);
        errdefer {
            pattern.allocator.free(pattern.data);
            pattern.allocator.destroy(pattern);
        }
        
        // Create extended pattern for generation
        var ext = ExtendedPattern{
            .pattern = pattern,
            .width = width,
            .height = height,
            .channels = channels,
        };
        
        // Clear the pattern with a default background color
        ext.clear(0);
        
        // Generate the pattern based on the selected algorithm
        switch (self.config.algorithm) {
            .Random => try self.generateRandom(&ext),
            .Gradient => try self.generateGradient(&ext),
            .Wave => try self.generateWave(&ext),
            .Spiral => try self.generateSpiral(&ext),
            .Checkerboard => try self.generateCheckerboard(&ext),
            .Fractal => try self.generateFractal(&ext),
        }
        
        // Analyze the generated pattern
        pattern.analyze();
        
        return pattern;
    }

    // -- Pattern Generation Algorithms --

    fn generateRandom(self: *PatternGenerator, pattern: *ExtendedPattern) !void {
        for (0..pattern.pattern.data.len) |i| {
            pattern.pattern.data[i] = self.random.int(u8);
        }
    }

    fn generateGradient(self: *PatternGenerator, pattern: *ExtendedPattern) !void {
        _ = self; // Mark as used
        const width_f = @as(f32, @floatFromInt(pattern.width));
        const height_f = @as(f32, @floatFromInt(pattern.height));
        
        for (0..pattern.height) |y| {
            for (0..pattern.width) |x| {
                const xf = @as(f32, @floatFromInt(x)) / width_f;
                const yf = @as(f32, @floatFromInt(y)) / height_f;
                const value = @as(u8, @intFromFloat((xf + yf) * 0.5 * 255.0));
                pattern.setPixel(@intCast(x), @intCast(y), value, value, value);
            }
        }
    }

    fn generateWave(self: *PatternGenerator, pattern: *ExtendedPattern) !void {
        _ = self; // Mark as used
        const width_f = @as(f32, @floatFromInt(pattern.width));
        const height_f = @as(f32, @floatFromInt(pattern.height));
        
        for (0..pattern.height) |y| {
            for (0..pattern.width) |x| {
                const xf = @as(f32, @floatFromInt(x)) / width_f * std.math.tau * 8.0;
                const yf = @as(f32, @floatFromInt(y)) / height_f * std.math.tau * 8.0;
                const value = @as(u8, @intFromFloat((@sin(xf) * @sin(yf) * 0.5 + 0.5) * 255.0));
                pattern.setPixel(@intCast(x), @intCast(y), value, value, value);
            }
        }
    }

    fn generateSpiral(self: *PatternGenerator, pattern: *ExtendedPattern) !void {
        _ = self; // Mark as used
        const center_x = @as(f32, @floatFromInt(pattern.width)) * 0.5;
        const center_y = @as(f32, @floatFromInt(pattern.height)) * 0.5;
        
        for (0..pattern.height) |y| {
            for (0..pattern.width) |x| {
                const dx = @as(f32, @floatFromInt(x)) - center_x;
                const dy = @as(f32, @floatFromInt(y)) - center_y;
                const radius = @sqrt(dx * dx + dy * dy);
                const angle = std.math.atan2(dy, dx);
                const value = @as(u8, @intFromFloat((@sin(radius * 0.1 - angle * 2.0) * 0.5 + 0.5) * 255.0));
                pattern.setPixel(@intCast(x), @intCast(y), value, value, value);
            }
        }
    }

    fn generateCheckerboard(self: *PatternGenerator, pattern: *ExtendedPattern) !void {
        const size = self.config.checker_size;
        
        for (0..pattern.height) |y| {
            const y_tile = @divFloor(y, size) % 2 == 0;
            
            for (0..pattern.width) |x| {
                const x_tile = @divFloor(x, size) % 2 == 0;
                const value: u8 = if (x_tile == y_tile) 255 else 0;
                pattern.setPixel(@intCast(x), @intCast(y), value, value, value);
            }
        }
    }


    fn generateFractal(self: *PatternGenerator, pattern: *ExtendedPattern) !void {
        // Simple fractal noise implementation
        const iterations = self.config.fractal_iterations;
        
        // Start with random noise
        try self.generateRandom(pattern);
        
        // Apply box blur multiple times to create fractal-like patterns
        for (0..iterations) |_| {
            // Simple box blur implementation would go here
            // For now, we'll just add some noise
            for (0..pattern.pattern.data.len) |i| {
                pattern.pattern.data[i] = @as(u8, @intFromFloat(
                    @as(f32, @floatFromInt(pattern.pattern.data[i])) * 0.8 + 
                    @as(f32, @floatFromInt(self.random.int(u8))) * 0.2
                ));
            }
        }
    }
};

// Tests
const expect = std.testing.expect;

test "PatternGenerator initialization" {
    const allocator = std.testing.allocator;
    
    const config = GeneratorConfig{
        .algorithm = .Random,
        .width = 64,
        .height = 64,
        .channels = 3,
    };
    
    var gen = try PatternGenerator.init(allocator, config);
    defer gen.deinit();
    
    try expect(gen.config.width == 64);
    try expect(gen.config.height == 64);
    try expect(gen.config.channels == 3);
    try expect(gen.config.algorithm == .Random);
}

test "Pattern generation" {
    const allocator = std.testing.allocator;
    
    const config = GeneratorConfig{
        .algorithm = .Random,
        .width = 32,
        .height = 32,
        .channels = 3,
    };
    
    var gen = try PatternGenerator.init(allocator, config);
    defer gen.deinit();
    
    const pattern = try gen.generate(32, 32, 3);
    defer {
        pattern.allocator.free(pattern.data);
        pattern.allocator.destroy(pattern);
    }
    
    try expect(pattern.width == 32);
    try expect(pattern.height == 32);
    
    // Check that the pattern has some non-zero values
    var has_non_zero = false;
    for (pattern.data) |value| {
        if (value != 0) {
            has_non_zero = true;
            break;
        }
    }
    try expect(has_non_zero);
}

test "Different algorithms" {
    const allocator = std.testing.allocator;
    
    const algorithms = [_]Algorithm{ .Random, .Gradient, .Wave, .Spiral, .Checkerboard, .Fractal };
    
    for (algorithms) |algorithm| {
        const config = GeneratorConfig{
            .algorithm = algorithm,
            .width = 16,
            .height = 16,
            .channels = 3,
        };
        
        var gen = try PatternGenerator.init(allocator, config);
        defer gen.deinit();
        
        const pattern = try gen.generate(16, 16, 3);
        defer {
            pattern.allocator.free(pattern.data);
            pattern.allocator.destroy(pattern);
        }
        
        try expect(pattern.width == 16);
        try expect(pattern.height == 16);
    }
}
