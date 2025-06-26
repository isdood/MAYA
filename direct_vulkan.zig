const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
    @cInclude("stdio.h");
});

// Vulkan types and constants
const VkResult = i32;
const VkInstance = *opaque {};
const VkAllocationCallbacks = opaque {};

// Vulkan constants
const VK_STRUCTURE_TYPE_APPLICATION_INFO = 0;
const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;

// Vulkan version macros
fn VK_MAKE_VERSION(major: u32, minor: u32, patch: u32) u32 {
    return (major << 22) | (minor << 12) | patch;
}

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
const PFN_vkCreateInstance = ?*const fn (
    pCreateInfo: *const VkInstanceCreateInfo,
    pAllocator: ?*const VkAllocationCallbacks,
    pInstance: *VkInstance,
) callconv(.C) VkResult;

const PFN_vkDestroyInstance = ?*const fn (
    instance: VkInstance,
    pAllocator: ?*const VkAllocationCallbacks,
) callconv(.C) void;

// Helper function to get a Vulkan function pointer
fn getVulkanFunction(comptime T: type, vkGetInstanceProcAddr: anytype, instance: ?*anyopaque, name: [*:0]const u8) ?T {
    return @as(T, @ptrCast(vkGetInstanceProcAddr.?(instance, name)));
}

// Helper function to get Vulkan result as string
fn vkResultToString(result: VkResult) []const u8 {
    return switch (result) {
        VK_SUCCESS => "VK_SUCCESS",
        VK_ERROR_OUT_OF_HOST_MEMORY => "VK_ERROR_OUT_OF_HOST_MEMORY",
        VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
        VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
        VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
        VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
        VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
        else => "UNKNOWN_VK_ERROR",
    };
}

pub fn main() !void {
    // Load the Vulkan library
    const libvulkan = c.dlopen("libvulkan.so.1", c.RTLD_LAZY | c.RTLD_LOCAL);
    if (libvulkan == null) {
        return error.FailedToLoadVulkan;
    }
    defer _ = c.dlclose(libvulkan);
    
    // Get vkGetInstanceProcAddr
    _ = c.printf("Getting vkGetInstanceProcAddr symbol...\n");
    const vkGetInstanceProcAddr_sym = c.dlsym(libvulkan, "vkGetInstanceProcAddr");
    if (vkGetInstanceProcAddr_sym == null) {
        _ = c.printf("Failed to get vkGetInstanceProcAddr symbol: %s\n", c.dlerror());
        return error.FailedToGetProcAddr;
    }
    
    _ = c.printf("Got vkGetInstanceProcAddr symbol at %p\n", vkGetInstanceProcAddr_sym);
    
    const vkGetInstanceProcAddr = @as(
        *const fn (?*anyopaque, [*:0]const u8) ?*anyopaque,
        @ptrCast(@alignCast(vkGetInstanceProcAddr_sym))
    );
    
    _ = c.printf("Cast vkGetInstanceProcAddr to function pointer\n");
    
    // Test the function pointer by getting a known function
    _ = c.printf("Testing vkGetInstanceProcAddr by getting vkEnumerateInstanceVersion...\n");
    const testFn = vkGetInstanceProcAddr(null, "vkEnumerateInstanceVersion");
    if (testFn == null) {
        _ = c.printf("Warning: Failed to get vkEnumerateInstanceVersion: %s\n", c.dlerror());
    } else {
        _ = c.printf("Successfully got vkEnumerateInstanceVersion at %p\n", testFn);
    }
    
    // Get vkEnumerateInstanceVersion
    var api_version: u32 = 0x00400000; // Default to Vulkan 1.0
    _ = c.printf("Getting vkEnumerateInstanceVersion...\n");
    const vkEnumerateInstanceVersionFn = vkGetInstanceProcAddr(
        null,
        "vkEnumerateInstanceVersion"
    );
    
    if (vkEnumerateInstanceVersionFn != null) {
        _ = c.printf("Got vkEnumerateInstanceVersionFn\n");
        const vkEnumerateInstanceVersion = @as(
            *const fn (*u32) callconv(.C) VkResult,
            @ptrCast(@alignCast(vkEnumerateInstanceVersionFn))
        );
        
        const result = vkEnumerateInstanceVersion(&api_version);
        if (result != VK_SUCCESS) {
            // Continue with default version
            api_version = 0x00400000; // Vulkan 1.0
        }
    }

    // Get vkCreateInstance
    _ = c.printf("Getting vkCreateInstance...\n");
    const vkCreateInstanceFn = vkGetInstanceProcAddr(
        null,
        "vkCreateInstance"
    );
    
    if (vkCreateInstanceFn != null) {
        _ = c.printf("Got vkCreateInstanceFn\n");
        const createInstance = @as(
            *const fn (*const VkInstanceCreateInfo, ?*const VkAllocationCallbacks, *VkInstance) callconv(.C) VkResult,
            @ptrCast(@alignCast(vkCreateInstanceFn))
        );
        
        // Prepare application info
        const app_info = VkApplicationInfo{
            .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "Vulkan Test",
            .applicationVersion = 1,
            .pEngineName = "No Engine",
            .engineVersion = 1,
            .apiVersion = api_version,
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
        var instance: VkInstance = undefined;
        const result = createInstance(&create_info, null, &instance);
        
        if (result == VK_SUCCESS) {
            // Cleanup
            defer {
                _ = c.printf("Getting vkDestroyInstance...\n");
                const vkDestroyInstanceFn = vkGetInstanceProcAddr(
                    instance,
                    "vkDestroyInstance"
                );
                
                if (vkDestroyInstanceFn != null) {
                    _ = c.printf("Got vkDestroyInstanceFn\n");
                    const vkDestroyInstance = @as(
                        *const fn (VkInstance, ?*const VkAllocationCallbacks) callconv(.C) void,
                        @ptrCast(@alignCast(vkDestroyInstanceFn))
                    );
                    vkDestroyInstance(instance, null);
                }
            }
            return; // Success
        } else {
            return error.FailedToCreateInstance;
        }
    } else {
        _ = c.printf("Failed to get vkCreateInstance\n");
        return error.FailedToGetCreateInstance;
    }
    
    return error.TestFailed;
}
