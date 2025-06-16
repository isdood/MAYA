const std = @import("std");
const print = std.debug.print;

pub const LanguageProcessor = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    patterns: std.ArrayList(Pattern),

    pub const Pattern = struct {
        name: []const u8,
        content: []const u8,
        metadata: ?[]const u8,
    };

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .patterns = std.ArrayList(Pattern).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.patterns.items) |pattern| {
            self.allocator.free(pattern.name);
            self.allocator.free(pattern.content);
            if (pattern.metadata) |metadata| {
                self.allocator.free(metadata);
            }
        }
        self.patterns.deinit();
    }

    pub fn addPattern(self: *Self, name: []const u8, content: []const u8, metadata: ?[]const u8) !void {
        const pattern = Pattern{
            .name = try self.allocator.dupe(u8, name),
            .content = try self.allocator.dupe(u8, content),
            .metadata = if (metadata) |m| try self.allocator.dupe(u8, m) else null,
        };
        try self.patterns.append(pattern);
    }

    pub fn processCommand(self: *Self, command: []const u8) !void {
        print("Processing command: {s}\n", .{command});
        
        // Basic command parsing
        var iterator = std.mem.split(u8, command, " ");
        const cmd = iterator.next() orelse return;
        
        if (std.mem.eql(u8, cmd, "add")) {
            const name = iterator.next() orelse return;
            const content = iterator.rest();
            try self.addPattern(name, content, null);
            print("Added pattern: {s}\n", .{name});
        } else if (std.mem.eql(u8, cmd, "list")) {
            print("Current patterns:\n", .{});
            for (self.patterns.items) |pattern| {
                print("- {s}: {s}\n", .{ pattern.name, pattern.content });
            }
        } else if (std.mem.eql(u8, cmd, "help")) {
            print("Available commands:\n", .{});
            print("  add <name> <content> - Add a new pattern\n", .{});
            print("  list - List all patterns\n", .{});
            print("  help - Show this help message\n", .{});
        } else {
            print("Unknown command: {s}\n", .{cmd});
            print("Type 'help' for available commands\n", .{});
        }
    }

    pub fn runTests(self: *Self) !void {
        print("\nMAYA Language Processor Test\n", .{});
        print("==========================\n\n", .{});

        // Test commands
        try self.processCommand("help");
        try self.processCommand("add test1 This is a test pattern");
        try self.processCommand("add test2 Another test pattern");
        try self.processCommand("list");
        try self.processCommand("unknown");
    }
}; 