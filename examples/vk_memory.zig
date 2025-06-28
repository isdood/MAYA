const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
    @cInclude("vulkan/vulkan.h");
});

const VkResult = c.VkResult;
const VkInstance = c.VkInstance;
const VkPhysicalDevice = c.VkPhysicalDevice;
const VkDevice = c.VkDevice;
const VkBuffer = c.VkBuffer;
const VkDeviceMemory = c.VkDeviceMemory;
const VkMemoryPropertyFlags = c.VkMemoryPropertyFlags;
const VkBufferUsageFlags = c.VkBufferUsageFlags;
const VkMemoryRequirements = c.VkMemoryRequirements;
const VkPhysicalDeviceMemoryProperties = c.VkPhysicalDeviceMemoryProperties;
const VkMemoryPropertyFlagBits = c.VkMemoryPropertyFlagBits;
const VkBufferUsageFlagBits = c.VkBufferUsageFlagBits;

// Function pointer types
type FnVkGetInstanceProcAddr = fn (instance: VkInstance, pName: [*:0]const u8) callconv(.C) ?*const anyopaque;
type FnVkCreateInstance = fn (pCreateInfo: *const c.VkInstanceCreateInfo, pAllocator: ?*const anyopaque, pInstance: *VkInstance) callconv(.C) VkResult;
type FnVkDestroyInstance = fn (instance: VkInstance, pAllocator: ?*const anyopaque) callconv(.C) void;
type FnVkEnumeratePhysicalDevices = fn (instance: VkInstance, pPhysicalDeviceCount: *u32, pPhysicalDevices: ?[*]VkPhysicalDevice) callconv(.C) VkResult;
type FnVkGetPhysicalDeviceProperties = fn (physicalDevice: VkPhysicalDevice, pProperties: *c.VkPhysicalDeviceProperties) callconv(.C) void;
type FnVkGetPhysicalDeviceQueueFamilyProperties = fn (physicalDevice: VkPhysicalDevice, pQueueFamilyPropertyCount: *u32, pQueueFamilyProperties: ?[*]c.VkQueueFamilyProperties) callconv(.C) void;
type FnVkCreateDevice = fn (physicalDevice: VkPhysicalDevice, pCreateInfo: *const c.VkDeviceCreateInfo, pAllocator: ?*const anyopaque, pDevice: *VkDevice) callconv(.C) VkResult;
type FnVkDestroyDevice = fn (device: VkDevice, pAllocator: ?*const anyopaque) callconv(.C) void;
type FnVkGetDeviceQueue = fn (device: VkDevice, queueFamilyIndex: u32, queueIndex: u32, pQueue: *c.VkQueue) callconv(.C) void;
type FnVkCreateBuffer = fn (device: VkDevice, pCreateInfo: *const c.VkBufferCreateInfo, pAllocator: ?*const anyopaque, pBuffer: *VkBuffer) callconv(.C) VkResult;
type FnVkDestroyBuffer = fn (device: VkDevice, buffer: VkBuffer, pAllocator: ?*const anyopaque) callconv(.C) void;
type FnVkGetBufferMemoryRequirements = fn (device: VkDevice, buffer: VkBuffer, pMemoryRequirements: *VkMemoryRequirements) callconv(.C) void;
type FnVkGetPhysicalDeviceMemoryProperties = fn (physicalDevice: VkPhysicalDevice, pMemoryProperties: *VkPhysicalDeviceMemoryProperties) callconv(.C) void;
type FnVkAllocateMemory = fn (device: VkDevice, pAllocateInfo: *const c.VkMemoryAllocateInfo, pAllocator: ?*const anyopaque, pMemory: *VkDeviceMemory) callconv(.C) VkResult;
type FnVkFreeMemory = fn (device: VkDevice, memory: VkDeviceMemory, pAllocator: ?*const anyopaque) callconv(.C) void;
type FnVkBindBufferMemory = fn (device: VkDevice, buffer: VkBuffer, memory: VkDeviceMemory, memoryOffset: c.VkDeviceSize) callconv(.C) VkResult;
type FnVkMapMemory = fn (device: VkDevice, memory: VkDeviceMemory, offset: c.VkDeviceSize, size: c.VkDeviceSize, flags: c.VkMemoryMapFlags, ppData: *?*anyopaque) callconv(.C) VkResult;
type FnVkUnmapMemory = fn (device: VkDevice, memory: VkDeviceMemory) callconv(.C) void;

const VulkanFunctions = struct {
    vkGetInstanceProcAddr: FnVkGetInstanceProcAddr,
    vkCreateInstance: FnVkCreateInstance,
    vkDestroyInstance: FnVkDestroyInstance,
    vkEnumeratePhysicalDevices: FnVkEnumeratePhysicalDevices,
    vkGetPhysicalDeviceProperties: FnVkGetPhysicalDeviceProperties,
    vkGetPhysicalDeviceQueueFamilyProperties: FnVkGetPhysicalDeviceQueueFamilyProperties,
    vkCreateDevice: FnVkCreateDevice,
    vkDestroyDevice: FnVkDestroyDevice,
    vkGetDeviceQueue: FnVkGetDeviceQueue,
    vkCreateBuffer: FnVkCreateBuffer,
    vkDestroyBuffer: FnVkDestroyBuffer,
    vkGetBufferMemoryRequirements: FnVkGetBufferMemoryRequirements,
    vkGetPhysicalDeviceMemoryProperties: FnVkGetPhysicalDeviceMemoryProperties,
    vkAllocateMemory: FnVkAllocateMemory,
    vkFreeMemory: FnVkFreeMemory,
    vkBindBufferMemory: FnVkBindBufferMemory,
    vkMapMemory: FnVkMapMemory,
    vkUnmapMemory: FnVkUnmapMemory,
};

const VulkanContext = struct {
    instance: VkInstance,
    physical_device: VkPhysicalDevice,
    device: VkDevice,
    queue: c.VkQueue,
    functions: VulkanFunctions,
    
    fn init() !@This() {
        std.debug.print("Initializing Vulkan...\n", .{});
        
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
        
        const vkGetInstanceProcAddr: FnVkGetInstanceProcAddr = @ptrCast(vkGetInstanceProcAddr_ptr);
        
        // Helper to load other Vulkan functions
        const getProc = struct {
            fn getProc(comptime T: type, name: [*:0]const u8) !T {
                const ptr = vkGetInstanceProcAddr(null, name) orelse {
                    std.debug.print("Failed to load {s}\n", .{name});
                    return error.FailedToLoadFunction;
                };
                return @ptrCast(ptr);
            }
        }.getProc;
        
        // Load instance-level functions
        const vkCreateInstance: FnVkCreateInstance = try getProc(FnVkCreateInstance, "vkCreateInstance");
        
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
        
        // Load remaining functions
        const functions = VulkanFunctions{
            .vkGetInstanceProcAddr = vkGetInstanceProcAddr,
            .vkCreateInstance = vkCreateInstance,
            .vkDestroyInstance = try getProc(FnVkDestroyInstance, "vkDestroyInstance"),
            .vkEnumeratePhysicalDevices = try getProc(FnVkEnumeratePhysicalDevices, "vkEnumeratePhysicalDevices"),
            .vkGetPhysicalDeviceProperties = try getProc(FnVkGetPhysicalDeviceProperties, "vkGetPhysicalDeviceProperties"),
            .vkGetPhysicalDeviceQueueFamilyProperties = try getProc(FnVkGetPhysicalDeviceQueueFamilyProperties, "vkGetPhysicalDeviceQueueFamilyProperties"),
            .vkCreateDevice = try getProc(FnVkCreateDevice, "vkCreateDevice"),
            .vkDestroyDevice = try getProc(FnVkDestroyDevice, "vkDestroyDevice"),
            .vkGetDeviceQueue = try getProc(FnVkGetDeviceQueue, "vkGetDeviceQueue"),
            .vkCreateBuffer = try getProc(FnVkCreateBuffer, "vkCreateBuffer"),
            .vkDestroyBuffer = try getProc(FnVkDestroyBuffer, "vkDestroyBuffer"),
            .vkGetBufferMemoryRequirements = try getProc(FnVkGetBufferMemoryRequirements, "vkGetBufferMemoryRequirements"),
            .vkGetPhysicalDeviceMemoryProperties = try getProc(FnVkGetPhysicalDeviceMemoryProperties, "vkGetPhysicalDeviceMemoryProperties"),
            .vkAllocateMemory = try getProc(FnVkAllocateMemory, "vkAllocateMemory"),
            .vkFreeMemory = try getProc(FnVkFreeMemory, "vkFreeMemory"),
            .vkBindBufferMemory = try getProc(FnVkBindBufferMemory, "vkBindBufferMemory"),
            .vkMapMemory = try getProc(FnVkMapMemory, "vkMapMemory"),
            .vkUnmapMemory = try getProc(FnVkUnmapMemory, "vkUnmapMemory"),
        };
        
        // Select physical device
        var device_count: u32 = 0;
        try check(functions.vkEnumeratePhysicalDevices(instance, &device_count, null));
        
        if (device_count == 0) {
            std.debug.print("No Vulkan devices found\n", .{});
            return error.NoPhysicalDevicesFound;
        }
        
        const devices = try std.heap.page_allocator.alloc(VkPhysicalDevice, device_count);
        defer std.heap.page_allocator.free(devices);
        
        try check(functions.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr));
        
        // Use the first physical device
        const physical_device = devices[0];
        
        // Get device properties
        var properties: c.VkPhysicalDeviceProperties = undefined;
        functions.vkGetPhysicalDeviceProperties(physical_device, &properties);
        
        // Print device name
        const device_name = std.mem.sliceTo(&properties.deviceName, 0);
        std.debug.print("Using device: {s}\n", .{device_name});
        
        // Find queue family with graphics support
        var queue_family_count: u32 = 0;
        functions.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
        
        const queue_families = try std.heap.page_allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
        defer std.heap.page_allocator.free(queue_families);
        
        functions.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);
        
        var graphics_queue_family: ?u32 = null;
        for (queue_families, 0..) |queue_family, i| {
            if (queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
                graphics_queue_family = @intCast(i);
                std.debug.print("  Found graphics queue family: {}\n", .{i});
                break;
            }
        }
        
        if (graphics_queue_family == null) {
            std.debug.print("No suitable queue family found\n", .{});
            return error.NoSuitableQueueFamily;
        }
        
        // Create logical device
        const queue_priority: f32 = 1.0;
        const queue_info = std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = graphics_queue_family.?,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        });
        
        const device_info = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
            .pEnabledFeatures = null,
        });
        
        var device: VkDevice = undefined;
        try check(functions.vkCreateDevice(physical_device, &device_info, null, &device));
        
        // Get queue
        var queue: c.VkQueue = undefined;
        functions.vkGetDeviceQueue(device, graphics_queue_family.?, 0, &queue);
        
        return .{
            .instance = instance,
            .physical_device = physical_device,
            .device = device,
            .queue = queue,
            .functions = functions,
        };
    }
    
    fn deinit(self: *@This()) void {
        std.debug.print("Cleaning up Vulkan...\n", .{});
        self.functions.vkDestroyDevice(self.device, null);
        self.functions.vkDestroyInstance(self.instance, null);
    }
};

const Buffer = struct {
    buffer: VkBuffer,
    memory: VkDeviceMemory,
    size: usize,
    
    fn create(
        ctx: *VulkanContext,
        size: usize,
        usage: VkBufferUsageFlags,
        properties: VkMemoryPropertyFlags,
    ) !@This() {
        const funcs = &ctx.functions;
        
        // Create buffer
        const buffer_info = std.mem.zeroInit(c.VkBufferCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = @intCast(size),
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        });
        
        var buffer: VkBuffer = undefined;
        try check(funcs.vkCreateBuffer(ctx.device, &buffer_info, null, &buffer));
        
        // Get memory requirements
        var mem_requirements: VkMemoryRequirements = undefined;
        funcs.vkGetBufferMemoryRequirements(ctx.device, buffer, &mem_requirements);
        
        // Find memory type
        var mem_properties: VkPhysicalDeviceMemoryProperties = undefined;
        funcs.vkGetPhysicalDeviceMemoryProperties(ctx.physical_device, &mem_properties);
        
        const memory_type_index = blk: {
            for (0..mem_properties.memoryTypeCount) |i| {
                const type_bit = @as(u32, 1) << @intCast(i);
                const is_required_type = (mem_requirements.memoryTypeBits & type_bit) != 0;
                const memory_type = mem_properties.memoryTypes[i];
                const has_required_properties = (memory_type.propertyFlags & properties) == properties;
                
                if (is_required_type and has_required_properties) {
                    std.debug.print("  Found suitable memory type: {}\n", .{i});
                    break :blk @intCast(i);
                }
            }
            
            std.debug.print("No suitable memory type found\n", .{});
            return error.NoSuitableMemoryType;
        };
        
        // Allocate memory
        const alloc_info = std.mem.zeroInit(c.VkMemoryAllocateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        });
        
        var memory: VkDeviceMemory = undefined;
        try check(funcs.vkAllocateMemory(ctx.device, &alloc_info, null, &memory));
        
        // Bind memory to buffer
        try check(funcs.vkBindBufferMemory(ctx.device, buffer, memory, 0));
        
        return .{
            .buffer = buffer,
            .memory = memory,
            .size = @intCast(size),
        };
    }
    
    fn destroy(self: *@This(), device: VkDevice, funcs: *const VulkanFunctions) void {
        funcs.vkDestroyBuffer(device, self.buffer, null);
        funcs.vkFreeMemory(device, self.memory, null);
    }
    
    fn map(self: *const @This(), device: VkDevice, funcs: *const VulkanFunctions, offset: usize, size: usize) ![]u8 {
        var data: ?*anyopaque = undefined;
        try check(funcs.vkMapMemory(device, self.memory, @intCast(offset), @intCast(size), 0, &data));
        return @as([*]u8, @ptrCast(data.?))[0..size];
    }
    
    fn unmap(self: *const @This(), device: VkDevice, funcs: *const VulkanFunctions) void {
        funcs.vkUnmapMemory(device, self.memory);
    }
};

fn check(result: VkResult) !void {
    if (result != c.VK_SUCCESS) {
        std.debug.print("Vulkan error: {}\n", .{result});
        return error.VulkanError;
    }
}

pub fn main() !void {
    std.debug.print("Starting Vulkan memory example...\n", .{});
    
    // Initialize Vulkan
    var context = try VulkanContext.init();
    defer context.deinit();
    
    // Create a buffer
    const buffer_size = 1024 * 1024; // 1MB
    std.debug.print("\nCreating buffer of size {} bytes...\n", .{buffer_size});
    
    const buffer = try Buffer.create(
        &context,
        buffer_size,
        c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT |
        c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT |
        c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
        c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );
    defer buffer.destroy(context.device, &context.functions);
    
    // Map memory and write some data
    std.debug.print("\nMapping memory and writing data...\n", .{});
    
    const data = try buffer.map(context.device, &context.functions, 0, 16);
    defer buffer.unmap(context.device, &context.functions);
    
    // Write some test data
    const test_data = [_]u32{ 1, 2, 3, 4 };
    @memcpy(data[0..@sizeOf(@TypeOf(test_data))], std.mem.asBytes(&test_data));
    
    // Read the data back
    const read_data = std.mem.bytesAsSlice(u32, data[0..@sizeOf(@TypeOf(test_data))]);
    std.debug.print("Wrote data: {any}\n", .{test_data});
    std.debug.print("Read back:  {any}\n", .{read_data});
    
    // Verify the data
    for (test_data, 0..) |expected, i| {
        if (read_data[i] != expected) {
            std.debug.print("Data mismatch at index {}: expected {}, got {}\n", .{i, expected, read_data[i]});
            return error.DataMismatch;
        }
    }
    
    std.debug.print("\nData verification successful!\n", .{});
    std.debug.print("Vulkan memory example completed successfully!\n", .{});
}
