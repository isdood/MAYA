const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const cwd = std.fs.cwd();

    // Define shader files to process
    const shader_files = [_][]const u8{
        "4d_tensor_operations_float.comp.spv",
        "4d_tensor_operations_int.comp.spv",
        "4d_tensor_operations_uint.comp.spv",
    };

    // Create output directory if it doesn't exist
    try cwd.makePath("src/vulkan/compute/generated");

    // Process each shader file
    for (shader_files) |shader_file| {
        const shader_path = try std.fs.path.join(allocator, &[_][]const u8{ "shaders", shader_file });
        defer allocator.free(shader_path);

        // Read shader file
        const shader_data = try cwd.readFileAlloc(allocator, shader_path, 10 * 1024 * 1024); // 10MB max
        defer allocator.free(shader_data);

        // Generate output filename
        const base_name = std.fs.path.stem(shader_file);
        const output_filename = try std.fmt.allocPrint(allocator, "{s}.zig", .{base_name});
        defer allocator.free(output_filename);
        
        const output_path = try std.fs.path.join(allocator, &[_][]const u8{ "src/vulkan/compute/generated", output_filename });
        defer allocator.free(output_path);

        // Create output file
        const output_file = try cwd.createFile(output_path, .{});
        defer output_file.close();

        // Write Zig byte array to file
        var writer = output_file.writer();
        try writer.print("pub const data = &[\\x00-\\x1F\\x7F-\\xFF]u8{{ ", .{});
        
        var i: usize = 0;
        for (shader_data) |byte| {
            if (i > 0) try writer.writeAll(", ");
            if (i % 16 == 0) try writer.writeAll("\\n    ");
            try writer.print("0x{x:0>2}", .{byte});
            i += 1;
        }
        
        try writer.writeAll("\n};\n");
    }
}
