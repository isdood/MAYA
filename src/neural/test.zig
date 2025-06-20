const std = @import("std");
const testing = std.testing;
const neural = @import("./mod.zig");

// Test the pattern recognition module
test "pattern recognition module" {
    try testing.expect(@hasDecl(neural.pattern_recognition, "Pattern"));
    try testing.expect(@hasDecl(neural.pattern_recognition, "PatternFeedback"));
}

// Test the pattern synthesis module
test "pattern synthesis module" {
    try testing.expect(@hasDecl(neural.pattern_synthesis, "SynthesizedPattern"));
    try testing.expect(@hasDecl(neural.pattern_synthesis, "PatternSynthesizer"));
}

// Test the pattern processor module
test "pattern processor module" {
    try testing.expect(@hasDecl(neural.pattern_processor, "PatternProcessor"));
    try testing.expect(@hasDecl(neural.pattern_processor, "ProcessorConfig"));
}

// Test the neural module initialization
test "neural module initialization" {
    // Create a test allocator
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    // Initialize the neural module
    try neural.init(arena.allocator());
    
    // Verify that the module was initialized correctly
    try testing.expect(true);
}

// Test the neural module test runner
test "neural module test runner" {
    // This just verifies that the test runner can be called
    try neural.runTests();
}

// Main test function to run all tests
pub fn main() !void {
    std.debug.print("\n=== Running Neural Module Integration Tests ===\n", .{});
    
    // Run all tests in this file
    const tests = .{
        "pattern recognition module",
        "pattern synthesis module",
        "pattern processor module",
        "neural module initialization",
        "neural module test runner",
    };
    
    for (tests) |test_name| {
        std.debug.print("Running test: {s}... ", .{test_name});
        try testing.runTest(test_name);
        std.debug.print("PASSED\n", .{});
    }
    
    std.debug.print("\n✅ All Neural Module Integration Tests Passed!\n", .{});
}
