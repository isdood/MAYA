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
    const handle = c.dlopen("libvulkan.so.1", c.RTLD_NOW | c.RTLD_LOCAL);
    if (handle == null) {
        const err = c.dlerror();
        std.debug.print("Failed to load libvulkan.so.1: {s}\n", .{@as([*:0]const u8, @ptrCast(err))});
        return error.FailedToLoadVulkan;
    }
    std.debug.print("Successfully loaded libvulkan.so.1\n", .{});
    
    // Load vkGetInstanceProcAddr
    const vkGetInstanceProcAddr = @as(
        fn (instance: VkInstance, pName: [*:0]const u8) callconv(.C) ?*const anyopaque,
        @ptrCast(c.dlsym(handle, "vkGetInstanceProcAddr")),
    );
    
    if (vkGetInstanceProcAddr == null) {
        std.debug.print("Failed to load vkGetInstanceProcAddr: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    }
    
    std.debug.print("Successfully loaded vkGetInstanceProcAddr\n", .{});
    
    // Load vkCreateInstance
    const vkCreateInstance = @as(
        fn (
            pCreateInfo: *const VkInstanceCreateInfo,
            pAllocator: ?*const anyopaque,
            pInstance: *VkInstance,
        ) callconv(.C) VkResult,
        @ptrCast(vkGetInstanceProcAddr(null, "vkCreateInstance")),
    );
    
    if (vkCreateInstance == null) {
        std.debug.print("Failed to load vkCreateInstance\n", .{});
        return error.FailedToLoadVulkan;
    }
    
    std.debug.print("Successfully loaded vkCreateInstance\n", .{});
    
    // Create application info
    const app_info = std.mem.zeroInit(VkApplicationInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Vulkan Debug",
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
        
        // Load vkDestroyInstance
        const vkDestroyInstance = @as(
            fn (instance: VkInstance, pAllocator: ?*const anyopaque) callconv(.C) void,
            @ptrCast(vkGetInstanceProcAddr(instance, "vkDestroyInstance")),
        );
        
        if (vkDestroyInstance) |destroyFn| {
            destroyFn(instance, null);
            std.debug.print("Successfully destroyed Vulkan instance\n", .{});
        } else {
            std.debug.print("Warning: Failed to load vkDestroyInstance\n", .{});
        }
    } else {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
    }
    
    // Close the library
    _ = c.dlclose(handle);
}

pub fn main() !void {
    std.debug.print("Starting Vulkan debug...\n", .{});
    try loadVulkan();
    std.debug.print("Vulkan debug completed\n", .{});
}
