const std = @import("std");
const vk = @import("vk.zig");

pub fn main() void {
    std.debug.print("=== Minimal Vulkan Test ===\n", .{});
    
    // Try to get the Vulkan API version
    std.debug.print("1. Getting Vulkan API version...\n", .{});
    
    var api_version: u32 = 0;
    std.debug.print("2. Before vkEnumerateInstanceVersion\n", .{});
    
    // Get the function pointer for vkEnumerateInstanceVersion
    const vkEnumerateInstanceVersionPtr = vk.vkGetInstanceProcAddr(null, "vkEnumerateInstanceVersion");
    std.debug.print("3. Got vkEnumerateInstanceVersion pointer: {*}\n", .{vkEnumerateInstanceVersionPtr});
    
    if (vkEnumerateInstanceVersionPtr == null) {
        std.debug.print("Failed to get vkEnumerateInstanceVersion function pointer\n", .{});
        return;
    }
    
    // Cast the function pointer
    const vkEnumerateInstanceVersion = @as(
        *const fn (*u32) callconv(.C) u32,
        @ptrCast(@alignCast(vkEnumerateInstanceVersionPtr)),
    );
    
    std.debug.print("4. Cast vkEnumerateInstanceVersion function pointer\n", .{});
    
    // Call the function
    std.debug.print("5. Calling vkEnumerateInstanceVersion...\n", .{});
    const result = vkEnumerateInstanceVersion(&api_version);
    std.debug.print("4. After vkEnumerateInstanceVersion, result: {}\n", .{result});
    
    if (result == vk.VK_SUCCESS) {
        const major = vk.VK_API_VERSION_MAJOR(api_version);
        const minor = vk.VK_API_VERSION_MINOR(api_version);
        const patch = vk.VK_API_VERSION_PATCH(api_version);
        std.debug.print("Vulkan API version: {}.{}.{}\n", .{major, minor, patch});
    } else {
        std.debug.print("Failed to get Vulkan version: {}\n", .{result});
    }
    
    // Try to create a minimal instance
    std.debug.print("\n5. Attempting to create Vulkan instance...\n", .{});
    
    const app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Minimal Vulkan Test",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.VK_MAKE_VERSION(1, 0, 0),
    };
    
    std.debug.print("6. Created app info\n", .{});
    
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
    
    std.debug.print("7. Created instance create info\n", .{});
    
    var instance: vk.VkInstance = undefined;
    std.debug.print("8. Before vkCreateInstance\n", .{});
    
    // Get the function pointer for vkCreateInstance
    const vkCreateInstancePtr = vk.vkGetInstanceProcAddr(null, "vkCreateInstance");
    std.debug.print("9. Got vkCreateInstance pointer: {*}\n", .{vkCreateInstancePtr});
    
    if (vkCreateInstancePtr == null) {
        std.debug.print("Failed to get vkCreateInstance function pointer\n", .{});
        return;
    }
    
    // Cast the function pointer
    const vkCreateInstance = @as(
        *const fn (*const vk.VkInstanceCreateInfo, ?*const vk.VkAllocationCallbacks, *vk.VkInstance) callconv(.C) vk.VkResult,
        @ptrCast(@alignCast(vkCreateInstancePtr)),
    );
    
    std.debug.print("10. Cast vkCreateInstance function pointer\n", .{});
    
    // Call the function
    std.debug.print("11. Calling vkCreateInstance...\n", .{});
    const create_result = vkCreateInstance(&create_info, null, &instance);
    std.debug.print("10. After vkCreateInstance, result: {}\n", .{create_result});
    
    if (create_result == vk.VK_SUCCESS) {
        std.debug.print("Successfully created Vulkan instance!\n", .{});
        
        // Get vkDestroyInstance
        const vkDestroyInstancePtr = vk.vkGetInstanceProcAddr(instance, "vkDestroyInstance");
        if (vkDestroyInstancePtr) |destroyFunc| {
            const vkDestroyInstance = @as(
                *const fn (vk.VkInstance, ?*const vk.VkAllocationCallbacks) callconv(.C) void,
                @ptrCast(@alignCast(destroyFunc)),
            );
            
            // Clean up
            std.debug.print("Cleaning up Vulkan instance...\n", .{});
            vkDestroyInstance(instance, null);
        } else {
            std.debug.print("Warning: Failed to get vkDestroyInstance function pointer\n", .{});
        }
        std.debug.print("Cleaned up Vulkan instance.\n", .{});
    } else {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{create_result});
    }
}
