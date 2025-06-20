@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-16 08:27:07",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/test/pattern_recognizer_test.zig",
    "type": "zig",
    "hash": "1ac3b2dbd21195b57872536375868de176ebfa22"
  }
}
@pattern_meta@

const std = @import("std");
const testing = std.testing;
const PatternRecognizer = @import("../learning/pattern_recognizer.zig").PatternRecognizer;
const Interaction = @import("../learning/interaction_recorder.zig").Interaction;

test "detectPatterns identifies consecutive actions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a list of interactions with consecutive actions
    var interactions = std.ArrayList(Interaction).init(allocator);
    defer interactions.deinit();

    // Interaction 1: code_change
    try interactions.append(Interaction{
        .context = .{
            .file_path = try allocator.dupe(u8, "src/test.zig"),
            .cursor_position = .{ .line = 1, .column = 1 },
            .selected_text = null,
            .surrounding_code = try allocator.dupe(u8, ""),
            .project_state = .{
                .modified_files = std.ArrayList([]const u8).init(allocator),
                .active_file = null,
                .last_compilation = null,
            },
        },
        .action = .{
            .type = .code_change,
            .content = try allocator.dupe(u8, "const x = 5;"),
            .parameters = std.StringHashMap([]const u8).init(allocator),
        },
        .metadata = .{
            .os_info = try allocator.dupe(u8, "ArchLinux"),
            .session_id = try allocator.dupe(u8, "test_session"),
        },
    });

    // Interaction 2: code_change (consecutive)
    try interactions.append(Interaction{
        .context = .{
            .file_path = try allocator.dupe(u8, "src/test.zig"),
            .cursor_position = .{ .line = 2, .column = 1 },
            .selected_text = null,
            .surrounding_code = try allocator.dupe(u8, ""),
            .project_state = .{
                .modified_files = std.ArrayList([]const u8).init(allocator),
                .active_file = null,
                .last_compilation = null,
            },
        },
        .action = .{
            .type = .code_change,
            .content = try allocator.dupe(u8, "const y = 10;"),
            .parameters = std.StringHashMap([]const u8).init(allocator),
        },
        .metadata = .{
            .os_info = try allocator.dupe(u8, "ArchLinux"),
            .session_id = try allocator.dupe(u8, "test_session"),
        },
    });

    // Interaction 3: other (not consecutive)
    try interactions.append(Interaction{
        .context = .{
            .file_path = try allocator.dupe(u8, "src/test.zig"),
            .cursor_position = .{ .line = 3, .column = 1 },
            .selected_text = null,
            .surrounding_code = try allocator.dupe(u8, ""),
            .project_state = .{
                .modified_files = std.ArrayList([]const u8).init(allocator),
                .active_file = null,
                .last_compilation = null,
            },
        },
        .action = .{
            .type = .other,
            .content = try allocator.dupe(u8, ""),
            .parameters = std.StringHashMap([]const u8).init(allocator),
        },
        .metadata = .{
            .os_info = try allocator.dupe(u8, "ArchLinux"),
            .session_id = try allocator.dupe(u8, "test_session"),
        },
    });

    // Initialize the PatternRecognizer
    var recognizer = PatternRecognizer.init(allocator, interactions.items);

    // Detect patterns
    const patterns = try recognizer.detectPatterns();
    defer allocator.free(patterns);

    // Verify that exactly one pattern is detected
    testing.expectEqual(@as(usize, 1), patterns.len) catch |err| {
        std.debug.print("Expected 1 pattern, found {}\n", .{patterns.len});
        return err;
    };

    // Verify the pattern details
    const pattern = patterns[0];
    testing.expectEqualStrings("pattern_0", pattern.id) catch |err| {
        std.debug.print("Expected pattern ID 'pattern_0', found '{s}'\n", .{pattern.id});
        return err;
    };
    testing.expectEqualStrings("Consecutive code_change actions", pattern.description) catch |err| {
        std.debug.print("Expected pattern description 'Consecutive code_change actions', found '{s}'\n", .{pattern.description});
        return err;
    };
    testing.expectEqual(@as(usize, 2), pattern.interactions.len) catch |err| {
        std.debug.print("Expected 2 interactions in pattern, found {}\n", .{pattern.interactions.len});
        return err;
    };
} 