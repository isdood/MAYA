//! 🚀 SIMD-accelerated Pattern Processing
//! ✨ Version: 1.0.2
//! 📅 Created: 2025-06-22
//! 👤 Author: isdood

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;

// Define a portable SIMD vector type
const SimdVector = @Vector(32, u8);

/// SIMD-accelerated pattern processing
pub const SimdPatternProcessor = struct {
    allocator: Allocator,
    vector_width: usize,
    
    pub fn init(allocator: Allocator) !*@This() {
        const self = try allocator.create(@This());
        self.* = .{
            .allocator = allocator,
            .vector_width = @sizeOf(SimdVector),
        };
        return self;
    }
    
    pub fn deinit(self: *@This()) void {
        self.allocator.destroy(self);
    }
    
    /// Apply a function to each element in parallel using SIMD
    pub fn vectorizedMap(_: *const @This(), 
                        input: []const u8, 
                        output: []u8, 
                        comptime T: type, 
                        comptime f: fn(T) T) void {
        const vector_size = @sizeOf(SimdVector);
        const aligned_len = (input.len / vector_size) * vector_size;
        
        // Process aligned blocks with SIMD
        var i: usize = 0;
        while (i < aligned_len) : (i += vector_size) {
            const vec: SimdVector = @as(*align(1) const SimdVector, @ptrCast(@alignCast(&input[i]))).*;
            const result = f(vec);
            @as(*align(1) SimdVector, @ptrCast(@alignCast(&output[i]))).* = result;
        }
        
        // Process remaining elements
        for (input[aligned_len..], output[aligned_len..]) |val, *out| {
            out.* = @as(u8, @intCast(f(@as(T, val))));
        }
    }
    
    /// SIMD-accelerated pattern matching
    pub fn patternMatch(_: *const @This(), 
                       pattern: []const u8, 
                       target: []const u8) usize {
        if (pattern.len != target.len) return 0;
        
        const vector_size = @sizeOf(SimdVector);
        const aligned_len = (pattern.len / vector_size) * vector_size;
        var matches: usize = 0;
        
        // Process in SIMD vectors
        var i: usize = 0;
        while (i < aligned_len) : (i += vector_size) {
            const pat_vec = @as(*align(1) const SimdVector, @ptrCast(@alignCast(&pattern[i]))).*;
            const tgt_vec = @as(*align(1) const SimdVector, @ptrCast(@alignCast(&target[i]))).*;
            const equal = pat_vec == tgt_vec;
            matches += @popCount(@as(u32, @bitCast(equal)));
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
    pub fn calculateStats(_: *const @This(), 
                         pattern: []const u8) struct { mean: f64, variance: f64 } {
        const vector_size = @sizeOf(SimdVector);
        const aligned_len = (pattern.len / vector_size) * vector_size;
        
        var sum: u64 = 0;
        var sum_sq: u64 = 0;
        
        // Process in SIMD vectors
        var i: usize = 0;
        while (i < aligned_len) : (i += vector_size) {
            const vec = @as(*align(1) const SimdVector, @ptrCast(@alignCast(&pattern[i]))).*;
            
            // Process each byte in the vector
            const bytes = @as(*const [32]u8, @ptrCast(&vec));
            for (bytes) |byte| {
                sum += byte;
                sum_sq += @as(u64, byte) * byte;
            }
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
