
const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const InteractionRecorder = @import("../learning/interaction_recorder.zig").InteractionRecorder;

pub fn runInteractionRecorderTests() !void {
    print("\nMAYA Interaction Recorder Tests\n", .{});
    print("============================\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var recorder = try InteractionRecorder.init(allocator);
    defer recorder.deinit();

    // Test basic recording
    try testBasicRecording(&recorder);
    
    // Test metadata creation
    try testMetadataCreation(&recorder);
    
    // Test interaction management
    try testInteractionManagement(&recorder);
}

fn testBasicRecording(recorder: *InteractionRecorder) !void {
    print("Testing basic recording...\n", .{});
    
    // Create test context
    const context = InteractionRecorder.Context{
        .file_path = try recorder.allocator.dupe(u8, "src/test.zig"),
        .cursor_position = .{ .line = 10, .column = 5 },
        .selected_text = try recorder.allocator.dupe(u8, "const x = 5;"),
        .surrounding_code = try recorder.allocator.dupe(u8, "fn main() void {\n    const x = 5;\n}"),
        .project_state = .{
            .modified_files = std.ArrayList([]const u8).init(recorder.allocator),
            .active_file = try recorder.allocator.dupe(u8, "src/test.zig"),
            .last_compilation = null,
        },
    };

    // Create test action
    const parameters = std.StringHashMap([]const u8).init(recorder.allocator);
    try parameters.put("type", "variable_declaration");
    const action = InteractionRecorder.Action{
        .type = .code_change,
        .content = try recorder.allocator.dupe(u8, "const x: u32 = 5;"),
        .parameters = parameters,
    };

    // Record interaction
    try recorder.record(context, action);

    // Verify recording
    const interactions = recorder.getInteractions();
    if (interactions.len != 1) {
        print("Error: Expected 1 interaction, found {}\n", .{interactions.len});
        return error.InvalidInteractionCount;
    }

    const interaction = interactions[0];
    if (!std.mem.eql(u8, interaction.context.file_path, "src/test.zig")) {
        print("Error: File path mismatch\n", .{});
        return error.FilePathMismatch;
    }

    if (interaction.context.cursor_position.line != 10 or interaction.context.cursor_position.column != 5) {
        print("Error: Cursor position mismatch\n", .{});
        return error.CursorPositionMismatch;
    }

    print("✓ Basic recording test passed\n", .{});
}

fn testMetadataCreation(recorder: *InteractionRecorder) !void {
    print("\nTesting metadata creation...\n", .{});
    
    // Create test context and action
    const context = InteractionRecorder.Context{
        .file_path = try recorder.allocator.dupe(u8, "src/test.zig"),
        .cursor_position = .{ .line = 1, .column = 1 },
        .selected_text = null,
        .surrounding_code = try recorder.allocator.dupe(u8, ""),
        .project_state = .{
            .modified_files = std.ArrayList([]const u8).init(recorder.allocator),
            .active_file = null,
            .last_compilation = null,
        },
    };

    const parameters = std.StringHashMap([]const u8).init(recorder.allocator);
    const action = InteractionRecorder.Action{
        .type = .other,
        .content = try recorder.allocator.dupe(u8, ""),
        .parameters = parameters,
    };

    // Record interaction
    try recorder.record(context, action);

    // Verify metadata
    const interactions = recorder.getInteractions();
    const interaction = interactions[interactions.len - 1];

    if (!std.mem.startsWith(u8, interaction.metadata.os_info, "ArchLinux")) {
        print("Error: OS info mismatch\n", .{});
        return error.OSInfoMismatch;
    }

    if (interaction.metadata.session_id.len != 36) {
        print("Error: Invalid session ID length\n", .{});
        return error.InvalidSessionID;
    }

    print("✓ Metadata creation test passed\n", .{});
}

fn testInteractionManagement(recorder: *InteractionRecorder) !void {
    print("\nTesting interaction management...\n", .{});
    
    // Record multiple interactions
    const num_interactions = 5;
    var i: usize = 0;
    while (i < num_interactions) : (i += 1) {
        const context = InteractionRecorder.Context{
            .file_path = try recorder.allocator.dupe(u8, "src/test.zig"),
            .cursor_position = .{ .line = i, .column = 0 },
            .selected_text = null,
            .surrounding_code = try recorder.allocator.dupe(u8, ""),
            .project_state = .{
                .modified_files = std.ArrayList([]const u8).init(recorder.allocator),
                .active_file = null,
                .last_compilation = null,
            },
        };

        const parameters = std.StringHashMap([]const u8).init(recorder.allocator);
        const action = InteractionRecorder.Action{
            .type = .other,
            .content = try recorder.allocator.dupe(u8, ""),
            .parameters = parameters,
        };

        try recorder.record(context, action);
    }

    // Verify interaction count
    const interactions = recorder.getInteractions();
    if (interactions.len != num_interactions) {
        print("Error: Expected {} interactions, found {}\n", .{ num_interactions, interactions.len });
        return error.InvalidInteractionCount;
    }

    // Test clearing interactions
    recorder.clearInteractions();
    if (recorder.getInteractions().len != 0) {
        print("Error: Interactions not cleared\n", .{});
        return error.InteractionsNotCleared;
    }

    print("✓ Interaction management test passed\n", .{});
} 
