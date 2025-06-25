//! Example of using the HYPERCUBE neural bridge in MAYA
//! This example shows how to process patterns using HYPERCUBE's 4D neural architecture

const std = @import("std");
const neural = @import("../src/neural.zig");
const HypercubeBridge = neural.hypercube.HypercubeBridge;

pub fn main() !void {
    // Initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize the HYPERCUBE bridge with default configuration
    var bridge = try HypercubeBridge.init(allocator, .{
        .attention = .{
            .gravitational_scale = 1.0,
            .min_distance = 0.1,
            .temperature = 0.5,
            .use_softmax = true,
        },
        .tunneling = .{
            .base_probability = 0.1,
            .temperature = 1.0,
            .max_distance_factor = 2.0,
            .adaptive = true,
        },
    });
    defer bridge.deinit();

    // Example pattern to process
    const pattern = "This is a test pattern for HYPERCUBE processing";
    
    // Process the pattern
    std.debug.print("Processing pattern: '{s}'\n", .{pattern});
    const processed = try bridge.processPattern(pattern);
    defer allocator.free(processed);
    
    // Print the result (first 50 bytes for brevity)
    const max_len = @min(50, processed.len);
    std.debug.print("Processed result (first {} bytes): {s}\n", .{ max_len, processed[0..max_len] });
    
    // Process a batch of patterns
    const patterns = [_][]const u8{
        "First pattern to process",
        "Second pattern with more data",
        "Third pattern for testing"
    };
    
    std.debug.print("\nProcessing batch of {} patterns...\n", .{patterns.len});
    const results = try bridge.processBatch(&patterns);
    defer {
        for (results) |result| {
            allocator.free(result);
        }
        allocator.free(results);
    }
    
    // Print batch results
    for (results, 0..) |result, i| {
        const max_len_result = @min(30, result.len);
        std.debug.print("  Result {}: {s}...\n", .{ i, result[0..max_len_result] });
    }
    
    std.debug.print("\nProcessed {} patterns in total\n", .{bridge.state.patterns_processed});
}
