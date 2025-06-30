const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const fs = std.fs;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const ChildProcess = std.process.Child;

const ShaderInfo = struct {
    const Kind = enum { compute, vertex, fragment };
    
    allocator: std.mem.Allocator,
    path: []const u8,
    name: []const u8,
    kind: Kind,
    
    pub fn deinit(self: *ShaderInfo) void {
        self.allocator.free(self.path);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    if (args.len < 3) {
        const stderr = std.io.getStdErr().writer();
        try stderr.writeAll("Usage: ");
        try stderr.writeAll(args[0]);
        try stderr.writeAll(" <input_dir> <output_dir>\n");
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
    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll("Found ");
    try std.fmt.formatInt(shaders.items.len, 10, .lower, .{}, stdout);
    try stdout.writeAll(" shaders to compile\n");

    // Compile each shader and ensure cleanup
    for (shaders.items) |*shader| {
        compileShader(allocator, shader.*, output_dir) catch |err| {
            // Clean up all shaders on error
            for (shaders.items) |*s| s.deinit();
            return err;
        };
    }
    
    // Clean up shader resources
    for (shaders.items) |*shader| {
        shader.deinit();
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
            // Create a copy of the path and name for the shader
            const shader_path = try std.fs.path.join(allocator, &[_][]const u8{dir_path, entry.name});
            
            // Create the shader info with the allocator for cleanup
            try shaders.append(ShaderInfo{
                .allocator = allocator,
                .path = shader_path,
                .name = entry.name[0 .. std.mem.lastIndexOfScalar(u8, entry.name, '.') orelse entry.name.len],
                .kind = k,
            });
        }
    }
}

fn compileShader(allocator: Allocator, shader: ShaderInfo, output_dir: []const u8) !void {
    // Simple string concatenation for output paths
    const output_spv = try std.fs.path.join(allocator, &[_][]const u8{
        output_dir,
        shader.name,
        ".spv"
    });
    defer allocator.free(output_spv);

    const output_zig = try std.fs.path.join(allocator, &[_][]const u8{
        output_dir,
        shader.name,
        ".zig"
    });
    defer allocator.free(output_zig);

    // Create output directory if it doesn't exist
    if (std.fs.path.dirname(output_spv)) |dir| {
        if (dir.len > 0) {
            // Split the path into components and create each directory one by one
            var it = std.mem.tokenizeScalar(u8, dir, '/');
            var current_path = std.ArrayList(u8).init(allocator);
            defer current_path.deinit();
            
            while (it.next()) |component| {
                if (current_path.items.len > 0) {
                    try current_path.append('/');
                }
                try current_path.appendSlice(component);
                
                std.fs.cwd().makeDir(current_path.items) catch |err| {
                    if (err != error.PathAlreadyExists) {
                        std.debug.print("Error: Failed to create directory {s}: {}\n", .{current_path.items, err});
                        return err;
                    }
                };
            }
        }
    }

    // Compile the shader
    std.debug.print("Compiling shader: {s} -> {s}\n", .{shader.path, output_spv});
    
    // Run glslc to compile the shader
    const argv = [_][]const u8{ "glslc", "--target-env=vulkan1.2", "-o", output_spv, shader.path };
    
    // Use the process API directly
    var child = ChildProcess.init(&argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    
    try child.spawn();
    
    // Read stdout
    const stdout = child.stdout.?.reader().readAllAlloc(allocator, 10 * 1024) catch |err| {
        std.debug.print("Failed to read stdout: {}\n", .{err});
        _ = child.kill() catch {};
        return error.ReadStdoutFailed;
    };
    defer allocator.free(stdout);
    
    // Read stderr
    const stderr_output = child.stderr.?.reader().readAllAlloc(allocator, 10 * 1024) catch |err| {
        std.debug.print("Failed to read stderr: {}\n", .{err});
        _ = child.kill() catch {};
        return error.ReadStderrFailed;
    };
    defer allocator.free(stderr_output);
    
    const term = try child.wait();
    
    // Check for errors
    if (term != .Exited or term.Exited != 0 or stderr_output.len > 0) {
        const stderr_writer = std.io.getStdErr().writer();
        
        // Print error header
        try stderr_writer.writeAll("\x1b[31mError: Failed to compile shader: ");
        try stderr_writer.print("{s}\n", .{shader.name});
        
        // Print the command that was run
        try stderr_writer.writeAll("Command: glslc --target-env=vulkan1.2 -o ");
        try stderr_writer.writeAll(output_spv);
        try stderr_writer.writeAll(" ");
        try stderr_writer.print("{s}\n", .{shader.path});
        
        // Print exit code if non-zero
        if (term != .Exited) {
            try stderr_writer.writeAll("Process terminated by signal\n");
        } else if (term.Exited != 0) {
            try stderr_writer.print("Exit code: {}\n", .{term.Exited});
        }
        
        // Print stderr if there was any output
        if (stderr_output.len > 0) {
            try stderr_writer.writeAll("Error output:\n");
            try stderr_writer.writeAll(stderr_output);
            try stderr_writer.writeAll("\n");
        }
        
        try stderr_writer.writeAll("\x1b[0m");
        return error.ShaderCompilationFailed;
    }

    // Read the compiled SPIR-V file
    const spv_file = try fs.cwd().openFile(output_spv, .{});
    defer spv_file.close();
    
    const spv_data = try spv_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(spv_data);

    // Generate Zig source file with the SPIR-V data
    var zig_file = try fs.cwd().createFile(output_zig, .{});
    defer zig_file.close();

    var writer = zig_file.writer();
    try writer.writeAll("//! Auto-generated from ");
    try writer.writeAll(shader.path);
    try writer.writeAll("\n//! DO NOT EDIT MANUALLY\n\n");
    try writer.writeAll("pub const data = [_]u8{\n    ");

    // Write bytes in chunks of 12 for better readability
    var i: usize = 0;
    while (i < spv_data.len) : (i += 1) {
        if (i > 0 and i % 12 == 0) {
            try writer.writeAll("\n    ");
        }
        // Format the byte as hex
        const byte = spv_data[i];
        const nibble_hi = byte >> 4;
        const nibble_lo = byte & 0xF;
        try writer.writeAll("0x");
        try writer.writeByte(if (nibble_hi < 10) '0' + @as(u8, @intCast(nibble_hi)) else 'a' + @as(u8, @intCast(nibble_hi - 10)));
        try writer.writeByte(if (nibble_lo < 10) '0' + @as(u8, @intCast(nibble_lo)) else 'a' + @as(u8, @intCast(nibble_lo - 10)));
        if (i < spv_data.len - 1) {
            try writer.writeAll(",");
        }
    }

    try writer.writeAll("\n};\n");
    
    // Log successful generation
    const stdout_writer = std.io.getStdOut().writer();
    try stdout_writer.writeAll("Generated ");
    try stdout_writer.writeAll(output_zig);
    try stdout_writer.writeAll("\n");
}
