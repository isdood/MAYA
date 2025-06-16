const std = @import("std");
const Maya = @import("../src/learning/maya.zig").Maya;

pub fn main() !void {
    // Initialize the general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize MAYA
    var maya = try Maya.init(allocator);
    defer maya.deinit();

    // Record some example interactions
    try recordExampleInteractions(&maya);

    // Analyze patterns
    const patterns = try maya.analyzePatterns();
    defer allocator.free(patterns);

    // Print detected patterns
    std.debug.print("\nDetected Patterns:\n", .{});
    for (patterns, 0..) |pattern, i| {
        std.debug.print("\nPattern {d}:\n", .{i + 1});
        std.debug.print("  ID: {s}\n", .{pattern.id});
        std.debug.print("  Description: {s}\n", .{pattern.description});
        std.debug.print("  Number of interactions: {d}\n", .{pattern.interactions.len});
    }

    // Export interactions to a file
    try maya.exportInteractions("maya_interactions.json");
    std.debug.print("\nInteractions exported to maya_interactions.json\n", .{});
}

fn recordExampleInteractions(maya: *Maya) !void {
    const allocator = maya.allocator;

    // Example 1: Code change
    try maya.recordInteraction(.{
        .file_path = try allocator.dupe(u8, "src/main.zig"),
        .cursor_position = .{ .line = 10, .column = 5 },
        .selected_text = try allocator.dupe(u8, "const x = 5;"),
        .surrounding_code = try allocator.dupe(u8, "fn main() void {\n    const x = 5;\n}"),
        .project_state = .{
            .modified_files = std.ArrayList([]const u8).init(allocator),
            .active_file = try allocator.dupe(u8, "src/main.zig"),
            .last_compilation = null,
        },
    }, .{
        .type = .code_change,
        .content = try allocator.dupe(u8, "const x: u32 = 5;"),
        .parameters = std.StringHashMap([]const u8).init(allocator),
    });

    // Example 2: Another code change
    try maya.recordInteraction(.{
        .file_path = try allocator.dupe(u8, "src/main.zig"),
        .cursor_position = .{ .line = 11, .column = 5 },
        .selected_text = try allocator.dupe(u8, "const y = 10;"),
        .surrounding_code = try allocator.dupe(u8, "fn main() void {\n    const x: u32 = 5;\n    const y = 10;\n}"),
        .project_state = .{
            .modified_files = std.ArrayList([]const u8).init(allocator),
            .active_file = try allocator.dupe(u8, "src/main.zig"),
            .last_compilation = null,
        },
    }, .{
        .type = .code_change,
        .content = try allocator.dupe(u8, "const y: u32 = 10;"),
        .parameters = std.StringHashMap([]const u8).init(allocator),
    });
} 