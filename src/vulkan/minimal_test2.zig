const std = @import("std");
const vk = @import("vk.zig");

pub fn main() !void {
    std.debug.print("=== Minimal Vulkan Test 2 ===\n", .{});
    
    // Try to get Vulkan API version
    var api_version: u32 = 0;
    std.debug.print("Calling vkEnumerateInstanceVersion...\n", .{});
    const vk_result = vk.vkEnumerateInstanceVersion(&api_version);
    
    if (vk_result == vk.VK_SUCCESS) {
        const major = vk.VK_API_VERSION_MAJOR(api_version);
        const minor = vk.VK_API_VERSION_MINOR(api_version);
        const patch = vk.VK_API_VERSION_PATCH(api_version);
        std.debug.print("Vulkan API version: {}.{}.{}\n", .{major, minor, patch});
    } else {
        std.debug.print("Failed to get Vulkan API version: {}\n", .{vk_result});
    }
    
    // Create application info
    std.debug.print("\nCreating application info...\n", .{});
    const app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Minimal Vulkan Test",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.VK_MAKE_VERSION(1, 0, 0), // Use Vulkan 1.0 for maximum compatibility
    };
    
    // Create instance with no extensions or layers
    std.debug.print("Creating Vulkan instance...\n", .{});
    const create_info = vk.VkInstanceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    };
    
    var instance: vk.VkInstance = undefined;
    std.debug.print("Calling vkCreateInstance...\n", .{});
    const result = vk.vkCreateInstance(&create_info, null, &instance);
    
    if (result == vk.VK_SUCCESS) {
        std.debug.print("Successfully created Vulkan instance!\n", .{});
        
        // Clean up
        vk.vkDestroyInstance(instance, null);
    } else {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
        return error.FailedToCreateVulkanInstance;
    }
    
    std.debug.print("Test completed.\n", .{});
}
