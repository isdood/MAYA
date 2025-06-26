const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    std.debug.print("=== System Information Test ===\n", .{});
    
    // Print basic system information
    std.debug.print("Zig version: {s}\n", .{builtin.zig_version_string});
    std.debug.print("Target OS: {s}\n", .{@tagName(builtin.target.os.tag)});
    std.debug.print("Target CPU Arch: {s}\n", .{@tagName(builtin.target.cpu.arch)});
    
    // Check for Vulkan ICDs using a shell command
    std.debug.print("\n=== Checking Vulkan Installation ===\n", .{});
    
    // Run vulkaninfo if available
    const result = std.ChildProcess.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{"vulkaninfo", "--summary"},
    }) catch |err| {
        std.debug.print("Failed to run vulkaninfo: {s}\n", .{@errorName(err)});
        std.debug.print("This suggests Vulkan may not be properly installed.\n", .{});
        return;
    };
    
    std.debug.print("vulkaninfo output (first 10 lines):\n", .{});
    var it = std.mem.tokenize(u8, result.stdout, "\n");
    var i: u32 = 0;
    while (it.next()) |line| : (i += 1) {
        if (i >= 10) break;
        std.debug.print("  {s}\n", .{line});
    }
    
    // Check for common Vulkan ICD locations
    std.debug.print("\n=== Checking Common Vulkan Paths ===\n", .{});
    
    const vulkan_paths = [_][]const u8{
        "/usr/share/vulkan/icd.d",
        "/usr/local/share/vulkan/icd.d",
        "/etc/vulkan/icd.d",
    };
    
    for (vulkan_paths) |path| {
        std.debug.print("Checking {s}... ", .{path});
        
        var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |err| {
            std.debug.print("not found ({s})\n", .{@errorName(err)});
            continue;
        };
        defer dir.close();
        
        var iter = dir.iterate();
        var found = false;
        
        while (iter.next() catch null) |entry| {
            if (std.mem.endsWith(u8, entry.name, ".json")) {
                if (!found) {
                    std.debug.print("found:\n", .{});
                    found = true;
                }
                std.debug.print("  {s}\n", .{entry.name});
            }
        }
        
        if (!found) {
            std.debug.print("no ICDs found\n", .{});
        }
    }
    
    std.debug.print("\nTest completed.\n", .{});
}
