const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
    @cInclude("vulkan/vulkan.h");
});

const VkResult = c.VkResult;
const VkInstance = c.VkInstance;
const VkApplicationInfo = c.VkApplicationInfo;
const VkInstanceCreateInfo = c.VkInstanceCreateInfo;

fn check(result: VkResult) !void {
    if (result != c.VK_SUCCESS) {
        std.debug.print("Vulkan error: {}\n", .{result});
        return error.VulkanError;
    }
}

fn loadVulkan() !void {
    // Try to load the Vulkan library
    std.debug.print("Loading libvulkan.so.1...\n", .{});
    const handle = c.dlopen("libvulkan.so.1", c.RTLD_NOW | c.RTLD_LOCAL);
    if (handle == null) {
        const err = c.dlerror();
        std.debug.print("Failed to load libvulkan.so.1: {s}\n", .{@as([*:0]const u8, @ptrCast(err))});
        return error.FailedToLoadVulkan;
    }
    std.debug.print("Successfully loaded libvulkan.so.1\n", .{});
    
    // Get the vkGetInstanceProcAddr function
    const vkGetInstanceProcAddr_ptr = c.dlsym(handle, "vkGetInstanceProcAddr");
    if (vkGetInstanceProcAddr_ptr == null) {
        std.debug.print("Failed to load vkGetInstanceProcAddr: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    }
    
    const vkGetInstanceProcAddr: *const fn (instance: VkInstance, pName: [*:0]const u8) callconv(.C) ?*const anyopaque = @ptrCast(vkGetInstanceProcAddr_ptr);
    std.debug.print("Successfully loaded vkGetInstanceProcAddr\n", .{});
    
    // Get vkCreateInstance
    const vkCreateInstance_ptr = vkGetInstanceProcAddr(null, "vkCreateInstance");
    if (vkCreateInstance_ptr == null) {
        std.debug.print("Failed to get vkCreateInstance\n", .{});
        return error.FailedToLoadVulkan;
    }
    
    const vkCreateInstance: *const fn (
        pCreateInfo: *const VkInstanceCreateInfo,
        pAllocator: ?*const anyopaque,
        pInstance: *VkInstance,
    ) callconv(.C) VkResult = @ptrCast(vkCreateInstance_ptr);
    
    std.debug.print("Successfully loaded vkCreateInstance\n", .{});
    
    // Create application info
    const app_info = std.mem.zeroInit(VkApplicationInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Vulkan Test",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
    });
    
    // Create instance info
    const instance_info = std.mem.zeroInit(VkInstanceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    });
    
    // Create instance
    var instance: VkInstance = undefined;
    std.debug.print("Calling vkCreateInstance...\n", .{});
    const result = vkCreateInstance(&instance_info, null, &instance);
    
    if (result == c.VK_SUCCESS) {
        std.debug.print("Successfully created Vulkan instance!\n", .{});
        
        // Get vkDestroyInstance
        const vkDestroyInstance_ptr = vkGetInstanceProcAddr(instance, "vkDestroyInstance") orelse {
            std.debug.print("Warning: Failed to get vkDestroyInstance\n", .{});
            return;
        };
        
        const vkDestroyInstance: *const fn (instance: VkInstance, pAllocator: ?*const anyopaque) callconv(.C) void = @ptrCast(vkDestroyInstance_ptr);
        
        vkDestroyInstance(instance, null);
        std.debug.print("Successfully destroyed Vulkan instance\n", .{});
    } else {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
    }
    
    // Close the library
    _ = c.dlclose(handle);
}

pub fn main() !void {
    std.debug.print("Starting Vulkan test...\n", .{});
    try loadVulkan();
    std.debug.print("Vulkan test completed\n", .{});
}
