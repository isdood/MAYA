//! 🚀 GPU-Accelerated Pattern Evolution Example
//! 
//! This example demonstrates how to use the GPU-accelerated pattern evolution.

const std = @import("std");
const neural = @import("../src/neural");
const Pattern = neural.Pattern;
const GPUEvolution = neural.gpu_evolution.GPUEvolution;

pub fn main() !void {
    // Initialize GPU evolution with default settings
    var gpu_evolution = try GPUEvolution.init(
        std.heap.page_allocator,
        .{ .enabled = true } // Enable GPU acceleration
    );
    defer gpu_evolution.deinit();

    // Create some test patterns
    const width: u32 = 8;
    const height: u32 = 8;
    const channels: u32 = 4; // RGBA
    const pattern_size = width * height * channels;
    
    // Generate some random patterns
    var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const random = rng.random();
    
    const num_patterns = 10;
    var patterns: [num_patterns][]u8 = undefined;
    
    // Allocate and fill patterns
    for (&patterns, 0..) |*pattern, i| {
        pattern.* = try std.heap.page_allocator.alloc(u8, pattern_size);
        random.bytes(pattern.*);
        
        // Set alpha channel to 255
        var j: usize = 3;
        while (j < pattern.len) : (j += 4) {
            pattern.*[j] = 0xFF;
        }
        
        // Print first few bytes of each pattern
        std.debug.print("Pattern {}: 0x", .{i});
        const max_bytes = @min(8, pattern.len);
        for (pattern.*[0..max_bytes]) |byte| {
            std.debug.print("{x:0>2}", .{byte});
        }
        std.debug.print("...\n", .{});
    }
    defer {
        // Clean up patterns
        for (&patterns) |*pattern| {
            std.heap.page_allocator.free(pattern.*);
        }
    }
    
    // Convert to slice of slices for the GPU function
    var pattern_slices: [num_patterns][]const u8 = undefined;
    for (patterns, 0..) |pattern, i| {
        pattern_slices[i] = pattern;
    }
    
    // Calculate fitness on GPU (or CPU fallback)
    const fitness_values = try gpu_evolution.calculateFitnessBatch(&pattern_slices, width, height);
    defer std.heap.page_allocator.free(fitness_values);
    
    // Print results
    std.debug.print("\nFitness values:\n", .{});
    for (fitness_values, 0..) |fitness, i| {
        std.debug.print("  Pattern {}: {d:.4}\n", .{i, fitness});
    }
}

// Add this to build.zig to build the example:
// 
// const gpu_evolution_example = b.addExecutable("gpu_evolution", "examples/gpu_evolution.zig");
// gpu_evolution_example.root_module.addImport("neural", neural_mod);
// b.installArtifact(gpu_evolution_example);
