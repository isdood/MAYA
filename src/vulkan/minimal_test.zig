const std = @import("std");
const vk = @import("vk.zig");

pub fn main() !void {
    std.debug.print("=== Minimal Vulkan Test ===\n", .{});
    
    // Create application info
    const app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Minimal Vulkan Test",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.VK_API_VERSION_1_0,
    };
    
    // Create instance create info
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
    
    // Create instance
    std.debug.print("Creating Vulkan instance...\n", .{});
    var instance: vk.VkInstance = undefined;
    const result = vk.vkCreateInstance(&create_info, null, &instance);
    
    if (result == vk.VK_SUCCESS) {
        std.debug.print("Successfully created Vulkan instance!\n", .{});
        
        // Clean up
        vk.vkDestroyInstance(instance, null);
        std.debug.print("Vulkan instance destroyed.\n", .{});
    } else {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
        return error.InstanceCreationFailed;
    }
}
