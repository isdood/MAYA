const std = @import("std");

// Import Vulkan bindings using C import
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub fn main() !void {
    std.debug.print("=== Starting Minimal Vulkan Test ===\n", .{});
    
    // 1. Create application info
    std.debug.print("1. Creating application info...\n", .{});
    const app_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "MAYA Test",
        .applicationVersion = c.VK_MAKE_API_VERSION(0, 1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = c.VK_MAKE_API_VERSION(0, 1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
    };
    
    // 2. Create instance create info
    std.debug.print("2. Creating instance...\n", .{});
    const create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    };
    
    // 3. Create instance
    var instance: c.VkInstance = undefined;
    const result = c.vkCreateInstance(&create_info, null, @ptrCast(&instance));
    
    if (result != c.VK_SUCCESS) {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
        return error.VulkanInitFailed;
    }
    
    std.debug.print("3. Vulkan instance created successfully!\n", .{});
    
    // 4. Enumerate instance extensions
    var extension_count: u32 = 0;
    _ = c.vkEnumerateInstanceExtensionProperties(null, &extension_count, null);
    std.debug.print("4. Found {} instance extensions\n", .{extension_count});
    
    // 5. Enumerate physical devices
    var device_count: u32 = 0;
    _ = c.vkEnumeratePhysicalDevices(instance, &device_count, null);
    std.debug.print("5. Found {} physical devices\n", .{device_count});
    
    if (device_count > 0) {
        const devices = try std.heap.page_allocator.alloc(c.VkPhysicalDevice, @intCast(device_count));
        defer std.heap.page_allocator.free(devices);
        _ = c.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
        
        for (devices, 0..) |device, i| {
            var properties: c.VkPhysicalDeviceProperties = undefined;
            c.vkGetPhysicalDeviceProperties(device, &properties);
            std.debug.print("   Device {}: {s} (API {}.{}.{})\n", .{
                i,
                std.mem.span(@as([*:0]const u8, @ptrCast(&properties.deviceName))),
                c.VK_VERSION_MAJOR(properties.apiVersion),
                c.VK_VERSION_MINOR(properties.apiVersion),
                c.VK_VERSION_PATCH(properties.apiVersion),
            });
        }
    }
    
    // 6. Cleanup
    c.vkDestroyInstance(instance, null);
    std.debug.print("6. Cleaned up Vulkan resources\n", .{});
    
    std.debug.print("=== Test completed successfully! ===\n", .{});
}
