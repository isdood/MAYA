const std = @import("std");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

const VulkanContext = struct {
    instance: c.VkInstance,
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    
    pub fn init() !@This() {
        std.debug.print("Creating Vulkan instance...\n", .{});
        
        // Initialize Vulkan
        var instance: c.VkInstance = undefined;
        {
            const app_info = std.mem.zeroInit(c.VkApplicationInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .pNext = null,
                .pApplicationName = "Vulkan Minimal",
                .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
                .pEngineName = "No Engine",
                .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
                .apiVersion = c.VK_API_VERSION_1_0,
            });
            
            const create_info = std.mem.zeroInit(c.VkInstanceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .pApplicationInfo = &app_info,
                .enabledLayerCount = 0,
                .ppEnabledLayerNames = null,
                .enabledExtensionCount = 0,
                .ppEnabledExtensionNames = null,
            });
            
            std.debug.print("  Calling vkCreateInstance...\n", .{});
            const result = c.vkCreateInstance(&create_info, null, &instance);
            if (result != c.VK_SUCCESS) {
                std.debug.print("  Failed to create Vulkan instance: {}\n", .{result});
                return error.FailedToCreateInstance;
            }
            std.debug.print("  Vulkan instance created successfully\n", .{});
        }
        
        // Pick the first physical device
        std.debug.print("Enumerating physical devices...\n", .{});
        var physical_device: c.VkPhysicalDevice = undefined;
        {
            var device_count: u32 = 0;
            var enum_result = c.vkEnumeratePhysicalDevices(instance, &device_count, null);
            std.debug.print("  Found {} physical devices\n", .{device_count});
            
            if (device_count == 0) {
                std.debug.print("  No physical devices found\n", .{});
                return error.NoPhysicalDevicesFound;
            }
            
            const devices = try std.heap.page_allocator.alloc(c.VkPhysicalDevice, device_count);
            defer std.heap.page_allocator.free(devices);
            
            enum_result = c.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
            if (enum_result != c.VK_SUCCESS) {
                std.debug.print("  Failed to enumerate physical devices: {}\n", .{enum_result});
                return error.FailedToEnumerateDevices;
            }
            
            // Just pick the first device for simplicity
            physical_device = devices[0];
            
            // Print device properties
            var properties: c.VkPhysicalDeviceProperties = undefined;
            c.vkGetPhysicalDeviceProperties(physical_device, &properties);
            
            // Convert device name to a Zig string
            const device_name = std.mem.sliceTo(&properties.deviceName, 0);
            std.debug.print("  Selected device: {s}\n", .{device_name});
        }
        
        // Create a logical device
        std.debug.print("Creating logical device...\n", .{});
        var device: c.VkDevice = undefined;
        {
            // Find queue families
            var queue_family_count: u32 = 0;
            c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
            std.debug.print("  Found {} queue families\n", .{queue_family_count});
            
            const queue_families = try std.heap.page_allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
            defer std.heap.page_allocator.free(queue_families);
            c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);
            
            var graphics_queue_family: ?u32 = null;
            for (queue_families, 0..) |queue_family, i| {
                if (queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
                    graphics_queue_family = @intCast(i);
                    std.debug.print("    Selected graphics queue family: {}\n", .{i});
                    break;
                }
            }
            
            if (graphics_queue_family == null) {
                std.debug.print("  No suitable queue family found\n", .{});
                return error.NoSuitableQueueFamily;
            }
            
            const queue_priority: f32 = 1.0;
            const queue_create_info = std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .queueFamilyIndex = graphics_queue_family.?,
                .queueCount = 1,
                .pQueuePriorities = &queue_priority,
            });
            
            const device_create_info = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .queueCreateInfoCount = 1,
                .pQueueCreateInfos = &queue_create_info,
                .enabledLayerCount = 0,
                .ppEnabledLayerNames = null,
                .enabledExtensionCount = 0,
                .ppEnabledExtensionNames = null,
                .pEnabledFeatures = null,
            });
            
            std.debug.print("  Calling vkCreateDevice...\n", .{});
            const result = c.vkCreateDevice(physical_device, &device_create_info, null, &device);
            if (result != c.VK_SUCCESS) {
                std.debug.print("  Failed to create logical device: {}\n", .{result});
                return error.FailedToCreateDevice;
            }
            std.debug.print("  Logical device created successfully\n", .{});
        }
        
        return .{
            .instance = instance,
            .physical_device = physical_device,
            .device = device,
        };
    }
    
    pub fn deinit(self: *@This()) void {
        std.debug.print("Cleaning up Vulkan context...\n", .{});
        
        if (self.device) |dev| {
            std.debug.print("  Destroying logical device...\n", .{});
            c.vkDestroyDevice(dev, null);
        }
        
        if (self.instance) |instance| {
            std.debug.print("  Destroying Vulkan instance...\n", .{});
            c.vkDestroyInstance(instance, null);
        }
    }
};

pub fn main() !void {
    std.debug.print("Starting minimal Vulkan example...\n", .{});
    
    // Initialize Vulkan context
    std.debug.print("Initializing Vulkan context...\n", .{});
    var context = try VulkanContext.init();
    defer context.deinit();
    
    std.debug.print("Vulkan initialization successful!\n", .{});
    
    // Simple buffer creation test
    std.debug.print("\nTesting buffer creation...\n", .{});
    
    // Create a buffer
    const buffer_info = std.mem.zeroInit(c.VkBufferCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .size = 1024 * 1024, // 1MB
        .usage = c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | 
                 c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | 
                 c.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
    });
    
    var buffer: c.VkBuffer = undefined;
    std.debug.print("  Creating buffer...\n", .{});
    const create_result = c.vkCreateBuffer(context.device, &buffer_info, null, &buffer);
    if (create_result != c.VK_SUCCESS) {
        std.debug.print("  Failed to create buffer: {}\n", .{create_result});
        return error.FailedToCreateBuffer;
    }
    defer {
        std.debug.print("  Destroying buffer...\n", .{});
        c.vkDestroyBuffer(context.device, buffer, null);
    }
    
    // Get memory requirements
    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(context.device, buffer, &mem_requirements);
    std.debug.print("  Buffer memory requirements:\n", .{});
    std.debug.print("    Size: {}\n", .{mem_requirements.size});
    std.debug.print("    Alignment: {}\n", .{mem_requirements.alignment});
    std.debug.print("    Memory type bits: {b}\n", .{mem_requirements.memoryTypeBits});
    
    // Find a suitable memory type
    var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(context.physical_device, &mem_properties);
    
    const memory_type_index = blk: {
        const properties = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | 
                         c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
        
        for (0..mem_properties.memoryTypeCount) |i| {
            const type_bit = @as(u32, 1) << @intCast(i);
            const is_required_type = (mem_requirements.memoryTypeBits & type_bit) != 0;
            const has_required_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;
            
            if (is_required_type and has_required_properties) {
                std.debug.print("  Found suitable memory type: {}\n", .{i});
                break :blk @as(u32, @intCast(i));
            }
        }
        
        std.debug.print("  No suitable memory type found\n", .{});
        return error.NoSuitableMemoryType;
    };
    
    // Allocate memory
    const alloc_info = std.mem.zeroInit(c.VkMemoryAllocateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .pNext = null,
        .allocationSize = mem_requirements.size,
        .memoryTypeIndex = memory_type_index,
    });
    
    var buffer_memory: c.VkDeviceMemory = undefined;
    std.debug.print("  Allocating memory...\n", .{});
    const alloc_result = c.vkAllocateMemory(context.device, &alloc_info, null, &buffer_memory);
    if (alloc_result != c.VK_SUCCESS) {
        std.debug.print("  Failed to allocate memory: {}\n", .{alloc_result});
        return error.FailedToAllocateMemory;
    }
    defer {
        std.debug.print("  Freeing memory...\n", .{});
        c.vkFreeMemory(context.device, buffer_memory, null);
    }
    
    // Bind memory to buffer
    std.debug.print("  Binding memory to buffer...\n", .{});
    const bind_result = c.vkBindBufferMemory(context.device, buffer, buffer_memory, 0);
    if (bind_result != c.VK_SUCCESS) {
        std.debug.print("  Failed to bind buffer memory: {}\n", .{bind_result});
        return error.FailedToBindBufferMemory;
    }
    
    // Map memory and write some data
    std.debug.print("  Mapping memory...\n", .{});
    var mapped_ptr: ?*anyopaque = undefined;
    const map_result = c.vkMapMemory(context.device, buffer_memory, 0, 16, 0, &mapped_ptr);
    if (map_result != c.VK_SUCCESS) {
        std.debug.print("  Failed to map memory: {}\n", .{map_result});
        return error.FailedToMapMemory;
    }
    
    // Write some data
    const test_data = [_]u32{ 1, 2, 3, 4 };
    @memcpy(@as([*]u8, @ptrCast(mapped_ptr.?))[0..@sizeOf(@TypeOf(test_data))], std.mem.asBytes(&test_data));
    
    // Unmap memory
    c.vkUnmapMemory(context.device, buffer_memory);
    
    // Read back the data
    const read_result = c.vkMapMemory(context.device, buffer_memory, 0, 16, 0, &mapped_ptr);
    if (read_result != c.VK_SUCCESS) {
        std.debug.print("  Failed to map memory for reading: {}\n", .{read_result});
        return error.FailedToMapMemory;
    }
    
    // Read the data back
    var read_data: [4]u32 = undefined;
    @memcpy(std.mem.asBytes(&read_data), @as([*]const u8, @ptrCast(mapped_ptr.?))[0..@sizeOf(@TypeOf(read_data))]);
    
    // Unmap memory
    c.vkUnmapMemory(context.device, buffer_memory);
    
    // Verify the data
    std.debug.print("  Wrote data: {any}\n", .{test_data});
    std.debug.print("  Read back: {any}\n", .{read_data});
    
    // Check if the data matches
    for (test_data, 0..) |expected, i| {
        if (read_data[i] != expected) {
            std.debug.print("  Data mismatch at index {}: expected {}, got {}\n", .{i, expected, read_data[i]});
            return error.DataMismatch;
        }
    }
    
    std.debug.print("  Data verification successful!\n", .{});
    std.debug.print("\nMinimal Vulkan example completed successfully!\n", .{});
}

// Simple test to verify the example compiles
test "minimal vulkan example" {
    // This just verifies the example compiles
    _ = @import("memory_management_minimal.zig");
}
