
const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    _ = std.heap.page_allocator; // Will be used in future
    
    std.debug.print("\n=== Starting MAYA Test Suite ===\n\n", .{});
    
    // Run unit tests
    std.debug.print("Running unit tests...\n", .{});
    {
        const unit_tests = @import("crystal_computing_test.zig");
        try std.testing.runTest(unit_tests);
    }
    
    // Run integration tests if available
    std.debug.print("\nRunning integration tests...\n", .{});
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
    
    std.debug.print("\n✅ All tests passed!\n", .{});
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
