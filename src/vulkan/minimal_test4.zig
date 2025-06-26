const std = @import("std");
const vk = @import("vk.zig");

pub fn main() !void {
    std.debug.print("=== Minimal Vulkan Test with AMD GPU ===\n", .{});
    
    // Application info
    const app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Minimal Vulkan Test",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.VK_MAKE_VERSION(1, 0, 0),
    };
    
    // Instance create info
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
    
    // First, check if we can get the instance version
    var instance_version: u32 = 0;
    const version_result = vk.vkEnumerateInstanceVersion(&instance_version);
    if (version_result != vk.VK_SUCCESS) {
        std.debug.print("Failed to get Vulkan instance version: {}\n", .{version_result});
    } else {
        const major = vk.VK_API_VERSION_MAJOR(instance_version);
        const minor = vk.VK_API_VERSION_MINOR(instance_version);
        const patch = vk.VK_API_VERSION_PATCH(instance_version);
        std.debug.print("Vulkan instance version: {}.{}.{}\n", .{major, minor, patch});
    }
    
    // Try to create the instance with error handling
    var instance: vk.VkInstance = undefined;
    const result = vk.vkCreateInstance(&create_info, null, &instance);
    
    if (result != vk.VK_SUCCESS) {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
        
        // Try to get more detailed error information
        if (result == vk.VK_ERROR_LAYER_NOT_PRESENT) {
            std.debug.print("  Error: Requested layer not present\n", .{});
        } else if (result == vk.VK_ERROR_EXTENSION_NOT_PRESENT) {
            std.debug.print("  Error: Requested extension not present\n", .{});
        } else if (result == vk.VK_ERROR_INCOMPATIBLE_DRIVER) {
            std.debug.print("  Error: Incompatible Vulkan driver\n", .{});
        } else if (result == vk.VK_ERROR_INITIALIZATION_FAILED) {
            std.debug.print("  Error: Initialization failed\n", .{});
        }
        
        return error.FailedToCreateInstance;
    }
    
    std.debug.print("Successfully created Vulkan instance!\n", .{});
    
    // Enumerate physical devices
    std.debug.print("Enumerating physical devices...\n", .{});
    var device_count: u32 = 0;
    const enum_result = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
    
    if (enum_result != vk.VK_SUCCESS and enum_result != vk.VK_INCOMPLETE) {
        std.debug.print("Failed to enumerate physical devices: {}\n", .{enum_result});
        vk.vkDestroyInstance(instance, null);
        return error.FailedToEnumerateDevices;
    }
    
    if (device_count == 0) {
        std.debug.print("No Vulkan devices found!\n", .{});
        vk.vkDestroyInstance(instance, null);
        return error.NoPhysicalDevicesFound;
    }
    
    std.debug.print("Found {} Vulkan device(s):\n", .{device_count});
    
    const devices = try std.heap.page_allocator.alloc(vk.VkPhysicalDevice, device_count);
    defer std.heap.page_allocator.free(devices);
    
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
    
    for (devices, 0..) |device, i| {
        var properties: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(device, &properties);
        
        std.debug.print("  {d}: {s} (API: {}.{}.{})\n", .{
            i,
            &properties.deviceName,
            vk.VK_API_VERSION_MAJOR(properties.apiVersion),
            vk.VK_API_VERSION_MINOR(properties.apiVersion),
            vk.VK_API_VERSION_PATCH(properties.apiVersion),
        });
        
        // Print memory properties for the device
        var memory_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(device, &memory_properties);
        
        std.debug.print("    Memory Heaps: {}\n", .{memory_properties.memoryHeapCount});
        for (0..memory_properties.memoryHeapCount) |j| {
            const heap = memory_properties.memoryHeaps[j];
            const size_gb: f64 = @as(f64, @floatFromInt(heap.size)) / (1024 * 1024 * 1024);
            const flags = heap.flags;
            
            var buf: [256]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            var flags_str = std.ArrayList(u8).init(fba.allocator());
        
            if (flags & vk.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT != 0) {
                flags_str.appendSlice("DEVICE_LOCAL ") catch {};
            }
            if (flags & vk.VK_MEMORY_HEAP_MULTI_INSTANCE_BIT != 0) {
                flags_str.appendSlice("MULTI_INSTANCE ") catch {};
            }
            if (flags & vk.VK_MEMORY_HEAP_MULTI_INSTANCE_BIT_KHR != 0) {
                flags_str.appendSlice("MULTI_INSTANCE_KHR ") catch {};
            }
        
            std.debug.print("      Heap {}: {d:.2} GB, flags: {s}\n", .{
                j, size_gb, flags_str.items
            });
        }
    }
    
    // Clean up
    vk.vkDestroyInstance(instance, null);
    std.debug.print("Test completed successfully!\n", .{});
}
