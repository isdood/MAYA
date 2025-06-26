const std = @import("std");
const vk = @import("vk.zig");

// Simple function to convert Vulkan result to string
fn vkResultToString(result: vk.VkResult) []const u8 {
    return switch (result) {
        vk.VK_SUCCESS => "VK_SUCCESS",
        vk.VK_NOT_READY => "VK_NOT_READY",
        vk.VK_TIMEOUT => "VK_TIMEOUT",
        vk.VK_EVENT_SET => "VK_EVENT_SET",
        vk.VK_EVENT_RESET => "VK_EVENT_RESET",
        vk.VK_INCOMPLETE => "VK_INCOMPLETE",
        vk.VK_ERROR_OUT_OF_HOST_MEMORY => "VK_ERROR_OUT_OF_HOST_MEMORY",
        vk.VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
        vk.VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
        vk.VK_ERROR_DEVICE_LOST => "VK_ERROR_DEVICE_LOST",
        vk.VK_ERROR_MEMORY_MAP_FAILED => "VK_ERROR_MEMORY_MAP_FAILED",
        vk.VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
        vk.VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
        vk.VK_ERROR_FEATURE_NOT_PRESENT => "VK_ERROR_FEATURE_NOT_PRESENT",
        vk.VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
        vk.VK_ERROR_TOO_MANY_OBJECTS => "VK_ERROR_TOO_MANY_OBJECTS",
        vk.VK_ERROR_FORMAT_NOT_SUPPORTED => "VK_ERROR_FORMAT_NOT_SUPPORTED",
        vk.VK_ERROR_FRAGMENTED_POOL => "VK_ERROR_FRAGMENTED_POOL",
        vk.VK_ERROR_UNKNOWN => "VK_ERROR_UNKNOWN",
        else => @tagName(result),
    };
}

pub fn main() !void {
    std.debug.print("=== Minimal Vulkan Test ===\n", .{});
    
    // Use Vulkan 1.0 as the base version
    const api_version = vk.VK_MAKE_VERSION(1, 0, 0);
    std.debug.print("Using Vulkan API version: 1.0.0\n", .{});
    
    // Create application info
    const app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Minimal Vulkan Test",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = api_version,
    };
    
    // Try creating instance with different configurations
    const configs = [_]struct {
        name: []const u8,
        extensions: ?[]const [*:0]const u8,
    }{
        .{ .name = "No extensions", .extensions = null },
        .{ .name = "With VK_KHR_surface", .extensions = &[_][*:0]const u8{"VK_KHR_surface"} },
    };
    
    for (configs) |config| {
        std.debug.print("\nTrying configuration: {s}\n", .{config.name});
        
        const extension_count = if (config.extensions) |exts| @as(u32, @intCast(exts.len)) else 0;
        const extensions_ptr = if (config.extensions) |exts| @as([*]const [*:0]const u8, @ptrCast(exts.ptr)) else null;
        
        if (config.extensions != null) {
            std.debug.print("  Extensions:\n", .{});
            for (config.extensions.?) |ext| {
                std.debug.print("    {s}\n", .{std.mem.span(ext)});
            }
        } else {
            std.debug.print("  No extensions\n", .{});
        }
        
        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = extension_count,
            .ppEnabledExtensionNames = extensions_ptr,
        };
        
        var instance: vk.VkInstance = undefined;
        const result = vk.vkCreateInstance(&create_info, null, &instance);
        
        if (result == vk.VK_SUCCESS) {
            std.debug.print("  Successfully created Vulkan instance!\n", .{});
            
            // Get physical device count
            var device_count: u32 = 0;
            const enum_result = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
            
            if (enum_result == vk.VK_SUCCESS) {
                std.debug.print("  Found {} physical device(s)\n", .{device_count});
            } else {
                std.debug.print("  Warning: Failed to enumerate physical devices: {} ({s})\n", .{
                    enum_result, vkResultToString(enum_result)
                });
            }
            
            // Clean up
            vk.vkDestroyInstance(instance, null);
            std.debug.print("  Vulkan instance destroyed.\n", .{});
            
            // If we successfully created an instance, we can stop trying configurations
            break;
        } else {
            std.debug.print("  Failed to create Vulkan instance: {} ({s})\n", .{
                result, vkResultToString(result)
            });
            
            // If this was the last configuration, return an error
            if (config.name.len > 0 and config.name[config.name.len - 1] == '!') {
                return error.FailedToCreateVulkanInstance;
            }
        }
    }
    
    std.debug.print("\nTest completed.\n", .{});
}
