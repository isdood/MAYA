const std = @import("std");
const print = std.debug.print;

pub const InteractionRecorder = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    interactions: std.ArrayList(Interaction),
    buffer: std.ArrayList(u8),

    pub const Interaction = struct {
        timestamp: u64,
        context: Context,
        action: Action,
        result: Result,
        metadata: Metadata,
    };

    pub const Context = struct {
        file_path: []const u8,
        cursor_position: Position,
        selected_text: ?[]const u8,
        surrounding_code: []const u8,
        project_state: ProjectState,
    };

    pub const Position = struct {
        line: usize,
        column: usize,
    };

    pub const ProjectState = struct {
        modified_files: std.ArrayList([]const u8),
        active_file: ?[]const u8,
        last_compilation: ?u64,
    };

    pub const Action = struct {
        type: ActionType,
        content: []const u8,
        parameters: std.StringHashMap([]const u8),
    };

    pub const ActionType = enum {
        code_change,
        file_edit,
        command_execution,
        test_run,
        build,
        other,
    };

    pub const Result = struct {
        success: bool,
        changes: std.ArrayList(Change),
        errors: ?std.ArrayList(Error),
        performance_metrics: ?PerformanceMetrics,
    };

    pub const Change = struct {
        file_path: []const u8,
        start_line: usize,
        end_line: usize,
        content: []const u8,
    };

    pub const Error = struct {
        message: []const u8,
        location: ?Position,
        severity: ErrorSeverity,
    };

    pub const ErrorSeverity = enum {
        info,
        warning,
        error,
        critical,
    };

    pub const PerformanceMetrics = struct {
        execution_time: u64,
        memory_usage: usize,
        cpu_usage: f32,
    };

    pub const Metadata = struct {
        os_info: []const u8,
        zig_version: []const u8,
        timestamp: u64,
        session_id: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .interactions = std.ArrayList(Interaction).init(allocator),
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.interactions.items) |interaction| {
            self.allocator.free(interaction.context.file_path);
            if (interaction.context.selected_text) |text| {
                self.allocator.free(text);
            }
            self.allocator.free(interaction.context.surrounding_code);
            
            // Free project state
            for (interaction.context.project_state.modified_files.items) |file| {
                self.allocator.free(file);
            }
            interaction.context.project_state.modified_files.deinit();
            if (interaction.context.project_state.active_file) |file| {
                self.allocator.free(file);
            }

            // Free action
            self.allocator.free(interaction.action.content);
            var it = interaction.action.parameters.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            interaction.action.parameters.deinit();

            // Free result
            for (interaction.result.changes.items) |change| {
                self.allocator.free(change.file_path);
                self.allocator.free(change.content);
            }
            interaction.result.changes.deinit();
            if (interaction.result.errors) |errors| {
                for (errors.items) |err| {
                    self.allocator.free(err.message);
                }
                errors.deinit();
            }

            // Free metadata
            self.allocator.free(interaction.metadata.os_info);
            self.allocator.free(interaction.metadata.zig_version);
            self.allocator.free(interaction.metadata.session_id);
        }
        self.interactions.deinit();
        self.buffer.deinit();
    }

    pub fn record(self: *Self, context: Context, action: Action) !void {
        const timestamp = std.time.timestamp();
        
        // Create result placeholder
        var result = Result{
            .success = false,
            .changes = std.ArrayList(Change).init(self.allocator),
            .errors = null,
            .performance_metrics = null,
        };

        // Create metadata
        const metadata = try self.createMetadata();

        // Create and store interaction
        const interaction = Interaction{
            .timestamp = @intCast(timestamp),
            .context = context,
            .action = action,
            .result = result,
            .metadata = metadata,
        };

        try self.interactions.append(interaction);
    }

    fn createMetadata(self: *Self) !Metadata {
        // Get OS info
        const os_info = try std.fmt.allocPrint(self.allocator, "ArchLinux {s}", .{std.os.uname().release});

        // Get Zig version
        const zig_version = try std.fmt.allocPrint(self.allocator, "{s}", .{std.builtin.zig_version_string});

        // Generate session ID
        var session_id_buf: [36]u8 = undefined;
        const session_id = try std.fmt.bufPrint(&session_id_buf, "{s}", .{std.crypto.random.uuid()});

        return Metadata{
            .os_info = os_info,
            .zig_version = zig_version,
            .timestamp = @intCast(std.time.timestamp()),
            .session_id = try self.allocator.dupe(u8, &session_id_buf),
        };
    }

    pub fn analyzeInteraction(self: *Self, interaction: Interaction) !void {
        // TODO: Implement interaction analysis
        _ = interaction;
    }

    pub fn getInteractions(self: *Self) []const Interaction {
        return self.interactions.items;
    }

    pub fn clearInteractions(self: *Self) void {
        for (self.interactions.items) |interaction| {
            // Free all allocated memory
            self.allocator.free(interaction.context.file_path);
            if (interaction.context.selected_text) |text| {
                self.allocator.free(text);
            }
            self.allocator.free(interaction.context.surrounding_code);
            
            // Free project state
            for (interaction.context.project_state.modified_files.items) |file| {
                self.allocator.free(file);
            }
            interaction.context.project_state.modified_files.deinit();
            if (interaction.context.project_state.active_file) |file| {
                self.allocator.free(file);
            }

            // Free action
            self.allocator.free(interaction.action.content);
            var it = interaction.action.parameters.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            interaction.action.parameters.deinit();

            // Free result
            for (interaction.result.changes.items) |change| {
                self.allocator.free(change.file_path);
                self.allocator.free(change.content);
            }
            interaction.result.changes.deinit();
            if (interaction.result.errors) |errors| {
                for (errors.items) |err| {
                    self.allocator.free(err.message);
                }
                errors.deinit();
            }

            // Free metadata
            self.allocator.free(interaction.metadata.os_info);
            self.allocator.free(interaction.metadata.zig_version);
            self.allocator.free(interaction.metadata.session_id);
        }
        self.interactions.clearRetainingCapacity();
    }
}; 