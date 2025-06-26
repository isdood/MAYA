// src/vulkan/minimal_amd.zig
const std = @import("std");
const vk = @import("vk.zig");



pub fn main() !void {
    std.debug.print("=== Minimal Vulkan Test with AMD GPU ===\n", .{});
    
    // Try with NULL application info first (simplest possible case)
    std.debug.print("Attempt 1: Creating instance with NULL application info...\n", .{});
    {
        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = null,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
        };
        
        std.debug.print("Calling vkCreateInstance...\n", .{});
        var instance: vk.VkInstance = undefined;
        const result = vk.vkCreateInstance(&create_info, null, &instance);
        
        if (result == vk.VK_SUCCESS) {
            std.debug.print("Successfully created Vulkan instance with NULL app info!\n", .{});
            vk.vkDestroyInstance(instance, null);
            return;
        } else {
            std.debug.print("Failed to create instance with NULL app info: {}\n", .{result});
        }
    }
    
    // If that fails, try with minimal application info
    std.debug.print("\nAttempt 2: Creating instance with minimal app info...\n", .{});
    {
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Minimal Vulkan Test",
            .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        };
        
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
        
        std.debug.print("Calling vkCreateInstance...\n", .{});
        var instance: vk.VkInstance = undefined;
        const result = vk.vkCreateInstance(&create_info, null, &instance);
        
        if (result == vk.VK_SUCCESS) {
            std.debug.print("Successfully created Vulkan instance with minimal app info!\n", .{});
            vk.vkDestroyInstance(instance, null);
            return;
        } else {
            std.debug.print("Failed to create instance with minimal app info: {}\n", .{result});
        }
    }
    
    // If we get here, both attempts failed
    std.debug.print("\nFailed to create Vulkan instance with any configuration.\n", .{});
    return error.FailedToCreateInstance;
}
