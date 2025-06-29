const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const ShaderInfo = struct {
    const Kind = enum { compute, vertex, fragment };
    
    path: []const u8,
    name: []const u8,
    kind: Kind,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    if (args.len < 3) {
        std.log.err("Usage: {} <input_dir> <output_dir>", .{args[0]});
        return error.InvalidArgs;
    }

    const input_dir = args[1];
    const output_dir = args[2];

    // Ensure output directory exists
    try fs.cwd().makePath(output_dir);

    // Find all shader files
    var shaders = ArrayList(ShaderInfo).init(allocator);
    defer shaders.deinit();

    try findShaders(allocator, input_dir, &shaders);
    std.log.info("Found {} shaders to compile", .{shaders.items.len});

    // Compile each shader
    for (shaders.items) |shader| {
        try compileShader(allocator, shader, output_dir);
    }
}

fn findShaders(allocator: Allocator, dir_path: []const u8, shaders: *ArrayList(ShaderInfo)) !void {
    var dir = try fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        
        const ext = fs.path.extension(entry.name);
        const kind = if (mem.eql(u8, ext, ".comp"))
            ShaderInfo.Kind.compute
        else if (mem.eql(u8, ext, ".vert"))
            ShaderInfo.Kind.vertex
        else if (mem.eql(u8, ext, ".frag"))
            ShaderInfo.Kind.fragment
        else
            null;

        if (kind) |k| {
            const shader_path = try fs.path.join(allocator, &[_][]const u8{dir_path, entry.name});
            const name = std.fs.path.stem(entry.name);
            try shaders.append(ShaderInfo{
                .path = shader_path,
                .name = try allocator.dupe(u8, name),
                .kind = k,
            });
        }
    }
}

fn compileShader(allocator: Allocator, shader: ShaderInfo, output_dir: []const u8) !void {
    const output_spv = try fs.path.join(allocator, &[_][]const u8{
        output_dir,
        try std.fmt.allocPrint(allocator, "{s}.spv", .{shader.name}),
    });
    defer allocator.free(output_spv);

    const output_zig = try fs.path.join(allocator, &[_][]const u8{
        output_dir,
        try std.fmt.allocPrint(allocator, "{s}.zig", .{shader.name}),
    });
    defer allocator.free(output_zig);

    // Compile GLSL to SPIR-V using glslangValidator
    const result = try process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "glslangValidator",
            "-V",
            "--target-env", "vulkan1.2",
            "-o", output_spv,
            shader.path,
        },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0) {
        std.log.err("Failed to compile shader {s}: {s}", .{ shader.path, result.stderr });
        return error.ShaderCompilationFailed;
    }

    // Read the compiled SPIR-V
    const spv_file = try fs.cwd().openFile(output_spv, .{});
    defer spv_file.close();

    const file_size = try spv_file.getEndPos();
    const spv_data = try allocator.alloc(u8, file_size);
    defer allocator.free(spv_data);
    _ = try spv_file.readAll(spv_data);

    // Generate Zig source file with the SPIR-V data
    var zig_file = try fs.cwd().createFile(output_zig, .{});
    defer zig_file.close();

    var writer = zig_file.writer();
    try writer.writeAll("//! Auto-generated from ");
    try writer.writeAll(shader.path);
    try writer.writeAll("\n");
    try writer.writeAll("//! DO NOT EDIT MANUALLY\n\n");

    // Write the SPIR-V data as a Zig array
    try writer.writeAll("pub const data = [_]u8{\n    ");

    // Write bytes in chunks of 12 for better readability
    for (spv_data, 0..) |byte, i| {
        if (i > 0 and i % 12 == 0) {
            try writer.writeAll("\n    ");
        }
        // Use a simple string conversion for the byte
        const byte_str = try std.fmt.allocPrint(allocator, "0x{x:0>2}", .{byte});
        defer allocator.free(byte_str);
        try writer.writeAll(byte_str);
        if (i < spv_data.len - 1) {
            try writer.writeAll(",");
        }
    }

    try writer.writeAll("\n};\n");
    
    // Simple debug output without formatting
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("Generated shader.zig\n");
}
