@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 10:40:05",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./test/run_tests.zig",
    "type": "zig",
    "hash": "3b0a05e4b182d173767a0283bc46d5d4fc2fa520"
  }
}
@pattern_meta@

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
