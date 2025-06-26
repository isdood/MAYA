const std = @import("std");

pub fn main() !void {
    std.debug.print("=== Vulkan System Check ===\n", .{});
    
    // Run vulkaninfo if available
    const result = std.ChildProcess.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{"vulkaninfo", "--summary"},
    }) catch |err| {
        std.debug.print("Failed to run vulkaninfo: {s}\n", .{@errorName(err)});
        std.debug.print("Make sure Vulkan is properly installed on your system.\n", .{});
        std.debug.print("On Ubuntu/Debian: sudo apt install vulkan-tools\n", .{});
        std.debug.print("On Fedora: sudo dnf install vulkan-tools\n", .{});
        std.debug.print("On Arch: sudo pacman -S vulkan-tools\n", .{});
        return;
    };
    
    std.debug.print("=== vulkaninfo Output ===\n{s}\n", .{result.stdout});
    
    // Check for common Vulkan ICDs
    std.debug.print("\n=== Checking Vulkan ICDs ===\n", .{});
    
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
                
                // Try to read the first line of the JSON file
                const file = dir.openFile(entry.name, .{}) catch continue;
                defer file.close();
                
                var buf: [1024]u8 = undefined;
                if (file.reader().readUntilDelimiterOrEof(&buf, '\n')) |first_line| {
                    std.debug.print("    {s}\n", .{first_line});
                } else |_| {}
            }
        }
        
        if (!found) {
            std.debug.print("no ICDs found\n", .{});
        }
    }
    
    std.debug.print("\n=== Environment Variables ===\n", .{});
    
    // Check important environment variables
    if (std.os.getenv("VK_LOADER_DEBUG")) |val| {
        std.debug.print("VK_LOADER_DEBUG={s}\n", .{val});
    } else {
        std.debug.print("VK_LOADER_DEBUG is not set\n", .{});
    }
    
    if (std.os.getenv("VK_ICD_FILENAMES")) |val| {
        std.debug.print("VK_ICD_FILENAMES={s}\n", .{val});
    } else {
        std.debug.print("VK_ICD_FILENAMES is not set\n", .{});
    }
    
    if (std.os.getenv("VK_LAYER_PATH")) |val| {
        std.debug.print("VK_LAYER_PATH={s}\n", .{val});
    } else {
        std.debug.print("VK_LAYER_PATH is not set\n", .{});
    }
    
    std.debug.print("\n=== GPU Information ===\n", .{});
    
    // Try to get GPU information using lspci
    const lspci_result = std.ChildProcess.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{"lspci", "-v", "-s", std.mem.trim(u8, std.os.getenv("DRI_PRIME") orelse "", " ")},
    }) catch |err| {
        std.debug.print("Failed to run lspci: {s}\n", .{@errorName(err)});
        return;
    };
    
    std.debug.print("{s}\n", .{lspci_result.stdout});
    
    std.debug.print("\n=== Vulkan Check Complete ===\n", .{});
}
