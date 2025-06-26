const std = @import("std");
const vk = @import("vk.zig");
const debug_utils = @import("debug_utils.zig");

// Enable portability enumeration
const ENABLE_PORTABILITY = true;
const ENABLE_VALIDATION = true;
const PORTABILITY_EXTENSION = "VK_KHR_portability_enumeration";

// Required extensions
const required_extensions = [_][:0]const u8{
    "VK_KHR_surface",
    "VK_KHR_get_surface_capabilities2",
    "VK_KHR_get_physical_device_properties2",
};

// Required device extensions
const required_device_extensions = [_][:0]const u8{
    "VK_KHR_swapchain",
};

// Simple function to convert Vulkan result to string
fn vkResultToString(result: vk.VkResult) []const u8 {
    // Cast to i32 and compare directly
    const res = @as(i32, @bitCast(result));
    
    // Common success cases
    if (res == @as(i32, @bitCast(vk.VK_SUCCESS))) return "VK_SUCCESS";
    if (res == @as(i32, @bitCast(vk.VK_NOT_READY))) return "VK_NOT_READY";
    if (res == @as(i32, @bitCast(vk.VK_TIMEOUT))) return "VK_TIMEOUT";
    if (res == @as(i32, @bitCast(vk.VK_EVENT_SET))) return "VK_EVENT_SET";
    if (res == @as(i32, @bitCast(vk.VK_EVENT_RESET))) return "VK_EVENT_RESET";
    if (res == @as(i32, @bitCast(vk.VK_INCOMPLETE))) return "VK_INCOMPLETE";
    
    // Common error cases
    if (res == @as(i32, @bitCast(vk.VK_ERROR_OUT_OF_HOST_MEMORY))) return "VK_ERROR_OUT_OF_HOST_MEMORY";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_OUT_OF_DEVICE_MEMORY))) return "VK_ERROR_OUT_OF_DEVICE_MEMORY";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_INITIALIZATION_FAILED))) return "VK_ERROR_INITIALIZATION_FAILED";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_DEVICE_LOST))) return "VK_ERROR_DEVICE_LOST";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_MEMORY_MAP_FAILED))) return "VK_ERROR_MEMORY_MAP_FAILED";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_LAYER_NOT_PRESENT))) return "VK_ERROR_LAYER_NOT_PRESENT";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_EXTENSION_NOT_PRESENT))) return "VK_ERROR_EXTENSION_NOT_PRESENT";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_FEATURE_NOT_PRESENT))) return "VK_ERROR_FEATURE_NOT_PRESENT";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_INCOMPATIBLE_DRIVER))) return "VK_ERROR_INCOMPATIBLE_DRIVER";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_TOO_MANY_OBJECTS))) return "VK_ERROR_TOO_MANY_OBJECTS";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_FORMAT_NOT_SUPPORTED))) return "VK_ERROR_FORMAT_NOT_SUPPORTED";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_FRAGMENTED_POOL))) return "VK_ERROR_FRAGMENTED_POOL";
    if (res == @as(i32, @bitCast(vk.VK_ERROR_UNKNOWN))) return "VK_ERROR_UNKNOWN";
    
    // If we get here, it's an unknown result code
    return "Unknown VkResult";
}

// Helper function to check for required extensions
fn checkInstanceExtensions(available: []const vk.VkExtensionProperties, required: []const [*:0]const u8) !void {
    std.debug.print("Checking required instance extensions...\n", .{});
    
    for (required) |req_ext| {
        var found = false;
        const req_ext_slice = std.mem.span(req_ext);
        
        for (available) |ext| {
            const ext_name = std.mem.sliceTo(&ext.extensionName, 0);
            if (std.mem.eql(u8, ext_name, req_ext_slice)) {
                found = true;
                std.debug.print("  ✓ {s}\n", .{req_ext_slice});
                break;
            }
        }
        
        if (!found) {
            std.debug.print("  ✗ {s} (missing)\n", .{req_ext_slice});
            return error.MissingRequiredExtension;
        }
    }
}

// Helper function to get Vulkan API version string
fn getVulkanVersionString(version: u32) [32:0]u8 {
    const major = vk.VK_API_VERSION_MAJOR(version);
    const minor = vk.VK_API_VERSION_MINOR(version);
    const patch = vk.VK_API_VERSION_PATCH(version);
    
    var buffer: [32:0]u8 = undefined;
    _ = std.fmt.bufPrintZ(&buffer, "{d}.{d}.{d}", .{major, minor, patch}) catch "unknown";
    return buffer;
}

pub fn main() !void {
    std.debug.print("=== Minimal Vulkan Test ===\n\n", .{});
    
    // Initialize Vulkan loader
    std.debug.print("Initializing Vulkan loader...\n", .{});
    
    // Get Vulkan API version
    var api_version: u32 = 0;
    std.debug.print("Calling vkEnumerateInstanceVersion...\n", .{});
    const vk_result = vk.vkEnumerateInstanceVersion(&api_version);
    
    if (vk_result == vk.VK_SUCCESS) {
        const version_str = getVulkanVersionString(api_version);
        std.debug.print("Vulkan API version: {s}\n", .{version_str});
    } else {
        std.debug.print("Warning: Failed to get Vulkan API version: {s}, assuming 1.0.0\n", .{vkResultToString(vk_result)});
        api_version = vk.VK_MAKE_VERSION(1, 0, 0);
    }
    
    // Get available instance extensions
    std.debug.print("\nEnumerating instance extensions...\n", .{});
    var extension_count: u32 = 0;
    var enum_result = vk.vkEnumerateInstanceExtensionProperties(null, &extension_count, null);
    
    if (enum_result != vk.VK_SUCCESS and enum_result != vk.VK_INCOMPLETE) {
        std.debug.print("Failed to get instance extension count: {s}\n", .{vkResultToString(enum_result)});
        return error.FailedToGetInstanceExtensions;
    }
    
    std.debug.print("Found {} instance extensions\n", .{extension_count});
    
    const extensions = try std.heap.c_allocator.alloc(vk.VkExtensionProperties, extension_count);
    defer std.heap.c_allocator.free(extensions);
    
    enum_result = vk.vkEnumerateInstanceExtensionProperties(null, &extension_count, extensions.ptr);
    if (enum_result != vk.VK_SUCCESS) {
        std.debug.print("Failed to enumerate instance extensions: {s}\n", .{vkResultToString(enum_result)});
        return error.FailedToEnumerateInstanceExtensions;
    }
    
    // Enable required extensions
    std.debug.print("\nEnabling instance extensions...\n", .{});
    var enabled_extensions = std.ArrayList([*:0]const u8).init(std.heap.c_allocator);
    defer enabled_extensions.deinit();
    
    // Add required extensions
    for (required_extensions) |ext| {
        try enabled_extensions.append(ext);
        std.debug.print("  Enabled required extension: {s}\n", .{ext});
    }
    
    // Add portability extension if available and enabled
    if (ENABLE_PORTABILITY) {
        try enabled_extensions.append(PORTABILITY_EXTENSION);
        std.debug.print("  Enabled portability extension: {s}\n", .{PORTABILITY_EXTENSION});
    }
    
    // Add debug utils extension if validation is enabled
    if (ENABLE_VALIDATION) {
        try enabled_extensions.append("VK_EXT_debug_utils");
        std.debug.print("  Enabled debug utils extension: VK_EXT_debug_utils\n", .{});
    }
    
    // Print enabled extensions
    std.debug.print("\nEnabled instance extensions:\n", .{});
    for (enabled_extensions.items) |ext| {
        std.debug.print("  {s}\n", .{std.mem.span(ext)});
    }
    
    // Check if all required extensions are available
    try checkInstanceExtensions(extensions, enabled_extensions.items);
    
    // Create application info
    std.debug.print("\nCreating application info...\n", .{});
    const app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Minimal Vulkan Test",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = api_version,
    };
    std.debug.print("  Application: {s}\n", .{std.mem.span(app_info.pApplicationName)});
    std.debug.print("  Engine: {s}\n", .{std.mem.span(app_info.pEngineName)});
    std.debug.print("  API Version: {}.{}.{}\n", .{
        vk.VK_API_VERSION_MAJOR(app_info.apiVersion),
        vk.VK_API_VERSION_MINOR(app_info.apiVersion),
        vk.VK_API_VERSION_PATCH(app_info.apiVersion),
    });
    
    // Set up instance create flags
    var instance_flags: vk.VkInstanceCreateFlags = 0;
    if (ENABLE_PORTABILITY) {
        instance_flags |= @as(u32, vk.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR);
    }
    
    // Create instance
    std.debug.print("\nCreating Vulkan instance...\n", .{});
    std.debug.print("  Flags: 0x{x}\n", .{instance_flags});
    std.debug.print("  Enabled extensions ({}):\n", .{enabled_extensions.items.len});
    for (enabled_extensions.items) |ext| {
        std.debug.print("    {s}\n", .{std.mem.span(ext)});
    }
    
    const create_info = vk.VkInstanceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = instance_flags,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @intCast(enabled_extensions.items.len),
        .ppEnabledExtensionNames = if (enabled_extensions.items.len > 0) enabled_extensions.items.ptr else null,
    };
    
    std.debug.print("  Calling vkCreateInstance...\n", .{});
    var instance: vk.VkInstance = undefined;
    const result = vk.vkCreateInstance(&create_info, null, &instance);
    std.debug.print("  vkCreateInstance returned: {s}\n", .{vkResultToString(result)});
    
    if (result != vk.VK_SUCCESS) {
        std.debug.print("Failed to create Vulkan instance: {s}\n", .{vkResultToString(result)});
        return error.FailedToCreateVulkanInstance;
    }
    
    defer {
        std.debug.print("\nDestroying Vulkan instance...\n", .{});
        vk.vkDestroyInstance(instance, null);
    }
    
    std.debug.print("Successfully created Vulkan instance!\n", .{});
    
    // Enumerate physical devices
    var device_count: u32 = 0;
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
    
    if (device_count == 0) {
        std.debug.print("No Vulkan devices found!\n", .{});
        return error.NoVulkanDevicesFound;
    }
    
    std.debug.print("\nFound {} physical device(s):\n", .{device_count});
    
    const devices = try std.heap.c_allocator.alloc(vk.VkPhysicalDevice, device_count);
    defer std.heap.c_allocator.free(devices);
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
    
    // Print device information
    for (devices, 0..) |device, i| {
        var properties: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(device, &properties);
        
        const device_type = switch (properties.deviceType) {
            vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => "Integrated GPU",
            vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => "Discrete GPU",
            vk.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => "Virtual GPU",
            vk.VK_PHYSICAL_DEVICE_TYPE_CPU => "CPU",
            else => "Other",
        };
        
        const version_str = getVulkanVersionString(properties.apiVersion);
        
        std.debug.print("\nDevice {}: {s}\n", .{i, properties.deviceName});
        std.debug.print("  Type: {s}\n", .{device_type});
        std.debug.print("  API Version: {s}\n", .{version_str});
        std.debug.print("  Driver Version: {}.{}.{}\n", .{
            vk.VK_API_VERSION_MAJOR(properties.driverVersion),
            vk.VK_API_VERSION_MINOR(properties.driverVersion),
            vk.VK_API_VERSION_PATCH(properties.driverVersion),
        });
        std.debug.print("  Vendor ID: 0x{x:0>4}\n", .{properties.vendorID});
        std.debug.print("  Device ID: 0x{x:0>4}\n", .{properties.deviceID});
        
        // Print queue families
        var queue_family_count: u32 = 0;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);
        
        if (queue_family_count > 0) {
            const queue_families = try std.heap.c_allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
            defer std.heap.c_allocator.free(queue_families);
            
            vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);
            
            std.debug.print("  Queue Families ({}):\n", .{queue_family_count});
            for (queue_families, 0..) |queue_family, j| {
                var flags = std.ArrayList(u8).init(std.heap.c_allocator);
                defer flags.deinit();
                
                if (queue_family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                    try flags.appendSlice("GRAPHICS ");
                }
                if (queue_family.queueFlags & vk.VK_QUEUE_COMPUTE_BIT != 0) {
                    try flags.appendSlice("COMPUTE ");
                }
                if (queue_family.queueFlags & vk.VK_QUEUE_TRANSFER_BIT != 0) {
                    try flags.appendSlice("TRANSFER ");
                }
                if (queue_family.queueFlags & vk.VK_QUEUE_SPARSE_BINDING_BIT != 0) {
                    try flags.appendSlice("SPARSE_BINDING ");
                }
                
                std.debug.print("    {}: {} queues, flags: {s}\n", .{
                    j, 
                    queue_family.queueCount,
                    flags.items
                });
            }
        }
    }
    
    std.debug.print("\nTest completed.\n", .{});
}
