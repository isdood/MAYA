
const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    _ = std.heap.GeneralPurposeAllocator(.{}){};
    
    std.debug.print("\n=== Starting MAYA Test Suite ===\n\n", .{});
    
    // Run minimal neural bridge tests (self-contained, no dependencies)
    std.debug.print("Running Neural Bridge Minimal Tests...\n", .{});
    {
        const min_time = try runTestWithTiming(@import("neural_bridge_minimal.zig"));
        std.debug.print("  ✓ Neural Bridge Minimal Tests passed in {d:.2}ms\n", .{min_time / 1_000_000.0});
    }
    
    // Run unit tests
    std.debug.print("\nRunning Core Unit Tests...\n", .{});
    {
        const unit_time = try runTestWithTiming(@import("crystal_computing_test.zig"));
        std.debug.print("  ✓ Core Unit Tests passed in {d:.2}ms\n", .{unit_time / 1_000_000.0});
    }
    
    // Run integration tests if available
    std.debug.print("\nRunning Integration Tests...\n", .{});
    {
        // Check if integration test file exists
        const file = std.fs.cwd().openFile("test/integration/neural_quantum_visual_test.zig", .{}) catch |err| {
            std.debug.print("Skipping integration tests (not found): {s}\n", .{@errorName(err)});
            return;
        };
        defer file.close();
        
        const integration_test = @import("integration/neural_quantum_visual_test.zig");
        try std.testing.runTest(integration_test);
    }
    
    // Run performance benchmarks
    std.debug.print("\nRunning performance benchmarks...\n", .{});
    try runBenchmarks();
    
    std.debug.print("\nAll tests completed successfully!\n", .{});
}

fn runTestWithTiming(comptime test_fn: anytype) !u64 {
    const start_time = std.time.nanoTimestamp();
    try std.testing.runTest(test_fn);
    const end_time = std.time.nanoTimestamp();
    const duration = end_time - start_time;
    return @as(u64, @intCast(duration));
}

fn runBenchmarks() !void {
    const benchmark = @import("crystal_computing_test.zig");
    
    // Run the benchmark test
    try std.testing.runTest(benchmark);
    
    // Save benchmark results
    const results = "{\"benchmarks\": \"completed\"}"; // Placeholder for actual results
    try saveBenchmarkResults(results);
    
    std.debug.print("\nBenchmark results saved to 'benchmark_results.json'\n", .{});
}

// Helper function to save benchmark results to a file
fn saveBenchmarkResults(results: []const u8) !void {
    const file = try std.fs.cwd().createFile("benchmark_results.json", .{});
    defer file.close();
    
    try file.writeAll(results);
}
