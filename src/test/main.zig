const std = @import("std");
const language_processor = @import("language_processor.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var processor = try language_processor.LanguageProcessor.init(allocator);
    defer processor.deinit();

    try processor.runTests();
} 