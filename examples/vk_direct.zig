const std = @import("std");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

const VkResult = c.VkResult;

fn check(result: VkResult) !void {
    if (result != c.VK_SUCCESS) {
        std.debug.print("Vulkan error: {}\n", .{result});
        return error.VulkanError;
    }
}

pub fn main() !void {
    std.debug.print("Starting minimal Vulkan example with direct C API...\n", .{});
    
    // Initialize Vulkan
    std.debug.print("Initializing Vulkan...\n", .{});
    
    // Create instance
    const app_info = std.mem.zeroInit(c.VkApplicationInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Vulkan Minimal",
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
    
    var instance: c.VkInstance = undefined;
    std.debug.print("  Creating Vulkan instance...\n", .{});
    try check(c.vkCreateInstance(&instance_info, null, &instance));
    defer {
        std.debug.print("  Destroying Vulkan instance...\n", .{});
        c.vkDestroyInstance(instance, null);
    }
    
    // Enumerate physical devices
    std.debug.print("Enumerating physical devices...\n", .{});
    var device_count: u32 = 0;
    try check(c.vkEnumeratePhysicalDevices(instance, &device_count, null));
    
    if (device_count == 0) {
        std.debug.print("  No Vulkan devices found\n", .{});
        return error.NoVulkanDevicesFound;
    }
    
    const devices = try std.heap.page_allocator.alloc(c.VkPhysicalDevice, device_count);
    defer std.heap.page_allocator.free(devices);
    
    try check(c.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr));
    
    // Use the first physical device
    const physical_device = devices[0];
    
    // Get device properties
    var properties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(physical_device, &properties);
    
    // Convert device name to a Zig string
    const device_name = std.mem.sliceTo(&properties.deviceName, 0);
    std.debug.print("  Using device: {s}\n", .{device_name});
    
    // Find queue family with graphics support
    var queue_family_count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
    
    const queue_families = try std.heap.page_allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
    defer std.heap.page_allocator.free(queue_families);
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);
    
    var graphics_queue_family: ?u32 = null;
    for (queue_families, 0..) |queue_family, i| {
        if (queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            graphics_queue_family = @intCast(i);
            std.debug.print("  Found graphics queue family: {}\n", .{i});
            break;
        }
    }
    
    if (graphics_queue_family == null) {
        std.debug.print("  No suitable queue family found\n", .{});
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
    
    var device: c.VkDevice = undefined;
    std.debug.print("  Creating logical device...\n", .{});
    try check(c.vkCreateDevice(physical_device, &device_info, null, &device));
    defer {
        std.debug.print("  Destroying logical device...\n", .{});
        c.vkDestroyDevice(device, null);
    }
    
    // Get queue
    var queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(device, graphics_queue_family.?, 0, &queue);
    
    // Test buffer creation
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
    try check(c.vkCreateBuffer(device, &buffer_info, null, &buffer));
    defer {
        std.debug.print("  Destroying buffer...\n", .{});
        c.vkDestroyBuffer(device, buffer, null);
    }
    
    // Get memory requirements
    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(device, buffer, &mem_requirements);
    std.debug.print("  Buffer memory requirements:\n", .{});
    std.debug.print("    Size: {}\n", .{mem_requirements.size});
    std.debug.print("    Alignment: {}\n", .{mem_requirements.alignment});
    
    // Find a suitable memory type
    var memory_props: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical_device, &memory_props);
    
    const memory_type_index = blk: {
        const required_flags = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | 
                             c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
        
        for (0..memory_props.memoryTypeCount) |i| {
            const type_bit = @as(u32, 1) << @intCast(i);
            const is_required_type = (mem_requirements.memoryTypeBits & type_bit) != 0;
            const memory_type = memory_props.memoryTypes[i];
            const has_required_flags = (memory_type.propertyFlags & required_flags) == required_flags;
            
            if (is_required_type and has_required_flags) {
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
    try check(c.vkAllocateMemory(device, &alloc_info, null, &buffer_memory));
    defer {
        std.debug.print("  Freeing memory...\n", .{});
        c.vkFreeMemory(device, buffer_memory, null);
    }
    
    // Bind memory to buffer
    std.debug.print("  Binding memory to buffer...\n", .{});
    try check(c.vkBindBufferMemory(device, buffer, buffer_memory, 0));
    
    // Map memory and write some data
    std.debug.print("  Mapping memory...\n", .{});
    var mapped_ptr: ?*anyopaque = undefined;
    try check(c.vkMapMemory(device, buffer_memory, 0, 16, 0, &mapped_ptr));
    
    // Write some data
    const test_data = [_]u32{ 1, 2, 3, 4 };
    @memcpy(@as([*]u8, @ptrCast(mapped_ptr.?))[0..@sizeOf(@TypeOf(test_data))], std.mem.asBytes(&test_data));
    
    // Unmap memory
    c.vkUnmapMemory(device, buffer_memory);
    
    // Map memory again to read back data
    std.debug.print("  Mapping memory for reading...\n", .{});
    try check(c.vkMapMemory(device, buffer_memory, 0, 16, 0, &mapped_ptr));
    
    // Read the data back
    var read_data: [4]u32 = undefined;
    @memcpy(std.mem.asBytes(&read_data), @as([*]const u8, @ptrCast(mapped_ptr.?))[0..@sizeOf(@TypeOf(read_data))]);
    
    // Unmap memory
    c.vkUnmapMemory(device, buffer_memory);
    
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
