const std = @import("std");
const c = @cImport({
    @cDefine("VK_USE_PLATFORM_XCB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});

pub fn main() !void {
    std.debug.print("=== Starting Vulkan test ===\n", .{});
    
    // Try to get Vulkan version
    var instance_version: u32 = 0;
    std.debug.print("Calling vkEnumerateInstanceVersion...\n", .{});
    const version_result = c.vkEnumerateInstanceVersion(&instance_version);
    
    if (version_result == c.VK_SUCCESS) {
        const major = c.VK_API_VERSION_MAJOR(instance_version);
        const minor = c.VK_API_VERSION_MINOR(instance_version);
        const patch = c.VK_API_VERSION_PATCH(instance_version);
        std.debug.print("Vulkan {}.{}.{} is available\n", .{major, minor, patch});
        
        // Try to create a Vulkan instance
        var app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Vulkan Test",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_0,
        };
        
        var create_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
        };
        
        var instance: c.VkInstance = undefined;
        std.debug.print("Calling vkCreateInstance...\n", .{});
        const create_result = c.vkCreateInstance(&create_info, null, &instance);
        
        if (create_result == c.VK_SUCCESS) {
            std.debug.print("Successfully created Vulkan instance!\n", .{});
            
            // Clean up
            c.vkDestroyInstance(instance, null);
            std.debug.print("Destroyed Vulkan instance\n", .{});
        } else {
            std.debug.print("Failed to create Vulkan instance: {}\n", .{create_result});
        }
    } else {
        std.debug.print("Failed to get Vulkan version: {}\n", .{version_result});
    }
}
