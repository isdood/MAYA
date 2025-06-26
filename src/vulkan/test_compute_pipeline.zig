const std = @import("std");
const vk = @import("vk.zig");
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
    physical_device: vk.VkPhysicalDevice,
    type_filter: u32,
    properties: vk.VkMemoryPropertyFlags,
) !u32 {
    var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
    vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

    for (0..mem_properties.memoryTypeCount) |i| {
        const type_bit = @as(u32, 1) << @as(u5, @intCast(i));
        const is_required_type = (type_filter & type_bit) != 0;
        const has_required_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;
        
        if (is_required_type and has_required_properties) {
            return @as(u32, @intCast(i));
        }
    }
    
    return error.NoSuitableMemoryType;
}

// Helper function to get compute queue family index
fn findComputeQueueFamily(physical_device: vk.VkPhysicalDevice) !u32 {
    var queue_family_count: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
    
    if (queue_family_count == 0) {
        return error.NoQueueFamiliesFound;
    }
    
    const queue_families = try std.heap.c_allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
    defer std.heap.c_allocator.free(queue_families);
    vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);
    
    for (queue_families, 0..) |queue_family, i| {
        if ((queue_family.queueFlags & vk.VK_QUEUE_COMPUTE_BIT) != 0) {
            return @as(u32, @intCast(i));
        }
    }
    
    return error.NoComputeQueueFamily;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Vulkan Compute Pipeline Test ===\n", .{});
    
    // 1. Initialize Vulkan
    std.debug.print("Initializing Vulkan...\n", .{});
    var vk_context = try context.VulkanContext.init();
    defer vk_context.deinit();
    
    std.debug.print("Vulkan initialized successfully!\n", .{});
    
    // 2. Create a physical device
    std.debug.print("Selecting physical device...\n", .{});
    var device_count: u32 = 0;
    _ = vk.vkEnumeratePhysicalDevices(vk_context.instance.?, &device_count, null);
    
    if (device_count == 0) {
        std.debug.print("No Vulkan devices found!\n", .{});
        return error.NoVulkanDevicesFound;
    }
    
    var devices = try allocator.alloc(vk.VkPhysicalDevice, device_count);
    defer allocator.free(devices);
    _ = vk.vkEnumeratePhysicalDevices(vk_context.instance.?, &device_count, devices.ptr);
    
    // Just use the first device for now
    const physical_device = devices[0];
    
    // Get device properties
    var device_properties: vk.VkPhysicalDeviceProperties = undefined;
    vk.vkGetPhysicalDeviceProperties(physical_device, &device_properties);
    std.debug.print("Using device: {s}\n", .{std.mem.span(&device_properties.deviceName)});
    
    // Find a compute queue family
    const queue_family_index = try findComputeQueueFamily(physical_device);
    std.debug.print("Using queue family index: {}\n", .{queue_family_index});
    
    // 3. Create a logical device and queue
    std.debug.print("Creating logical device...\n", .{});
    
    const queue_priority = [_]f32{1.0};
    const queue_create_info = vk.VkDeviceQueueCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = queue_family_index,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };
    
    // We only need the storage buffer feature for compute
    var features = std.mem.zeroes(vk.VkPhysicalDeviceFeatures);
    features.shaderStorageBufferArrayDynamicIndexing = vk.VK_TRUE;
    
    const device_extensions = [_][*:0]const u8{}; // No extensions needed for basic compute
    
    const device_create_info = vk.VkDeviceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_create_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = @as(u32, @intCast(@as(usize, device_extensions.len))),
        .ppEnabledExtensionNames = if (device_extensions.len > 0) &device_extensions else null,
        .pEnabledFeatures = &features,
    };
    
    var device: vk.VkDevice = undefined;
    if (vk.vkCreateDevice(physical_device, &device_create_info, null, &device) != vk.VK_SUCCESS) {
        return error.DeviceCreationFailed;
    }
    defer vk.vkDestroyDevice(device, null);
    
    // Get the compute queue
    var compute_queue: vk.VkQueue = undefined;
    vk.vkGetDeviceQueue(device, queue_family_index, 0, &compute_queue);
    
    // 4. Create input/output buffers
    std.debug.print("Creating buffers...\n", .{});
    
    const buffer_size = TENSOR_SIZE * @sizeOf(f32);
    
    // Create input buffer
    const input_buffer = try memory.Buffer.init(
        physical_device,
        device,
        buffer_size,
        vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );
    defer input_buffer.deinit(device);
    
    // Create output buffer
    const output_buffer = try memory.Buffer.init(
        physical_device,
        device,
        buffer_size,
        vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );
    defer output_buffer.deinit(device);
    
    // 5. Initialize input data
    std.debug.print("Initializing input data...\n", .{});
    
    // Map and initialize input buffer
    const input_data = try input_buffer.mapMemory(device, f32);
    defer input_buffer.unmapMemory(device);
    
    for (0..TENSOR_SIZE) |i| {
        input_data[i] = @as(f32, @floatFromInt(i));
    }
    
    std.debug.print("Input data initialized. First few values: {d:.2} {d:.2} {d:.2} {d:.2}\n", 
        .{input_data[0], input_data[1], input_data[2], input_data[3]});
    
    // 6. Create compute pipeline
    std.debug.print("Creating compute pipeline...\n", .{});
    
    // Define descriptor set layout bindings
    const bindings = [_]vk.VkDescriptorSetLayoutBinding{
        .{
            .binding = 0,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 1,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
    };
    
    // 7. Create the compute pipeline
    std.debug.print("Creating compute pipeline...\n", .{});
    
    // Convert SPIR-V shader code to u32 array
    const shader_code = std.mem.bytesAsSlice(u32, shaders.shader_4d_tensor_operations);
    
    // Create the compute pipeline
    var compute_pipeline = try pipeline.ComputePipeline.init(
        device,
        shader_code,
        &bindings,
    );
    defer compute_pipeline.deinit(device);
    
    // 8. Create descriptor sets
    std.debug.print("Creating descriptor sets...\n", .{});
    
    // Update descriptor sets
    try compute_pipeline.updateDescriptorSets(device, &[2]memory.Buffer{ input_buffer, output_buffer });
    
    // 9. Create command buffer
    std.debug.print("Creating command buffer...\n", .{});
    
    const command_buffer = try compute_pipeline.createCommandBuffer(
        device,
        compute_queue,
        @as(u32, @intCast(TENSOR_SIZE / WORKGROUP_SIZE)),
        1,
        1
    );
    
    // 10. Submit work
    std.debug.print("Submitting compute work...\n", .{});
    
    const submit_info = vk.VkSubmitInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,
    };
    
    const fence_create_info = vk.VkFenceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };
    
    var fence: vk.VkFence = undefined;
    if (vk.vkCreateFence(device, &fence_create_info, null, &fence) != vk.VK_SUCCESS) {
        return error.FenceCreationFailed;
    }
    defer vk.vkDestroyFence(device, fence, null);
    
    if (vk.vkQueueSubmit(compute_queue, 1, &submit_info, fence) != vk.VK_SUCCESS) {
        return error.QueueSubmitFailed;
    }
    
    // 11. Wait for completion
    std.debug.print("Waiting for compute work to complete...\n", .{});
    
    _ = vk.vkWaitForFences(device, 1, &fence, vk.VK_TRUE, std.math.maxInt(u64));
    
    // 12. Read back results
    std.debug.print("Reading back results...\n", .{});
    
    const output_data = try output_buffer.mapMemory(device, f32);
    defer output_buffer.unmapMemory(device);
    
    // Print first few results
    std.debug.print("First 10 results:\n", .{});
    for (0..@min(10, TENSOR_SIZE)) |i| {
        std.debug.print("  output[{}] = {d:.4}\n", .{i, output_data[i]});
    }
    
    // Verify results
    var success = true;
    for (0..TENSOR_SIZE) |i| {
        const expected = @as(f32, @floatFromInt(i)) * 2.0; // Assuming the shader multiplies by 2
        if (@abs(output_data[i] - expected) > 0.0001) {
            std.debug.print("Mismatch at index {}: expected {d:.4}, got {d:.4}\n", .{i, expected, output_data[i]});
            success = false;
            break;
        }
    }
    
    if (success) {
        std.debug.print("All results match expected values!\n", .{});
    } else {
        std.debug.print("Some results did not match expected values.\n", .{});
    }
    
    std.debug.print("Test completed.\n", .{});
}
