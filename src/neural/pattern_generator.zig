// 🎨 MAYA Pattern Generator
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-21
// 👤 Author: isdood

const std = @import("std");
const math = std.math;
const rand = std.rand;
const Allocator = std.mem.Allocator;

// Re-export the main types for easier access
pub usingnamespace @This();

/// Pattern generation algorithms
pub const PatternAlgorithm = enum {
    Random,
    Gradient,
    Wave,
    Spiral,
    Checkerboard,
    Fractal,
};

/// Pattern generation configuration
pub const GeneratorConfig = struct {
    width: u32 = 256,
    height: u32 = 256,
    channels: u8 = 3, // RGB
    algorithm: PatternAlgorithm = .Gradient,
    seed: ?u64 = null,
    // Algorithm-specific parameters
    wave_frequency: f32 = 0.1,
    spiral_turns: f32 = 3.0,
    checker_size: u32 = 32,
    fractal_iterations: u8 = 5,
};

/// Generated pattern
pub const Pattern = struct {
    width: u32,
    height: u32,
    channels: u8,
    data: []u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, width: u32, height: u32, channels: u8) !*Pattern {
        const size = width * height * channels;
        const data = try allocator.alloc(u8, size);
        
        const pattern = try allocator.create(Pattern);
        pattern.* = .{
            .width = width,
            .height = height,
            .channels = channels,
            .data = data,
            .allocator = allocator,
        };
        return pattern;
    }

    pub fn deinit(self: *Pattern) void {
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }

    pub fn clear(self: *Pattern, value: u8) void {
        @memset(self.data, value);
    }

    pub fn setPixel(self: *Pattern, x: u32, y: u32, r: u8, g: u8, b: u8) void {
        if (x >= self.width or y >= self.height) return;
        const idx = (y * self.width + x) * self.channels;
        self.data[idx] = r;
        if (self.channels > 1) self.data[idx + 1] = g;
        if (self.channels > 2) self.data[idx + 2] = b;
    }
};

/// Pattern generator
pub const PatternGenerator = struct {
    config: GeneratorConfig,
    rng: rand.Xoshiro256,
    allocator: Allocator,

    pub fn init(allocator: Allocator, config: GeneratorConfig) !*PatternGenerator {
        const seed = config.seed orelse @intCast(std.time.milliTimestamp());
        var rng = rand.DefaultPrng.init(@bitCast(seed));
        
        const gen = try allocator.create(PatternGenerator);
        gen.* = .{
            .config = config,
            .rng = rng,
            .allocator = allocator,
        };
        return gen;
    }

    pub fn deinit(self: *PatternGenerator) void {
        self.allocator.destroy(self);
    }

    /// Generate a new pattern
    pub fn generate(self: *PatternGenerator) !*Pattern {
        const pattern = try Pattern.init(
            self.allocator,
            self.config.width,
            self.config.height,
            self.config.channels
        );

        switch (self.config.algorithm) {
            .Random => try self.generateRandom(pattern),
            .Gradient => try self.generateGradient(pattern),
            .Wave => try self.generateWave(pattern),
            .Spiral => try self.generateSpiral(pattern),
            .Checkerboard => try self.generateCheckerboard(pattern),
            .Fractal => try self.generateFractal(pattern),
        }

        return pattern;
    }

    // -- Pattern Generation Algorithms --


    fn generateRandom(self: *PatternGenerator, pattern: *Pattern) !void {
        for (0..pattern.data.len) |i| {
            pattern.data[i] = self.rng.random().int(u8);
        }
    }

    fn generateGradient(self: *PatternGenerator, pattern: *Pattern) !void {
        const width_f = @as(f32, @floatFromInt(pattern.width));
        const height_f = @as(f32, @floatFromInt(pattern.height));
        
        for (0..pattern.height) |y| {
            const yf = @as(f32, @floatFromInt(y)) / height_f;
            for (0..pattern.width) |x| {
                const xf = @as(f32, @floatFromInt(x)) / width_f;
                const r = @as(u8, @intFromFloat(xf * 255.0));
                const g = @as(u8, @intFromFloat(yf * 255.0));
                const b = @as(u8, @intFromFloat((1.0 - (xf + yf) * 0.5) * 255.0));
                pattern.setPixel(
                    @intCast(x), 
                    @intCast(y), 
                    r, g, b
                );
            }
        }
    }


    fn generateWave(self: *PatternGenerator, pattern: *Pattern) !void {
        const width_f = @as(f32, @floatFromInt(pattern.width));
        const height_f = @as(f32, @floatFromInt(pattern.height));
        const freq = self.config.wave_frequency * 0.1; // Scale frequency
        
        for (0..pattern.height) |y| {
            const yf = @as(f32, @floatFromInt(y)) / height_f;
            for (0..pattern.width) |x| {
                const xf = @as(f32, @floatFromInt(x)) / width_f;
                const value = 0.5 + 0.5 * @sin((xf + yf) * freq * math.pi * 2.0);
                const v = @as(u8, @intFromFloat(value * 255.0));
                pattern.setPixel(
                    @intCast(x), 
                    @intCast(y), 
                    v, v, v
                );
            }
        }
    }


    fn generateSpiral(self: *PatternGenerator, pattern: *Pattern) !void {
        const center_x = @as(f32, @floatFromInt(pattern.width)) * 0.5;
        const center_y = @as(f32, @floatFromInt(pattern.height)) * 0.5;
        const max_radius = @sqrt(center_x * center_x + center_y * center_y);
        const turns = self.config.spiral_turns;
        
        for (0..pattern.height) |y| {
            const yf = @as(f32, @floatFromInt(y)) - center_y;
            for (0..pattern.width) |x| {
                const xf = @as(f32, @floatFromInt(x)) - center_x;
                
                // Convert to polar coordinates
                const radius = @sqrt(xf * xf + yf * yf) / max_radius;
                var angle = std.math.atan2(f32, yf, xf) + math.pi; // 0 to 2π
                
                // Create spiral pattern
                const spiral = (angle / (2.0 * math.pi) * turns + radius) % 1.0;
                const v = @as(u8, @intFromFloat(spiral * 255.0));
                
                // Color based on angle and radius
                const r = @as(u8, @intFromFloat((angle / (2.0 * math.pi)) * 255.0));
                const g = @as(u8, @intFromFloat(radius * 255.0));
                const b = v;
                
                pattern.setPixel(
                    @intCast(x), 
                    @intCast(y), 
                    r, g, b
                );
            }
        }
    }


    fn generateCheckerboard(self: *PatternGenerator, pattern: *Pattern) !void {
        const size = self.config.checker_size;
        
        for (0..pattern.height) |y| {
            for (0..pattern.width) |x| {
                const x_block = x / size;
                const y_block = y / size;
                const is_black = (x_block + y_block) % 2 == 0;
                const value: u8 = if (is_black) 0 else 255;
                pattern.setPixel(
                    @intCast(x), 
                    @intCast(y), 
                    value, value, value
                );
            }
        }
    }


    fn generateFractal(self: *PatternGenerator, pattern: *Pattern) !void {
        // Simple plasma fractal implementation
        const width = pattern.width;
        const height = pattern.height;
        const iterations = self.config.fractal_iterations;
        
        // Initialize with random values at the corners
        var grid = try self.allocator.alloc(f32, width * height);
        defer self.allocator.free(grid);
        
        // Initialize corners with random values
        const size = @max(width, height);
        const max_level = @as(u32, @intCast(@log2(@as(f32, @floatFromInt(size))))) + 1;
        
        // Diamond-square algorithm
        var step = size - 1;
        var scale: f32 = 1.0;
        
        // Initialize corners
        grid[0] = self.rng.random().float(f32);
        grid[width - 1] = self.rng.random().float(f32);
        grid[(height - 1) * width] = self.rng.random().float(f32);
        grid[width * height - 1] = self.rng.random().float(f32);
        
        while (step > 1) {
            const half_step = step / 2;
            
            // Diamond step
            var y: u32 = 0;
            while (y < height - 1) {
                var x: u32 = 0;
                while (x < width - 1) {
                    const a = y * width + x;
                    const b = y * width + (x + step);
                    const c = (y + step) * width + x;
                    const d = (y + step) * width + (x + step);
                    const center = a + half_step * width + half_step;
                    
                    if (center < grid.len) {
                        grid[center] = (grid[a] + grid[b] + grid[c] + grid[d]) * 0.25 + 
                                      (self.rng.random().float(f32) - 0.5) * scale;
                    }
                    x += step;
                }
                y += step;
            }
            
            // Square step
            y = 0;
            while (y < height) {
                var x = (y + half_step) % step == 0 ? 0 : half_step;
                while (x < width) {
                    if (y * width + x < grid.len) {
                        var sum: f32 = 0.0;
                        var count: u32 = 0;
                        
                        // Top neighbor
                        if (y >= half_step) {
                            sum += grid[(y - half_step) * width + x];
                            count += 1;
                        }
                        // Right neighbor
                        if (x + half_step < width) {
                            sum += grid[y * width + (x + half_step)];
                            count += 1;
                        }
                        // Bottom neighbor
                        if (y + half_step < height) {
                            sum += grid[(y + half_step) * width + x];
                            count += 1;
                        }
                        // Left neighbor
                        if (x >= half_step) {
                            sum += grid[y * width + (x - half_step)];
                            count += 1;
                        }
                        
                        if (count > 0) {
                            grid[y * width + x] = sum / @as(f32, @floatFromInt(count)) + 
                                                (self.rng.random().float(f32) - 0.5) * scale;
                        }
                    }
                    x += step;
                }
                y += half_step;
            }
            
            step = half_step;
            scale *= 0.5;
        }
        
        // Convert to RGB
        for (0..height) |y| {
            for (0..width) |x| {
                const idx = y * width + x;
                const value = @as(u8, @intFromFloat(grid[idx] * 255.0));
                pattern.setPixel(
                    @intCast(x), 
                    @intCast(y), 
                    value, value, value
                );
            }
        }
    }
};

// Tests
const expect = std.testing.expect;

test "pattern generator initialization" {
    const allocator = std.testing.allocator;
    const config = GeneratorConfig{ .algorithm = .Gradient };
    var gen = try PatternGenerator.init(allocator, config);
    defer gen.deinit();
    
    try expect(gen.config.algorithm == .Gradient);
}

test "generate gradient pattern" {
    const allocator = std.testing.allocator;
    const config = GeneratorConfig{ 
        .width = 32,
        .height = 32,
        .algorithm = .Gradient 
    };
    
    var gen = try PatternGenerator.init(allocator, config);
    defer gen.deinit();
    
    const pattern = try gen.generate();
    defer pattern.deinit();
    
    try expect(pattern.width == 32);
    try expect(pattern.height == 32);
    try expect(pattern.channels == 3);
    try expect(pattern.data.len == 32 * 32 * 3);
}

test "generate fractal pattern" {
    const allocator = std.testing.allocator;
    const config = GeneratorConfig{ 
        .width = 64,
        .height = 64,
        .algorithm = .Fractal,
        .fractal_iterations = 4
    };
    
    var gen = try PatternGenerator.init(allocator, config);
    defer gen.deinit();
    
    const pattern = try gen.generate();
    defer pattern.deinit();
    
    try expect(pattern.width == 64);
    try expect(pattern.height == 64);
}
