const std = @import("std");
const c = @cImport({
    @cDefine("VK_USE_PLATFORM_XLIB_KHR", "1");
    @cInclude("dlfcn.h");
    @cInclude("vulkan/vulkan.h");
});

// Opaque handle types
const VkInstance = opaque {};
const VkAllocationCallbacks = opaque {};

// Function pointer types
const PFN_vkCreateInstance = *const fn(
    pCreateInfo: *const anyopaque,
    pAllocator: ?*const VkAllocationCallbacks,
    pInstance: **VkInstance
) callconv(.C) c_int;

const PFN_vkDestroyInstance = *const fn(
    instance: *VkInstance,
    pAllocator: ?*const VkAllocationCallbacks
) callconv(.C) void;

// Global function pointers
var g_vkCreateInstance: ?PFN_vkCreateInstance = null;
var g_vkDestroyInstance: ?PFN_vkDestroyInstance = null;

// Load Vulkan library and function pointers
fn loadVulkan() !void {
    // Try to load Vulkan library
    const lib = c.dlopen("libvulkan.so.1", c.RTLD_LAZY | c.RTLD_LOCAL);
    if (lib == null) {
        std.debug.print("Failed to load libvulkan.so.1: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    }
    
    // Get function pointers with explicit casting
    if (c.dlsym(lib, "vkCreateInstance")) |ptr| {
        g_vkCreateInstance = @ptrCast(ptr);
    } else {
        std.debug.print("Failed to get vkCreateInstance: {s}\n", .{c.dlerror()});
        return error.FailedToGetFunction;
    }
    
    if (c.dlsym(lib, "vkDestroyInstance")) |ptr| {
        g_vkDestroyInstance = @ptrCast(ptr);
    } else {
        std.debug.print("Warning: Failed to get vkDestroyInstance: {s}\n", .{c.dlerror()});
    }
}

pub fn main() !void {
    std.debug.print("1. Starting minimal Vulkan example...\n", .{});
    
    // 1. Application info
    const app_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "MinimalVulkan",
        .applicationVersion = c.VK_MAKE_API_VERSION(0, 1, 0, 0),
        .pEngineName = "NoEngine",
        .engineVersion = c.VK_MAKE_API_VERSION(0, 1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
    };
    
    std.debug.print("2. Created application info\n", .{});
    
    // 2. Instance create info
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
    
    std.debug.print("3. Created instance create info\n", .{});
    
    // 3. Create instance
    try loadVulkan();
    
    var instance: *VkInstance = undefined;
    std.debug.print("4. Creating Vulkan instance...\n", .{});
    
    std.debug.print("4.1. About to call vkCreateInstance...\n", .{});
    
    const result = g_vkCreateInstance.?(
        &create_info,
        null,
        &instance
    );
    std.debug.print("4.2. After vkCreateInstance call\n", .{});
    
    if (result != c.VK_SUCCESS) {
        std.debug.print("5. Failed to create Vulkan instance: {any}\n", .{result});
        printVulkanError(result);
        return error.FailedToCreateInstance;
    }
    
    std.debug.print("5. Successfully created Vulkan instance!\n", .{});
    
    // Cleanup
    if (g_vkDestroyInstance) |destroyFn| {
        destroyFn(instance, null);
    }
    std.debug.print("6. Cleaned up Vulkan instance\n", .{});
}

fn printVulkanError(result: c.VkResult) void {
    const error_str = switch (result) {
        c.VK_ERROR_OUT_OF_HOST_MEMORY => "VK_ERROR_OUT_OF_HOST_MEMORY",
        c.VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
        c.VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
        c.VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
        c.VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
        c.VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
        else => "Unknown error",
    };
    
    std.debug.print("Vulkan error: {any} ({s})\n", .{ result, error_str });
}
