const std = @import("std");
const process = std.process;
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Ensure glslangValidator is installed
    const glslang_result = try process.Child.run(.{
        .allocator = b.allocator,
        .argv = &[_][]const u8{ "glslangValidator", "--version" },
    });
    
    if (glslang_result.term.Exited != 0) {
        std.log.err("glslangValidator not found. Please install it (e.g., 'sudo apt install glslang-tools' on Debian/Ubuntu)", .{});
        return error.GlslangNotFound;
    }

    // Create output directory
    const shaders_dir = "shaders";
    const out_dir = "src/vulkan/compute/generated";
    
    try fs.cwd().makePath(out_dir);
    
    // Compile each shader
    const shader_exts = [_][]const u8{
        ".comp",
    };
    
    var dir = try fs.cwd().openDir(shaders_dir, .{ .iterate = true });
    defer dir.close();
    
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();
    
    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.path);
        
        // Check if this is a shader we want to compile
        var should_compile = false;
        for (shader_exts) |shader_ext| {
            if (mem.eql(u8, ext, shader_ext)) {
                should_compile = true;
                break;
            }
        }
        
        if (!should_compile) continue;
        
        const shader_name = entry.path[0 .. entry.path.len - ext.len];
        const input_path = try fs.path.join(b.allocator, &[_][]const u8{ shaders_dir, entry.path });
        const output_path = try fmt.allocPrint(b.allocator, "{s}/{s}.spv", .{ out_dir, entry.path });
        const output_zig = try fmt.allocPrint(b.allocator, "{s}/{s}.zig", .{ out_dir, entry.path });
        
        // Compile shader to SPIR-V
        const result = try process.Child.run(.{
            .allocator = b.allocator,
            .argv = &[_][]const u8{
                "glslangValidator",
                "-V",
                "--target-env", "vulkan1.2",
                "-o", output_path,
                input_path,
            },
        });
        
        if (result.term.Exited != 0) {
            std.log.err("Failed to compile shader {s}: {s}", .{ input_path, result.stderr });
            return error.ShaderCompilationFailed;
        }
        
        // Convert SPIR-V to Zig array
        const spv_file = try fs.cwd().openFile(output_path, .{});
        defer spv_file.close();
        
        const file_size = try spv_file.getEndPos();
        const spv_data = try b.allocator.alloc(u8, file_size);
        defer b.allocator.free(spv_data);
        _ = try spv_file.readAll(spv_data);
        
        // Generate Zig file with the SPIR-V data
        var zig_file = try fs.cwd().createFile(output_zig, .{});
        defer zig_file.close();
        
        try zig_file.writer().print(
            \// This file is auto-generated from {s}
            \// Do not edit manually
            \
            \pub const data = [_]u8{{
            \    
        , .{entry.path});
        
        // Write bytes in chunks of 12 for better readability
        var i: usize = 0;
        while (i < spv_data.len) : (i += 1) {
            if (i % 12 == 0) {
                try zig_file.writeAll("\n    ");
            }
            try zig_file.writer().print("0x{x:0>2},", .{spv_data[i]});
        }
        
        try zig_file.writeAll(
            \
            \};
            \
        );
        
        std.log.info("Compiled {s} -> {s}", .{ input_path, output_zig });
    }
}
