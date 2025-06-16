const std = @import("std");
const InteractionRecorder = @import("interaction_recorder.zig").InteractionRecorder;
const PatternRecognizer = @import("pattern_recognizer.zig").PatternRecognizer;

/// The main MAYA learning system interface.
pub const Maya = struct {
    allocator: std.mem.Allocator,
    recorder: InteractionRecorder,
    pattern_recognizer: ?PatternRecognizer,

    /// Initialize a new MAYA learning system instance.
    pub fn init(allocator: std.mem.Allocator) !Maya {
        return Maya{
            .allocator = allocator,
            .recorder = try InteractionRecorder.init(allocator),
            .pattern_recognizer = null,
        };
    }

    /// Deinitialize the MAYA learning system.
    pub fn deinit(self: *Maya) void {
        self.recorder.deinit();
        if (self.pattern_recognizer) |*recognizer| {
            recognizer.deinit();
        }
    }

    /// Record a new interaction in the system.
    pub fn recordInteraction(self: *Maya, context: InteractionRecorder.Context, action: InteractionRecorder.Action) !void {
        try self.recorder.record(context, action);
    }

    /// Get all recorded interactions.
    pub fn getInteractions(self: *Maya) []const InteractionRecorder.Interaction {
        return self.recorder.getInteractions();
    }

    /// Analyze recorded interactions and detect patterns.
    pub fn analyzePatterns(self: *Maya) ![]PatternRecognizer.Pattern {
        const interactions = self.recorder.getInteractions();
        
        // Initialize pattern recognizer if not already done
        if (self.pattern_recognizer == null) {
            self.pattern_recognizer = PatternRecognizer.init(self.allocator, interactions);
        } else {
            // Update the pattern recognizer with new interactions
            self.pattern_recognizer.?.interactions = interactions;
        }

        return try self.pattern_recognizer.?.detectPatterns();
    }

    /// Clear all recorded interactions and patterns.
    pub fn clear(self: *Maya) void {
        self.recorder.clearInteractions();
        if (self.pattern_recognizer) |*recognizer| {
            recognizer.deinit();
            self.pattern_recognizer = null;
        }
    }

    /// Export recorded interactions to a file.
    pub fn exportInteractions(self: *Maya, file_path: []const u8) !void {
        const interactions = self.recorder.getInteractions();
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        const writer = file.writer();
        try writer.print("{{\n  \"interactions\": [\n", .{});
        
        for (interactions, 0..) |interaction, i| {
            try writer.print("    {{\n", .{});
            try writer.print("      \"file_path\": \"{s}\",\n", .{interaction.context.file_path});
            try writer.print("      \"action_type\": \"{s}\",\n", .{@tagName(interaction.action.type)});
            try writer.print("      \"content\": \"{s}\",\n", .{interaction.action.content});
            try writer.print("      \"timestamp\": \"{s}\"\n", .{interaction.metadata.session_id});
            try writer.print("    }}{s}\n", .{if (i < interactions.len - 1) "," else ""});
        }
        
        try writer.print("  ]\n}}\n", .{});
    }

    /// Import interactions from a file.
    pub fn importInteractions(self: *Maya, file_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(content);

        // TODO: Implement JSON parsing and interaction import
        // This is a placeholder for the actual implementation
        _ = content;
    }
}; 