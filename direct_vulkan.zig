const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
    @cInclude("stdio.h");
});

// Vulkan types and constants
const VkResult = i32;
const VkInstance = *opaque {};
const VkAllocationCallbacks = opaque {};

// Vulkan version macro
fn VK_MAKE_VERSION(major: u32, minor: u32, patch: u32) u32 {
    return (major << 22) | (minor << 12) | patch;
}

// Vulkan structure types
const VK_STRUCTURE_TYPE_APPLICATION_INFO = 0;
const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;

// Vulkan structures
const VkApplicationInfo = extern struct {
    sType: u32,
    pNext: ?*const anyopaque,
    pApplicationName: [*:0]const u8,
    applicationVersion: u32,
    pEngineName: [*:0]const u8,
    engineVersion: u32,
    apiVersion: u32,
};

const VkInstanceCreateInfo = extern struct {
    sType: u32,
    pNext: ?*const anyopaque,
    flags: u32,
    pApplicationInfo: ?*const VkApplicationInfo,
    enabledLayerCount: u32,
    ppEnabledLayerNames: ?[*]const [*:0]const u8,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8,
};

// Vulkan result codes
const VK_SUCCESS = 0;
const VK_ERROR_OUT_OF_HOST_MEMORY = -1;
const VK_ERROR_OUT_OF_DEVICE_MEMORY = -2;
const VK_ERROR_INITIALIZATION_FAILED = -3;
const VK_ERROR_LAYER_NOT_PRESENT = -4;
const VK_ERROR_EXTENSION_NOT_PRESENT = -5;
const VK_ERROR_INCOMPATIBLE_DRIVER = -6;

// Function pointer types
const PFN_vkCreateInstance = fn (
    pCreateInfo: *const VkInstanceCreateInfo,
    pAllocator: ?*const VkAllocationCallbacks,
    pInstance: *VkInstance,
) callconv(.C) VkResult;

const PFN_vkDestroyInstance = fn (
    instance: VkInstance,
    pAllocator: ?*const VkAllocationCallbacks,
) callconv(.C) void;

const PFN_vkGetInstanceProcAddr = fn (
    instance: ?*anyopaque,
    pName: [*:0]const u8,
) callconv(.C) ?*anyopaque;

// Helper function to convert VkResult to string
fn vkResultToString(result: VkResult) [*:0]const u8 {
    return switch (result) {
        VK_SUCCESS => "VK_SUCCESS",
        VK_ERROR_OUT_OF_HOST_MEMORY => "VK_ERROR_OUT_OF_HOST_MEMORY",
        VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
        VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
        VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
        VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
        VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
        else => "UNKNOWN_VK_RESULT",
    };
}

pub fn main() !void {
    _ = c.printf("=== Vulkan Instance Creation Test ===\n");
    
    // Load the Vulkan library
    _ = c.printf("Loading libvulkan.so.1...\n");
    const libvulkan = c.dlopen("libvulkan.so.1", c.RTLD_LAZY | c.RTLD_LOCAL);
    if (libvulkan == null) {
        _ = c.printf("Failed to load libvulkan.so.1: %s\n", c.dlerror());
        return error.FailedToLoadVulkan;
    }
    defer _ = c.dlclose(libvulkan);
    _ = c.printf("Successfully loaded libvulkan.so.1\n");
    
    // Get the exported vkGetInstanceProcAddr function
    _ = c.printf("Getting vkGetInstanceProcAddr symbol...\n");
    const vkGetInstanceProcAddr_sym = c.dlsym(libvulkan, "vkGetInstanceProcAddr");
    if (vkGetInstanceProcAddr_sym == null) {
        _ = c.printf("Failed to get vkGetInstanceProcAddr symbol: %s\n", c.dlerror());
        return error.FailedToGetProcAddr;
    }
    
    const vkGetInstanceProcAddr = @as(
        *const PFN_vkGetInstanceProcAddr,
        @ptrCast(@alignCast(vkGetInstanceProcAddr_sym))
    );
    _ = c.printf("Got vkGetInstanceProcAddr at %p\n", vkGetInstanceProcAddr);
    
    // Get vkCreateInstance
    _ = c.printf("Getting vkCreateInstance...\n");
    const vkCreateInstance_sym = vkGetInstanceProcAddr(null, "vkCreateInstance");
    if (vkCreateInstance_sym == null) {
        _ = c.printf("Failed to get vkCreateInstance: %s\n", c.dlerror());
        return error.FailedToGetCreateInstance;
    }
    
    const vkCreateInstance = @as(
        *const PFN_vkCreateInstance,
        @ptrCast(@alignCast(vkCreateInstance_sym))
    );
    _ = c.printf("Got vkCreateInstance at %p\n", vkCreateInstance);
    
    // Prepare application info
    const app_info = VkApplicationInfo{
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Vulkan Test",
        .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = VK_MAKE_VERSION(1, 0, 0), // Use Vulkan 1.0 for maximum compatibility
    };
    
    // Create instance info
    const create_info = VkInstanceCreateInfo{
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    };

    // Create instance
    _ = c.printf("Creating Vulkan instance...\n");
    var instance: VkInstance = undefined;
    const result = vkCreateInstance(&create_info, null, &instance);
    
    if (result == VK_SUCCESS) {
        _ = c.printf("Successfully created Vulkan instance at %p\n", instance);
        
        // Get vkDestroyInstance
        _ = c.printf("Getting vkDestroyInstance...\n");
        const vkDestroyInstance_sym = vkGetInstanceProcAddr(instance, "vkDestroyInstance");
        if (vkDestroyInstance_sym == null) {
            _ = c.printf("Warning: Failed to get vkDestroyInstance: %s\n", c.dlerror());
            return error.FailedToGetDestroyInstance;
        }
        
        const vkDestroyInstance = @as(
            *const PFN_vkDestroyInstance,
            @ptrCast(@alignCast(vkDestroyInstance_sym))
        );
        _ = c.printf("Got vkDestroyInstance at %p\n", vkDestroyInstance);
        
        // Cleanup
        _ = c.printf("Destroying Vulkan instance...\n");
        vkDestroyInstance(instance, null);
        _ = c.printf("Vulkan instance destroyed\n");
        
        _ = c.printf("Test completed successfully\n");
    } else {
        _ = c.printf("Failed to create Vulkan instance: %s (0x%x)\n", vkResultToString(result), result);
        return error.FailedToCreateInstance;
    }
    
    return;
}