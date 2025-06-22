//! 🎯 MAYA Pattern Operations
//! ✨ Version: 1.0.0
//! 📅 Created: 2025-06-22
//! 👤 Author: isdood

const std = @import("std");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;

/// Pattern mutation operations
pub const PatternMutator = struct {
    allocator: Allocator,
    rng: std.rand.Random,
    
    pub fn init(allocator: Allocator, seed: u64) @This() {
        var rng = std.rand.DefaultPrng.init(seed);
        return .{
            .allocator = allocator,
            .rng = rng.random(),
        };
    }
    
    /// Apply a point mutation to the pattern
    pub fn pointMutation(self: *@This(), pattern: []u8) void {
        if (pattern.len == 0) return;
        const idx = self.rng.intRangeLessThan(usize, 0, pattern.len);
        pattern[idx] ^= @as(u8, 1) << @as(u3, @intCast(self.rng.intRangeLessThan(u3, 0, 8)));
    }
    
    /// Apply a segment shuffle mutation
    pub fn segmentShuffle(self: *@This(), pattern: []u8) void {
        if (pattern.len < 2) return;
        
        const start = self.rng.intRangeLessThan(usize, 0, pattern.len - 1);
        const end = self.rng.intRangeLessThan(usize, start + 1, pattern.len);
        const len = end - start;
        
        // Shuffle the segment
        var i: usize = 0;
        while (i < len / 2) : (i += 1) {
            const a = start + i;
            const b = end - 1 - i;
            const temp = pattern[a];
            pattern[a] = pattern[b];
            pattern[b] = temp;
        }
    }
    
    /// Apply a quantum-inspired phase flip
    pub fn quantumPhaseFlip(self: *@This(), pattern: []u8) void {
        const flip_prob = 0.1; // 10% chance to flip each bit
        for (pattern) |*byte| {
            var mask: u8 = 1;
            while (mask > 0) : (mask <<= 1) {
                if (self.rng.float(f64) < flip_prob) {
                    byte.* ^= mask;
                }
            }
        }
    }
};

/// Pattern crossover operations
pub const PatternCrossover = struct {
    allocator: Allocator,
    rng: std.rand.Random,
    
    pub fn init(allocator: Allocator, seed: u64) @This() {
        var rng = std.rand.DefaultPrng.init(seed);
        return .{
            .allocator = allocator,
            .rng = rng.random(),
        };
    }
    
    /// Perform single-point crossover between two patterns
    pub fn singlePoint(self: *@This(), parent1: []const u8, parent2: []const u8, child: []u8) void {
        const min_len = @min(parent1.len, parent2.len);
        if (min_len == 0) return;
        
        const crossover_point = self.rng.intRangeLessThan(usize, 1, min_len);
        @memcpy(child[0..crossover_point], parent1[0..crossover_point]);
        @memcpy(child[crossover_point..], parent2[crossover_point..]);
    }
    
    /// Perform uniform crossover between two patterns
    pub fn uniform(self: *@This(), parent1: []const u8, parent2: []const u8, child: []u8) void {
        const min_len = @min(parent1.len, parent2.len);
        for (0..min_len) |i| {
            child[i] = if (self.rng.boolean()) parent1[i] else parent2[i];
        }
    }
    
    /// Perform quantum-inspired crossover with phase
    pub fn quantumCrossover(self: *@This(), parent1: []const u8, parent2: []const u8, child: []u8) void {
        const min_len = @min(parent1.len, parent2.len);
        for (0..min_len) |i| {
            // Superposition of both parents with phase
            const phase = self.rng.float(f32) * math.pi * 2;
            const a = @as(f32, @floatFromInt(parent1[i]));
            const b = @as(f32, @floatFromInt(parent2[i]));
            
            // Quantum interference
            const result = (a * @cos(phase) + b * @sin(phase)) * 0.7071; // 1/√2 normalization
            child[i] = @intFromFloat(@round(@abs(result)));
        }
    }
};

/// Pattern fitness evaluation
pub const PatternFitness = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) @This() {
        return .{
            .allocator = allocator,
        };
    }
    
    /// Calculate pattern complexity
    pub fn calculateComplexity(self: *@This(), pattern: []const u8) f64 {
        _ = self; // Unused
        if (pattern.len == 0) return 0.0;
        
        // Simple complexity measure based on byte transitions
        var transitions: usize = 0;
        var last_byte = pattern[0];
        
        for (pattern[1..]) |byte| {
            if (byte != last_byte) {
                transitions += 1;
                last_byte = byte;
            }
        }
        
        return @as(f64, @floatFromInt(transitions)) / @as(f64, @floatFromInt(pattern.len));
    }
    
    /// Calculate pattern entropy
    pub fn calculateEntropy(self: *@This(), pattern: []const u8) f64 {
        _ = self; // Unused
        if (pattern.len == 0) return 0.0;
        
        var counts = [_]usize{0} ** 256;
        for (pattern) |byte| {
            counts[byte] += 1;
        }
        
        var entropy: f64 = 0.0;
        for (counts) |count| {
            if (count > 0) {
                const p = @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(pattern.len));
                entropy -= p * @log2(p);
            }
        }
        
        return entropy / 8.0; // Normalize to [0,1]
    }
};
