
const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize the test runner
    var test_runner = std.testing.allocator;
    
    // Run the integration tests
    const integration_test = @import("integration/neural_quantum_visual_test.zig");
    
    // This will run all tests in the imported file
    _ = try std.testing.runTest(integration_test);
    
    std.debug.print("All integration tests passed!\n", .{});
}
