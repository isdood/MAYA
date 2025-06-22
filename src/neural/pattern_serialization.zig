// 🗂️ MAYA Pattern Serialization
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-22
// 👤 Author: isdood

const std = @import("std");
const Allocator = std.mem.Allocator;
const Pattern = @import("pattern.zig").Pattern;
const PatternGenerator = @import("pattern_generator.zig").PatternGenerator;

/// Pattern file format version
const PATTERN_FILE_VERSION: u32 = 1;

/// Pattern file header
const PatternHeader = packed struct {
    magic: [4]u8 = .{ 'M', 'P', 'A', 'T' },  // Magic number "MPAT"
    version: u32,                            // File format version
    width: u32,                              // Pattern width in pixels
    height: u32,                             // Pattern height in pixels
    channels: u8,                            // Number of color channels (1=grayscale, 3=RGB, 4=RGBA)
    pattern_type: u8,                        // Pattern type (enum)
    _reserved: [2]u8 = .{0, 0},             // Reserved for future use
    complexity: f64,                         // Pattern complexity (0.0 to 1.0)
    stability: f64,                          // Pattern stability (0.0 to 1.0)
};

/// Save a pattern to a binary file
pub fn savePatternToFile(allocator: Allocator, pattern: *const Pattern, file_path: []const u8) !void {
    _ = allocator; // Not used yet, but will be needed for future allocations
    // Open or create the output file
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    // Create a buffered writer for better performance
    var buffered_writer = std.io.bufferedWriter(file.writer());
    const writer = buffered_writer.writer();

    // Write the header
    const header = PatternHeader{
        .version = PATTERN_FILE_VERSION,
        .width = @intCast(pattern.dimensions[0]),
        .height = @intCast(pattern.dimensions[1]),
        .channels = 1,  // Default to grayscale for now
        .pattern_type = @intFromEnum(pattern.pattern_type),
        .complexity = pattern.complexity,
        .stability = pattern.stability,
    };

    // Write header
    try writer.writeAll(std.mem.asBytes(&header));
    
    // Write pattern data
    try writer.writeAll(pattern.data);
    
    // Flush the buffer to ensure all data is written
    try buffered_writer.flush();
}

/// Load a pattern from a file
pub fn loadPatternFromFile(allocator: Allocator, file_path: []const u8) !*Pattern {
    // Open the input file
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    // Create a buffered reader for better performance
    var buffered_reader = std.io.bufferedReader(file.reader());
    const reader = buffered_reader.reader();

    // Read and validate the header
    const header = try reader.readStruct(PatternHeader);
    
    // Validate magic number
    if (!std.mem.eql(u8, &header.magic, "MPAT")) {
        return error.InvalidFileFormat;
    }
    
    // Check version compatibility
    if (header.version != PATTERN_FILE_VERSION) {
        return error.UnsupportedFileVersion;
    }

    // Create a new pattern with the dimensions from the file
    const pattern = try Pattern.init(
        allocator,
        try allocator.alloc(u8, header.width * header.height * header.channels),
        header.width,
        header.height
    );
    
    // Read the pattern data
    _ = try reader.readAll(pattern.data);
    
    // Set pattern properties
    pattern.pattern_type = @enumFromInt(header.pattern_type);
    pattern.complexity = header.complexity;
    pattern.stability = header.stability;
    
    return pattern;
}

/// Serialize a pattern to a JSON string
pub fn serializeToJson(allocator: Allocator, pattern: *const Pattern) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    
    const writer = buffer.writer();
    
    try std.json.stringify(.{
        .width = pattern.dimensions[0],
        .height = pattern.dimensions[1],
        .channels = 1,  // Default to grayscale for now
        .pattern_type = @tagName(pattern.pattern_type),
        .complexity = pattern.complexity,
        .stability = pattern.stability,
        .data = std.fmt.fmtSliceHexLower(pattern.data),
    }, .{}, writer);
    
    return buffer.toOwnedSlice();
}

/// Deserialize a pattern from a JSON string
pub fn deserializeFromJson(allocator: Allocator, json_str: []const u8) !*Pattern {
    const parsed = try std.json.parseFromSlice(
        struct {
            width: u32,
            height: u32,
            channels: u8,
            pattern_type: []const u8,
            complexity: f64,
            stability: f64,
            data: []const u8,
        },
        allocator,
        json_str,
        .{ .allocate = .alloc_always },
    );
    defer parsed.deinit();
    
    // Parse pattern type
    const pattern_type = std.meta.stringToEnum(Pattern.PatternType, parsed.value.pattern_type) orelse .Unknown;
    
    // Convert hex data back to binary
    const data = try allocator.alloc(u8, parsed.value.data.len / 2);
    _ = try std.fmt.hexToBytes(data, parsed.value.data);
    
    // Create and return the pattern
    const pattern = try Pattern.init(allocator, data, parsed.value.width, parsed.value.height);
    pattern.pattern_type = pattern_type;
    pattern.complexity = parsed.value.complexity;
    pattern.stability = parsed.value.stability;
    
    return pattern;
}

// Tests
const testing = std.testing;

test "pattern serialization roundtrip" {
    const allocator = testing.allocator;
    
    // Create a test pattern
    const width: u32 = 32;
    const height: u32 = 32;
    const data = try allocator.alloc(u8, width * height);
    defer allocator.free(data);
    
    // Fill with test data
    for (data, 0..) |*byte, i| {
        byte.* = @truncate(i);
    }
    
    const pattern = try Pattern.init(allocator, data, width, height);
    defer pattern.deinit(allocator);
    
    pattern.pattern_type = .Visual;
    pattern.complexity = 0.75;
    pattern.stability = 0.85;
    
    // Test file serialization
    const test_file = "test_pattern.mpat";
    defer std.fs.cwd().deleteFile(test_file) catch {};
    
    try savePatternToFile(allocator, pattern, test_file);
    const loaded_pattern = try loadPatternFromFile(allocator, test_file);
    defer loaded_pattern.deinit(allocator);
    
    try testing.expectEqual(pattern.dimensions[0], loaded_pattern.dimensions[0]);
    try testing.expectEqual(pattern.dimensions[1], loaded_pattern.dimensions[1]);
    try testing.expectEqual(pattern.pattern_type, loaded_pattern.pattern_type);
    try testing.expectEqual(pattern.complexity, loaded_pattern.complexity);
    try testing.expectEqual(pattern.stability, loaded_pattern.stability);
    try testing.expectEqualSlices(u8, pattern.data, loaded_pattern.data);
    
    // Test JSON serialization
    const json_str = try serializeToJson(allocator, pattern);
    defer allocator.free(json_str);
    
    const json_pattern = try deserializeFromJson(allocator, json_str);
    defer json_pattern.deinit(allocator);
    
    try testing.expectEqual(pattern.dimensions[0], json_pattern.dimensions[0]);
    try testing.expectEqual(pattern.dimensions[1], json_pattern.dimensions[1]);
    try testing.expectEqual(pattern.pattern_type, json_pattern.pattern_type);
    try testing.expectEqual(pattern.complexity, json_pattern.complexity);
    try testing.expectEqual(pattern.stability, json_pattern.stability);
    try testing.expectEqualSlices(u8, pattern.data, json_pattern.data);
}
