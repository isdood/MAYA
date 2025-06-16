const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const LanguageProcessor = @import("language_processor.zig").LanguageProcessor;
const pattern_tests = @import("pattern_tests.zig");

pub fn main() !void {
    print("\nMAYA Test Suite\n", .{});
    print("==============\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var processor = try LanguageProcessor.init(allocator);
    defer processor.deinit();

    // Run language processor tests
    try processor.runTests();

    // Run pattern tests
    try pattern_tests.runPatternTests();

    print("\nAll tests completed successfully!\n", .{});
} 