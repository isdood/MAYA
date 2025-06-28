const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
    @cInclude("vulkan/vulkan.h");
});

const VkResult = c.VkResult;
const VkInstance = c.VkInstance;

// Function pointer types
const FnVkGetInstanceProcAddr = fn (instance: VkInstance, pName: [*:0]const u8) callconv(.C) ?*const anyopaque;
const FnVkCreateInstance = fn (pCreateInfo: *const c.VkInstanceCreateInfo, pAllocator: ?*const anyopaque, pInstance: *VkInstance) callconv(.C) VkResult;
const FnVkDestroyInstance = fn (instance: VkInstance, pAllocator: ?*const anyopaque) callconv(.C) void;

fn check(result: VkResult) !void {
    if (result != c.VK_SUCCESS) {
        std.debug.print("Vulkan error: {}\n", .{result});
        return error.VulkanError;
    }
}

pub fn main() !void {
    std.debug.print("Starting Vulkan minimal working example...\n", .{});
    
    // Load Vulkan library
    const handle = c.dlopen("libvulkan.so.1", c.RTLD_NOW | c.RTLD_LOCAL) orelse {
        std.debug.print("Failed to load libvulkan.so.1: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    };
    defer _ = c.dlclose(handle);
    
    // Load vkGetInstanceProcAddr
    const vkGetInstanceProcAddr_ptr = c.dlsym(handle, "vkGetInstanceProcAddr") orelse {
        std.debug.print("Failed to load vkGetInstanceProcAddr: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    };
    
    const vkGetInstanceProcAddr: *const FnVkGetInstanceProcAddr = @ptrCast(vkGetInstanceProcAddr_ptr);
    
    // Load instance-level functions
    const vkCreateInstance_ptr = vkGetInstanceProcAddr(null, "vkCreateInstance") orelse {
        std.debug.print("Failed to load vkCreateInstance\n", .{});
        return error.FailedToLoadVulkan;
    };
    const vkCreateInstance: *const FnVkCreateInstance = @ptrCast(vkCreateInstance_ptr);
    
    // Create instance
    const app_info = std.mem.zeroInit(c.VkApplicationInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Vulkan Minimal Example",
        .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = c.VK_API_VERSION_1_0,
    });
    
    const instance_info = std.mem.zeroInit(c.VkInstanceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    });
    
    var instance: VkInstance = undefined;
    try check(vkCreateInstance(&instance_info, null, &instance));
    
    // Cleanup function
    const cleanup = struct {
        fn cleanupFn(inst: VkInstance, vkGetInstanceProcAddrFn: *const FnVkGetInstanceProcAddr) void {
            const vkDestroyInstance_ptr = vkGetInstanceProcAddrFn(inst, "vkDestroyInstance");
            if (vkDestroyInstance_ptr) |ptr| {
                const vkDestroyInstance: *const FnVkDestroyInstance = @ptrCast(ptr);
                vkDestroyInstance(inst, null);
                std.debug.print("Successfully destroyed Vulkan instance\n", .{});
            } else {
                std.debug.print("Warning: Failed to load vkDestroyInstance\n", .{});
            }
        }
    }.cleanupFn;
    
    // Ensure cleanup happens when we're done
    defer cleanup(instance, vkGetInstanceProcAddr);
    
    std.debug.print("Successfully created Vulkan instance!\n", .{});
    
    // Try to load a device-level function
    const vkCreateBuffer_ptr = vkGetInstanceProcAddr(instance, "vkCreateBuffer");
    if (vkCreateBuffer_ptr == null) {
        std.debug.print("Warning: Failed to load vkCreateBuffer\n", .{});
    } else {
        std.debug.print("Successfully loaded vkCreateBuffer\n", .{});
    }
    
    std.debug.print("Vulkan minimal working example completed successfully!\n", .{});
}
