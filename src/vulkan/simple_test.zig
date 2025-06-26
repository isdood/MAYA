const std = @import("std");
const vk = @import("vk.zig");

pub fn main() void {
    std.debug.print("=== Simple Vulkan Test ===\n", .{});
    
    // Try to load the Vulkan library
    std.debug.print("1. Loading Vulkan library...\n", .{});
    
    // Try to get the instance version
    std.debug.print("2. Getting Vulkan instance version...\n", .{});
    
    var api_version: u32 = 0;
    const result = vk.vkEnumerateInstanceVersion(&api_version);
    
    if (result == vk.VK_SUCCESS) {
        const major = vk.VK_API_VERSION_MAJOR(api_version);
        const minor = vk.VK_API_VERSION_MINOR(api_version);
        const patch = vk.VK_API_VERSION_PATCH(api_version);
        std.debug.print("Vulkan API version: {}.{}.{}\n", .{major, minor, patch});
    } else {
        std.debug.print("Failed to get Vulkan version: {}\n", .{result});
    }
    
    std.debug.print("Test completed.\n", .{});
}
