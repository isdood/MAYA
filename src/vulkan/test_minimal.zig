const std = @import("std");
const c = @cImport({
    @cDefine("VK_USE_PLATFORM_XCB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});

pub fn main() !void {
    std.debug.print("=== Starting minimal Vulkan test ===\n", .{});
    
    // Try to get Vulkan version
    var instance_version: u32 = 0;
    const version_result = c.vkEnumerateInstanceVersion(&instance_version);
    
    if (version_result == c.VK_SUCCESS) {
        const major = c.VK_API_VERSION_MAJOR(instance_version);
        const minor = c.VK_API_VERSION_MINOR(instance_version);
        const patch = c.VK_API_VERSION_PATCH(instance_version);
        std.debug.print("Vulkan {}.{}.{} is available\n", .{major, minor, patch});
    } else {
        std.debug.print("Failed to get Vulkan version: {}\n", .{version_result});
    }
}
