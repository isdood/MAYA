// This is a debug version of the memory management example with additional logging
// to help identify where the segmentation fault is occurring.

const std = @import("std");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

const VulkanContext = struct {
    allocator: std.mem.Allocator,
    instance: c.VkInstance,
    physical_device: ?c.VkPhysicalDevice,
    device: ?c.VkDevice,
    
    pub fn init(allocator: std.mem.Allocator) !@This() {
        std.debug.print("Creating Vulkan instance...\n", .{});
        
        // Initialize Vulkan
        var instance: c.VkInstance = undefined;
        {
            std.debug.print("  Creating application info...\n", .{});
            const app_info = c.VkApplicationInfo{
                .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .pNext = null,
                .pApplicationName = "Vulkan Memory Management",
                .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
                .pEngineName = "No Engine",
                .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
                .apiVersion = c.VK_API_VERSION_1_0,
            };
            
            std.debug.print("  Creating instance create info...\n", .{});
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
        var physical_device: ?c.VkPhysicalDevice = null;
        {
            var device_count: u32 = 0;
            var enum_result = c.vkEnumeratePhysicalDevices(instance, &device_count, null);
            std.debug.print("  vkEnumeratePhysicalDevices (count) result: {}\n", .{enum_result});
            std.debug.print("  Found {} physical devices\n", .{device_count});
            
            if (device_count == 0) {
                std.debug.print("  No physical devices found\n", .{});
                return error.NoPhysicalDevicesFound;
            }
            
            const devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
            defer allocator.free(devices);
            
            enum_result = c.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
            std.debug.print("  vkEnumeratePhysicalDevices (get) result: {}\n", .{enum_result});
            
            if (enum_result != c.VK_SUCCESS) {
                std.debug.print("  Failed to enumerate physical devices: {}\n", .{enum_result});
                return error.FailedToEnumerateDevices;
            }
            
            // Just pick the first device for simplicity
            physical_device = devices[0];
            std.debug.print("  Selected physical device: {*}\n", .{physical_device});
        }
        
        // Create a logical device
        var device: ?c.VkDevice = null;
        if (physical_device) |pd| {
            std.debug.print("Creating logical device...\n", .{});
            
            // Find queue families
            var queue_family_count: u32 = 0;
            c.vkGetPhysicalDeviceQueueFamilyProperties(pd, &queue_family_count, null);
            std.debug.print("  Found {} queue families\n", .{queue_family_count});
            
            const queue_families = try allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
            defer allocator.free(queue_families);
            c.vkGetPhysicalDeviceQueueFamilyProperties(pd, &queue_family_count, queue_families.ptr);
            
            var graphics_queue_family: ?u32 = null;
            for (queue_families, 0..) |queue_family, i| {
                std.debug.print("  Queue family {}: flags={b}\n", .{i, queue_family.queueFlags});
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
            const queue_create_info = c.VkDeviceQueueCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .queueFamilyIndex = graphics_queue_family.?,
                .queueCount = 1,
                .pQueuePriorities = &queue_priority,
            };
            
            const device_create_info = c.VkDeviceCreateInfo{
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
            };
            
            std.debug.print("  Calling vkCreateDevice...\n", .{});
            var dev: c.VkDevice = undefined;
            const result = c.vkCreateDevice(pd, &device_create_info, null, &dev);
            if (result == c.VK_SUCCESS) {
                device = dev;
                std.debug.print("  Logical device created successfully: {*}\n", .{dev});
            } else {
                std.debug.print("  Failed to create logical device: {}\n", .{result});
                return error.FailedToCreateDevice;
            }
        }
        
        return .{
            .allocator = allocator,
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
            self.device = null;
        }
        
        if (@intFromPtr(self.instance) != 0) {
            std.debug.print("  Destroying Vulkan instance...\n", .{});
            c.vkDestroyInstance(self.instance, null);
        }
        
        self.physical_device = null;
    }
};

const MemoryManager = struct {
    device: c.VkDevice,
    physical_device: c.VkPhysicalDevice,
    allocator: std.mem.Allocator,
    
    pub fn init(device: c.VkDevice, physical_device: c.VkPhysicalDevice, allocator: std.mem.Allocator) @This() {
        return .{
            .device = device,
            .physical_device = physical_device,
            .allocator = allocator,
        };
    }
    
    pub fn createBuffer(self: *@This(), size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags) !struct {
        buffer: c.VkBuffer,
        memory: c.VkDeviceMemory,
        size: c.VkDeviceSize,
    } {
        std.debug.print("  Creating buffer...\n", .{});
        
        // Create buffer
        const buffer_info = c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = size,
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };
        
        var buffer: c.VkBuffer = undefined;
        const create_result = c.vkCreateBuffer(self.device, &buffer_info, null, &buffer);
        if (create_result != c.VK_SUCCESS) {
            std.debug.print("    Failed to create buffer: {}\n", .{create_result});
            return error.FailedToCreateBuffer;
        }
        
        std.debug.print("    Buffer created: {*}\n", .{buffer});
        
        // Allocate memory
        std.debug.print("  Allocating memory...\n", .{});
        var mem_requirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(self.device, buffer, &mem_requirements);
        
        const alloc_info = c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = try self.findMemoryType(mem_requirements.memoryTypeBits, properties),
        };
        
        var buffer_memory: c.VkDeviceMemory = undefined;
        const alloc_result = c.vkAllocateMemory(self.device, &alloc_info, null, &buffer_memory);
        if (alloc_result != c.VK_SUCCESS) {
            std.debug.print("    Failed to allocate memory: {}\n", .{alloc_result});
            c.vkDestroyBuffer(self.device, buffer, null);
            return error.FailedToAllocateMemory;
        }
        
        std.debug.print("    Memory allocated: {*}\n", .{buffer_memory});
        
        // Bind memory to buffer
        std.debug.print("  Binding memory to buffer...\n", .{});
        const bind_result = c.vkBindBufferMemory(self.device, buffer, buffer_memory, 0);
        if (bind_result != c.VK_SUCCESS) {
            std.debug.print("    Failed to bind buffer memory: {}\n", .{bind_result});
            c.vkFreeMemory(self.device, buffer_memory, null);
            c.vkDestroyBuffer(self.device, buffer, null);
            return error.FailedToBindBufferMemory;
        }
        
        return .{
            .buffer = buffer,
            .memory = buffer_memory,
            .size = size,
        };
    }
    
    pub fn destroyBuffer(self: *@This(), buffer_info: anytype) void {
        std.debug.print("  Freeing buffer memory...\n", .{});
        c.vkFreeMemory(self.device, buffer_info.memory, null);
        
        std.debug.print("  Destroying buffer...\n", .{});
        c.vkDestroyBuffer(self.device, buffer_info.buffer, null);
    }
    
    pub fn copyToBuffer(self: *@This(), buffer_info: anytype, data: []const u8, offset: c.VkDeviceSize) !void {
        std.debug.print("  Mapping memory for writing...\n", .{});
        var mapped_ptr: ?*anyopaque = undefined;
        const map_result = c.vkMapMemory(self.device, buffer_info.memory, offset, @intCast(data.len), 0, &mapped_ptr);
        if (map_result != c.VK_SUCCESS) {
            std.debug.print("    Failed to map memory: {}\n", .{map_result});
            return error.FailedToMapMemory;
        }
        defer {
            std.debug.print("  Unmapping memory...\n", .{});
            c.vkUnmapMemory(self.device, buffer_info.memory);
        }
        
        std.debug.print("  Copying {} bytes to buffer...\n", .{data.len});
        @memcpy(@as([*]u8, @ptrCast(mapped_ptr))[0..data.len], data);
        
        // Flush the memory to make sure the write is visible to the device
        std.debug.print("  Flushing memory...\n", .{});
        const memory_range = c.VkMappedMemoryRange{
            .sType = c.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .pNext = null,
            .memory = buffer_info.memory,
            .offset = offset,
            .size = c.VK_WHOLE_SIZE,
        };
        const flush_result = c.vkFlushMappedMemoryRanges(self.device, 1, &memory_range);
        if (flush_result != c.VK_SUCCESS) {
            std.debug.print("    Failed to flush memory: {}\n", .{flush_result});
            return error.FailedToFlushMemory;
        }
    }
    
    pub fn copyFromBuffer(self: *@This(), buffer_info: anytype, data: []u8, offset: c.VkDeviceSize) !void {
        std.debug.print("  Mapping memory for reading...\n", .{});
        var mapped_ptr: ?*anyopaque = undefined;
        const map_result = c.vkMapMemory(self.device, buffer_info.memory, offset, @intCast(data.len), 0, &mapped_ptr);
        if (map_result != c.VK_SUCCESS) {
            std.debug.print("    Failed to map memory: {}\n", .{map_result});
            return error.FailedToMapMemory;
        }
        defer {
            std.debug.print("  Unmapping memory...\n", .{});
            c.vkUnmapMemory(self.device, buffer_info.memory);
        }
        
        // Invalidate the memory to make sure we read the latest data
        std.debug.print("  Invalidating memory...\n", .{});
        const memory_range = c.VkMappedMemoryRange{
            .sType = c.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .pNext = null,
            .memory = buffer_info.memory,
            .offset = offset,
            .size = c.VK_WHOLE_SIZE,
        };
        const invalidate_result = c.vkInvalidateMappedMemoryRanges(self.device, 1, &memory_range);
        if (invalidate_result != c.VK_SUCCESS) {
            std.debug.print("    Failed to invalidate memory: {}\n", .{invalidate_result});
            return error.FailedToInvalidateMemory;
        }
        
        std.debug.print("  Copying {} bytes from buffer...\n", .{data.len});
        @memcpy(data, @as([*]const u8, @ptrCast(mapped_ptr))[0..data.len]);
    }
    
    fn findMemoryType(self: *@This(), type_filter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
        std.debug.print("  Finding suitable memory type...\n", .{});
        var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &mem_properties);
        
        for (0..mem_properties.memoryTypeCount) |i| {
            const type_bit = @as(u32, 1) << @intCast(i);
            const is_required_type = (type_filter & type_bit) != 0;
            const has_required_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;
            
            if (is_required_type and has_required_properties) {
                std.debug.print("    Found suitable memory type: {}\n", .{i});
                return @intCast(i);
            }
        }
        
        std.debug.print("    No suitable memory type found\n", .{});
        return error.NoSuitableMemoryType;
    }
};

pub fn main() !void {
    std.debug.print("Starting memory management example...\n", .{});
    
    // Initialize allocator
    std.debug.print("Initializing allocator...\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        std.debug.print("Deinitializing allocator...\n", .{});
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    // Initialize Vulkan context
    std.debug.print("Initializing Vulkan context...\n", .{});
    var context = try VulkanContext.init(allocator);
    defer context.deinit();
    
    // Ensure we have a valid device
    const device = context.device orelse {
        std.debug.print("Error: No Vulkan device available\n", .{});
        return error.NoDevice;
    };
    
    const physical_device = context.physical_device orelse {
        std.debug.print("Error: No physical device selected\n", .{});
        return error.NoPhysicalDevice;
    };
    
    std.debug.print("Vulkan device and physical device are valid\n", .{});
    
    // Initialize memory manager
    std.debug.print("Initializing memory manager...\n", .{});
    var memory_manager = MemoryManager.init(device, physical_device, allocator);
    
    // Create a buffer using MemoryManager
    std.debug.print("\nCreating buffer...\n", .{});
    const buffer_size: c.VkDeviceSize = 1024 * 1024; // 1MB buffer size
    
    // Define buffer usage and memory properties
    const usage = c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | 
                 c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | 
                 c.VK_BUFFER_USAGE_TRANSFER_DST_BIT;
                 
    // Use host-visible and host-coherent memory for this example
    const memory_properties = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | 
                             c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    
    std.debug.print("Creating buffer with size: {} bytes\n", .{buffer_size});
    std.debug.print("Buffer usage: {b}\n", .{usage});
    std.debug.print("Memory properties: {b}\n", .{memory_properties});
    
    const buffer = try memory_manager.createBuffer(buffer_size, usage, memory_properties);
    defer memory_manager.destroyBuffer(buffer);
    
    std.debug.print("Buffer created successfully. Buffer info:\n", .{});
    std.debug.print("  vk_buffer: {*}\n", .{buffer.buffer});
    std.debug.print("  memory: {*}\n", .{buffer.memory});
    std.debug.print("  size: {} bytes\n", .{buffer.size});
    
    // Example: Writing to and reading from a buffer
    {
        std.debug.print("\nExample: Writing to and reading from a buffer\n", .{});
        
        // Prepare some test data
        const test_data = [_]u32{ 1, 2, 3, 4, 5 };
        
        // Copy data to the buffer
        std.debug.print("Writing data to buffer...\n", .{});
        try memory_manager.copyToBuffer(
            buffer,
            std.mem.sliceAsBytes(&test_data),
            0, // offset
        );
        
        // Read data back from the buffer
        std.debug.print("Reading data from buffer...\n", .{});
        const readback_data = try allocator.alloc(u8, test_data.len * @sizeOf(u32));
        defer allocator.free(readback_data);
        
        try memory_manager.copyFromBuffer(
            buffer,
            readback_data,
            0, // offset
        );
        
        // Convert readback data to u32 slice
        const readback_slice = std.mem.bytesAsSlice(u32, readback_data);
        
        // Verify the data
        std.debug.print("  Wrote data: ", .{});
        for (test_data) |val| std.debug.print("{} ", .{val});
        std.debug.print("\n  Read back: ", .{});
        for (readback_slice) |val| std.debug.print("{} ", .{val});
        std.debug.print("\n", .{});
        
        // Verify the data matches
        for (test_data, 0..) |expected, i| {
            if (readback_slice[i] != expected) {
                std.debug.print("  Data mismatch at index {}: expected {}, got {}\n", .{i, expected, readback_slice[i]});
                return error.DataMismatch;
            }
        }
        
        std.debug.print("  Successfully verified readback of {} bytes\n", .{test_data.len * @sizeOf(u32)});
    }
    
    std.debug.print("\nMemory management example completed successfully!\n", .{});
}

// Simple test to verify the example compiles
test "memory management example" {
    // This just verifies the example compiles
    _ = @import("memory_management_debug.zig");
}
