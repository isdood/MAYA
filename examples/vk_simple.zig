const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
    @cInclude("vulkan/vulkan.h");
});

const VkResult = c.VkResult;
const VkInstance = c.VkInstance;
const VkBuffer = c.VkBuffer;
const VkDeviceMemory = c.VkDeviceMemory;

// Function pointer types
const FnVkGetInstanceProcAddr = fn (instance: VkInstance, pName: [*:0]const u8) callconv(.C) ?*const anyopaque;
const FnVkCreateInstance = fn (pCreateInfo: *const c.VkInstanceCreateInfo, pAllocator: ?*const anyopaque, pInstance: *VkInstance) callconv(.C) VkResult;
const FnVkDestroyInstance = fn (instance: VkInstance, pAllocator: ?*const anyopaque) callconv(.C) void;
const FnVkCreateBuffer = fn (device: c.VkDevice, pCreateInfo: *const c.VkBufferCreateInfo, pAllocator: ?*const anyopaque, pBuffer: *VkBuffer) callconv(.C) VkResult;
const FnVkDestroyBuffer = fn (device: c.VkDevice, buffer: VkBuffer, pAllocator: ?*const anyopaque) callconv(.C) void;
const FnVkGetBufferMemoryRequirements = fn (device: c.VkDevice, buffer: VkBuffer, pMemoryRequirements: *c.VkMemoryRequirements) callconv(.C) void;
const FnVkGetPhysicalDeviceMemoryProperties = fn (physicalDevice: c.VkPhysicalDevice, pMemoryProperties: *c.VkPhysicalDeviceMemoryProperties) callconv(.C) void;
const FnVkAllocateMemory = fn (device: c.VkDevice, pAllocateInfo: *const c.VkMemoryAllocateInfo, pAllocator: ?*const anyopaque, pMemory: *VkDeviceMemory) callconv(.C) VkResult;
const FnVkFreeMemory = fn (device: c.VkDevice, memory: VkDeviceMemory, pAllocator: ?*const anyopaque) callconv(.C) void;
const FnVkBindBufferMemory = fn (device: c.VkDevice, buffer: VkBuffer, memory: VkDeviceMemory, memoryOffset: c.VkDeviceSize) callconv(.C) VkResult;
const FnVkMapMemory = fn (device: c.VkDevice, memory: VkDeviceMemory, offset: c.VkDeviceSize, size: c.VkDeviceSize, flags: c.VkMemoryMapFlags, ppData: *?*anyopaque) callconv(.C) VkResult;
const FnVkUnmapMemory = fn (device: c.VkDevice, memory: VkDeviceMemory) callconv(.C) void;

fn check(result: VkResult) !void {
    if (result != c.VK_SUCCESS) {
        std.debug.print("Vulkan error: {}\n", .{result});
        return error.VulkanError;
    }
}

pub fn main() !void {
    std.debug.print("Starting Vulkan memory example...\n", .{});
    
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
        .pApplicationName = "Vulkan Memory Example",
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
    defer {
        const vkDestroyInstance_ptr = vkGetInstanceProcAddr(instance, "vkDestroyInstance") orelse {
            std.debug.print("Warning: Failed to load vkDestroyInstance\n", .{});
            return;
        };
        const vkDestroyInstance: *const FnVkDestroyInstance = @ptrCast(vkDestroyInstance_ptr);
        vkDestroyInstance(instance, null);
    }
    
    std.debug.print("Successfully created Vulkan instance!\n", .{});
    
    // Load device-level functions
    const loadDeviceFunction = struct {
        fn load(instance: VkInstance, vkGetInstanceProcAddr: *const FnVkGetInstanceProcAddr, name: [*:0]const u8) ?*const anyopaque {
            return vkGetInstanceProcAddr(instance, name);
        }
    }.load;
    
    // For simplicity, we'll just demonstrate loading one function
    const vkCreateBuffer_ptr = loadDeviceFunction(instance, vkGetInstanceProcAddr, "vkCreateBuffer") orelse {
        std.debug.print("Failed to load vkCreateBuffer\n", .{});
        return error.FailedToLoadFunction;
    };
    const vkCreateBuffer: *const FnVkCreateBuffer = @ptrCast(vkCreateBuffer_ptr);
    
    std.debug.print("Successfully loaded vkCreateBuffer\n", .{});
    
    // Create a simple buffer
    const buffer_size = 1024; // 1KB
    const buffer_info = std.mem.zeroInit(c.VkBufferCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .size = buffer_size,
        .usage = c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
    });
    
    var buffer: VkBuffer = undefined;
    try check(vkCreateBuffer(null, &buffer_info, null, &buffer));
    defer {
        const vkDestroyBuffer_ptr = vkGetInstanceProcAddr(instance, "vkDestroyBuffer") orelse {
            std.debug.print("Warning: Failed to load vkDestroyBuffer\n", .{});
            return;
        };
        const vkDestroyBuffer: *const FnVkDestroyBuffer = @ptrCast(vkDestroyBuffer_ptr);
        vkDestroyBuffer(null, buffer, null);
    }
    
    std.debug.print("Successfully created buffer!\n", .{});
    
    // Get buffer memory requirements
    const vkGetBufferMemoryRequirements_ptr = loadDeviceFunction(instance, vkGetInstanceProcAddr, "vkGetBufferMemoryRequirements") orelse {
        std.debug.print("Failed to load vkGetBufferMemoryRequirements\n", .{});
        return error.FailedToLoadFunction;
    };
    const vkGetBufferMemoryRequirements: *const FnVkGetBufferMemoryRequirements = @ptrCast(vkGetBufferMemoryRequirements_ptr);
    
    var mem_requirements: c.VkMemoryRequirements = undefined;
    vkGetBufferMemoryRequirements(null, buffer, &mem_requirements);
    
    // Get memory properties
    const vkGetPhysicalDeviceMemoryProperties_ptr = vkGetInstanceProcAddr(instance, "vkGetPhysicalDeviceMemoryProperties") orelse {
        std.debug.print("Failed to load vkGetPhysicalDeviceMemoryProperties\n", .{});
        return error.FailedToLoadFunction;
    };
    const vkGetPhysicalDeviceMemoryProperties: *const FnVkGetPhysicalDeviceMemoryProperties = @ptrCast(vkGetPhysicalDeviceMemoryProperties_ptr);
    
    // Just to demonstrate, we'll print the memory type count
    var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    vkGetPhysicalDeviceMemoryProperties(null, &mem_properties);
    std.debug.print("Memory type count: {}\n", .{mem_properties.memoryTypeCount});
    
    std.debug.print("Vulkan memory example completed successfully!\n", .{});
}
