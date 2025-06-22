//! 🚀 SIMD-accelerated Pattern Processing
//! ✨ Version: 1.0.0
//! 📅 Created: 2025-06-22
//! 👤 Author: isdood

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;

// Import the appropriate SIMD module based on architecture
const simd = if (builtin.cpu.arch == .x86_64)
    @import("std").x86
else if (builtin.cpu.arch == .aarch64)
    @import("std").aarch64
else
    @compileError("SIMD not supported on this architecture");

/// SIMD-accelerated pattern processing
pub const SimdPatternProcessor = struct {
    allocator: Allocator,
    vector_width: usize,
    
    pub fn init(allocator: Allocator) !*@This() {
        const self = try allocator.create(@This());
        self.* = .{
            .allocator = allocator,
            .vector_width = @divExact(@sizeOf(simd.u8x32) * 8, 8), // 256-bit vectors by default
        };
        return self;
    }
    
    pub fn deinit(self: *@This()) void {
        self.allocator.destroy(self);
    }
    
    /// Apply a function to each element in parallel using SIMD
    pub fn vectorizedMap(self: *const @This(), 
                        input: []const u8, 
                        output: []u8, 
                        comptime T: type, 
                        comptime f: fn(T) T) void {
        const vector_size = @sizeOf(simd.u8x32);
        const aligned_len = (input.len / vector_size) * vector_size;
        
        // Process aligned blocks with SIMD
        var i: usize = 0;
        while (i < aligned_len) : (i += vector_size) {
            const vec = @as(*align(1) const simd.u8x32, @ptrCast(&input[i])).*;
            const result = f(vec);
            @as(*align(1) simd.u8x32, @ptrCast(&output[i])).* = result;
        }
        
        // Process remaining elements
        for (input[aligned_len..], output[aligned_len..]) |val, *out| {
            out.* = @as(u8, @intCast(f(@as(T, val))));
        }
    }
    
    /// SIMD-accelerated pattern matching
    pub fn patternMatch(self: *const @This(), 
                       pattern: []const u8, 
                       target: []const u8) usize {
        if (pattern.len != target.len) return 0;
        
        const vector_size = @sizeOf(simd.u8x32);
        const aligned_len = (pattern.len / vector_size) * vector_size;
        var matches: usize = 0;
        
        // Process in SIMD vectors
        var i: usize = 0;
        while (i < aligned_len) : (i += vector_size) {
            const pat_vec = @as(*align(1) const simd.u8x32, @ptrCast(&pattern[i])).*;
            const tgt_vec = @as(*align(1) const simd.u8x32, @ptrCast(&target[i])).*;
            const mask = @as(simd.u8x32, @splat(@as(u8, 0xFF))) & @as(simd.u8x32, @splat(1)) * @as(simd.u8x32, @splat(@as(u8, @intFromBool(pat_vec.eql(tgt_vec)))));
            matches += @popCount(mask);
        }
        
        // Process remaining elements
        for (pattern[aligned_len..], target[aligned_len..]) |p, t| {
            matches += @intFromBool(p == t);
        }
        
        return matches;
    }
    
    /// SIMD-accelerated pattern transformation
    pub fn transformPattern(self: *const @This(), 
                           input: []const u8, 
                           output: []u8, 
                           transform: *const fn (u8) u8) void {
        self.vectorizedMap(input, output, u8, transform);
    }
    
    /// Calculate pattern statistics using SIMD
    pub fn calculateStats(self: *const @This(), 
                         pattern: []const u8) struct { mean: f64, variance: f64 } {
        const vector_size = @sizeOf(simd.u8x32);
        const aligned_len = (pattern.len / vector_size) * vector_size;
        
        var sum: u64 = 0;
        var sum_sq: u64 = 0;
        
        // Process in SIMD vectors
        var i: usize = 0;
        while (i < aligned_len) : (i += vector_size) {
            const vec = @as(*align(1) const simd.u8x32, @ptrCast(&pattern[i])).*;
            
            // Horizontal sum
            const vec_u16 = @as(simd.u16x16, @bitCast(vec));
            const sum2 = @reduce(.Add, vec_u16);
            sum += @as(u64, @intCast(sum2));
            
            // Sum of squares
            const squared = @as(simd.u16x16, @bitCast(vec)) * @as(simd.u16x16, @bitCast(vec));
            sum_sq += @reduce(.Add, @as(simd.u32x8, @bitCast(squared)));
        }
        
        // Process remaining elements
        for (pattern[aligned_len..]) |val| {
            sum += val;
            sum_sq += val * val;
        }
        
        const mean = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(pattern.len));
        const mean_sq = @as(f64, @floatFromInt(sum_sq)) / @as(f64, @floatFromInt(pattern.len));
        const variance = mean_sq - (mean * mean);
        
        return .{ .mean = mean, .variance = variance };
    }
};

// Tests
const testing = std.testing;

test "SIMD pattern matching" {
    const allocator = testing.allocator;
    var processor = try SimdPatternProcessor.init(allocator);
    defer processor.deinit();
    
    const pattern1 = "abcdefghijklmnopqrstuvwxyz";
    const pattern2 = "abcdefghijklmnopqrstuvwxya";
    
    const matches = processor.patternMatch(pattern1, pattern2);
    try testing.expect(matches == 25); // All but last character match
}

test "SIMD pattern statistics" {
    const allocator = testing.allocator;
    var processor = try SimdPatternProcessor.init(allocator);
    defer processor.deinit();
    
    const pattern = "\x01\x02\x03\x04";
    const stats = processor.calculateStats(pattern);
    
    try testing.expectApproxEqAbs(stats.mean, 2.5, 0.0001);
    try testing.expectApproxEqAbs(stats.variance, 1.25, 0.0001);
}
