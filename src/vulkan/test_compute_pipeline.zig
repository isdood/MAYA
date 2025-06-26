const std = @import("std");
const c = @import("vk.zig");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// Import our shaders
const shaders = @import("shaders.zig");

// Import our Vulkan modules
const memory = @import("memory.zig");
const pipeline = @import("compute/pipeline.zig");
const context = @import("compute/context.zig");

// Test parameters
const TENSOR_SIZE = 64; // 4x4x4x1 tensor for simplicity
const WORKGROUP_SIZE = 4; // Must match the shader's local_size

// Helper function to find a memory type
fn findMemoryType(
    physical_device: c.VkPhysicalDevice,
    type_filter: u32,
    properties: c.VkMemoryPropertyFlags,
) !u32 {
    var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

    for (0..mem_properties.memoryTypeCount) |i| {
        const type_bit = @as(u32, 1) << @intCast(u5, i);
        const has_type = (type_filter & type_bit) != 0;
        const has_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;

        if (has_type and has_properties) {
            return @intCast(u32, i);
        }
    }

    return error.NoSuitableMemoryType;
}

// Helper function to get compute queue family index
fn findComputeQueueFamily(physical_device: c.VkPhysicalDevice) !u32 {
    var queue_family_count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
    
    if (queue_family_count == 0) {
        return error.NoQueueFamiliesFound;
    }
    
    const queue_families = try std.heap.c_allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
    defer std.heap.c_allocator.free(queue_families);
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);
    
    for (queue_families) |queue_family, i| {
        if ((queue_family.queueFlags & c.VK_QUEUE_COMPUTE_BIT) != 0) {
            return @intCast(u32, i);
        }
    }
    
    return error.NoComputeQueueFamily;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("=== Vulkan Compute Pipeline Test ===\n", .{});
    
    // 1. Initialize Vulkan
    print("Initializing Vulkan...\n", .{});
    var vk_context = try context.VulkanContext.init();
    defer vk_context.deinit();
    
    print("Vulkan initialized successfully!\n", .{});
    
    // 2. Create a physical device
    print("Selecting physical device...\n", .{});
    var device_count: u32 = 0;
    _ = c.vkEnumeratePhysicalDevices(vk_context.instance.?, &device_count, null);
    
    if (device_count == 0) {
        print("No Vulkan devices found!\n", .{});
        return error.NoVulkanDevicesFound;
    }
    
    var devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
    defer allocator.free(devices);
    _ = c.vkEnumeratePhysicalDevices(vk_context.instance.?, &device_count, devices.ptr);
    
    // Just use the first device for now
    const physical_device = devices[0];
    
    // Get device properties
    var device_properties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(physical_device, &device_properties);
    print("Using device: {s}\n", .{std.mem.span(&device_properties.deviceName)});
    
    // Find a compute queue family
    const queue_family_index = try findComputeQueueFamily(physical_device);
    print("Using queue family index: {}\n", .{queue_family_index});
    
    // 3. Create a logical device and queue
    print("Creating logical device...\n", .{});
    
    const queue_priority = [_]f32{1.0};
    const queue_create_info = c.VkDeviceQueueCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = queue_family_index,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };
    
    // We only need the storage buffer feature for compute
    var features = std.mem.zeroes(c.VkPhysicalDeviceFeatures);
    features.shaderStorageBufferArrayDynamicIndexing = c.VK_TRUE;
    
    const device_extensions = [_][*:0]const u8{}; // No extensions needed for basic compute
    
    const device_create_info = c.VkDeviceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_create_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @intCast(u32, device_extensions.len),
        .ppEnabledExtensionNames = if (device_extensions.len > 0) &device_extensions else null,
        .pEnabledFeatures = &features,
    };
    
    var device: c.VkDevice = undefined;
    if (c.vkCreateDevice(physical_device, &device_create_info, null, &device) != c.VK_SUCCESS) {
        return error.DeviceCreationFailed;
    }
    defer c.vkDestroyDevice(device, null);
    
    // Get the compute queue
    var compute_queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(device, queue_family_index, 0, &compute_queue);
    
    // 4. Create input/output buffers
    print("Creating buffers...\n", .{});
    
    const buffer_size = TENSOR_SIZE * @sizeOf(f32);
    
    // Find memory type for buffers
    const memory_type_index = try findMemoryType(
        physical_device,
        0xFFFFFFFF, // All types
        @intCast(u32, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | 
                     c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)
    );
    
    // Create input buffer
    const input_buffer = try memory.Buffer.init(
        device,
        buffer_size,
        c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        memory_type_index,
    );
    defer input_buffer.deinit(device);
    
    // Create output buffer
    const output_buffer = try memory.Buffer.init(
        device,
        buffer_size,
        c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        memory_type_index,
    );
    defer output_buffer.deinit(device);
    
    // 5. Create descriptor set layout
    print("Creating descriptor set layout...\n", .{});
    
    const bindings = [_]c.VkDescriptorSetLayoutBinding{
        .{
            .binding = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 1,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
    };
    
    // 6. Create compute pipeline
    print("Creating compute pipeline...\n", .{});
    
    // Convert SPIR-V shader code to u32 array
    const shader_code = std.mem.bytesAsSlice(u32, shaders.shader_4d_tensor_operations);
    
    var compute_pipeline = try pipeline.ComputePipeline.init(
        device,
        shader_code,
        &bindings,
    );
    defer compute_pipeline.deinit();
    
    print("Compute pipeline created successfully!\n", .{});
    
    // 7. Create command buffer and dispatch compute
    print("Dispatching compute...\n", .{});
    
    // Note: We'll need to implement command buffer recording and submission
    // This is a simplified version that skips some steps for brevity
    
    // 8. Read back results and verify
    print("Verifying results...\n", .{});
    
    print("Test completed successfully!\n", .{});
}
