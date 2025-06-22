const std = @import("std");
const pattern_serialization = @import("pattern_serialization.zig");

pub const Pattern = struct {
    /// The pixel data of the pattern
    data: []u8,
    /// Width of the pattern in pixels
    width: usize,
    /// Height of the pattern in pixels
    height: usize,
    /// Type of the pattern
    pattern_type: PatternType,
    /// Complexity score of the pattern (0.0 to 1.0)
    complexity: f64,
    /// Stability score of the pattern (0.0 to 1.0)
    stability: f64,
    /// Allocator used for this pattern's memory
    allocator: std.mem.Allocator,

    pub const PatternType = enum {
        Quantum,
        Visual,
        Hybrid,
        Unknown,
    };

    /// Initialize a new pattern with the given data and dimensions
    pub fn init(allocator: std.mem.Allocator, data: []const u8, width: usize, height: usize) !*Pattern {
        const self = try allocator.create(Pattern);
        self.* = .{
            .data = try allocator.dupe(u8, data),
            .width = width,
            .height = height,
            .pattern_type = .Unknown,
            .complexity = 0.0,
            .stability = 0.0,
            .allocator = allocator,
        };
        return self;
    }

    /// Initialize a new pattern with the given dimensions and channels
    pub fn initPattern(allocator: std.mem.Allocator, width: u32, height: u32, channels: u8) !*Pattern {
        const size = @as(usize, width) * @as(usize, height) * @as(usize, channels);
        const data = try allocator.alloc(u8, size);
        
        const pattern = try allocator.create(Pattern);
        pattern.* = .{
            .data = data,
            .width = @as(usize, @intCast(width)),
            .height = @as(usize, @intCast(height)),
            .pattern_type = .Visual,
            .complexity = 0.0,
            .stability = 0.0,
            .allocator = allocator,
        };
        
        return pattern;
    }

    pub fn deinit(self: *Pattern, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        allocator.destroy(self);
    }

    pub fn analyze(self: *Pattern) void {
        // Basic pattern analysis placeholder
        self.complexity = calculateComplexity(self.data);
        self.stability = calculateStability(self.data);
    }

    fn calculateComplexity(data: []const u8) f64 {
        // Placeholder complexity calculation
        return @as(f64, @floatFromInt(data.len)) / 100.0;
    }

    fn calculateStability(data: []const u8) f64 {
        // Placeholder stability calculation
        var sum: u32 = 0;
        for (data) |byte| {
            sum += byte;
        }
        return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(data.len));
    }

    /// Save the pattern to a file
    pub fn saveToFile(self: *const Pattern, file_path: []const u8) !void {
        try pattern_serialization.savePatternToFile(self.allocator, self, file_path);
    }

    /// Load a pattern from a file
    pub fn loadFromFile(allocator: std.mem.Allocator, file_path: []const u8) !*Pattern {
        return try pattern_serialization.loadPatternFromFile(allocator, file_path);
    }

    /// Serialize the pattern to a JSON string
    pub fn toJson(self: *const Pattern) ![]const u8 {
        return try pattern_serialization.serializeToJson(self.allocator, self);
    }

    /// Deserialize a pattern from a JSON string
    pub fn fromJson(allocator: std.mem.Allocator, json_str: []const u8) !*Pattern {
        return try pattern_serialization.deserializeFromJson(allocator, json_str);
    }
};
