const std = @import("std");
const vk = @import("vulkan");

pub fn main() !void {
    std.debug.print("Starting minimal Vulkan example with vulkan-zig...\n", .{});
    
    // Initialize Vulkan
    std.debug.print("Initializing Vulkan...\n", .{});
    
    // Create instance
    const app_info = std.mem.zeroInit(vk.ApplicationInfo, .{
        .p_application_name = "Vulkan Minimal",
        .application_version = vk.makeApiVersion(0, 1, 0, 0),
        .p_engine_name = "No Engine",
        .engine_version = vk.makeApiVersion(0, 1, 0, 0),
        .api_version = vk.API_VERSION_1_0,
    });
    
    const instance_info = std.mem.zeroInit(vk.InstanceCreateInfo, .{
        .p_application_info = &app_info,
    });
    
    var instance: vk.Instance = undefined;
    std.debug.print("  Creating Vulkan instance...\n", .{});
    try vk.check(vk.getInstance().createInstance(&instance_info, null, &instance));
    defer {
        std.debug.print("  Destroying Vulkan instance...\n", .{});
        instance.destroyInstance(null);
    }
    
    // Enumerate physical devices
    std.debug.print("Enumerating physical devices...\n", .{});
    var device_count: u32 = 0;
    _ = try vk.check(instance.enumeratePhysicalDevices(&device_count, null));
    
    if (device_count == 0) {
        std.debug.print("  No Vulkan devices found\n", .{});
        return error.NoVulkanDevicesFound;
    }
    
    const devices = try std.heap.page_allocator.alloc(vk.PhysicalDevice, device_count);
    defer std.heap.page_allocator.free(devices);
    
    _ = try vk.check(instance.enumeratePhysicalDevices(&device_count, devices.ptr));
    
    // Use the first physical device
    const physical_device = devices[0];
    
    // Get device properties
    var properties: vk.PhysicalDeviceProperties = undefined;
    physical_device.getProperties(&properties);
    
    // Convert device name to a Zig string
    const device_name = std.mem.sliceTo(&properties.device_name, 0);
    std.debug.print("  Using device: {s}\n", .{device_name});
    
    // Find queue family with graphics support
    var queue_family_count: u32 = 0;
    physical_device.getQueueFamilyProperties(&queue_family_count, null);
    
    const queue_families = try std.heap.page_allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
    defer std.heap.page_allocator.free(queue_families);
    physical_device.getQueueFamilyProperties(&queue_family_count, queue_families.ptr);
    
    var graphics_queue_family: ?u32 = null;
    for (queue_families, 0..) |queue_family, i| {
        if (queue_family.queue_flags.graphics_bit) {
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
    const queue_priority = [_]f32{1.0};
    const queue_info = [_]vk.DeviceQueueCreateInfo{
        std.mem.zeroInit(vk.DeviceQueueCreateInfo, .{
            .queue_family_index = graphics_queue_family.?,
            .queue_count = 1,
            .p_queue_priorities = &queue_priority,
        }),
    };
    
    const device_info = std.mem.zeroInit(vk.DeviceCreateInfo, .{
        .queue_create_info_count = 1,
        .p_queue_create_infos = &queue_info,
    });
    
    var device: vk.Device = undefined;
    std.debug.print("  Creating logical device...\n", .{});
    try vk.check(physical_device.createDevice(&device_info, null, &device));
    defer {
        std.debug.print("  Destroying logical device...\n", .{});
        device.destroyDevice(null);
    }
    
    // Get queue
    var queue: vk.Queue = undefined;
    device.getDeviceQueue(graphics_queue_family.?, 0, &queue);
    
    // Test buffer creation
    std.debug.print("\nTesting buffer creation...\n", .{});
    
    // Create a buffer
    const buffer_info = std.mem.zeroInit(vk.BufferCreateInfo, .{
        .size = 1024 * 1024, // 1MB
        .usage = .{ .storage_buffer_bit = true, .transfer_src_bit = true, .transfer_dst_bit = true },
        .sharing_mode = .exclusive,
    });
    
    var buffer: vk.Buffer = undefined;
    std.debug.print("  Creating buffer...\n", .{});
    try vk.check(device.createBuffer(&buffer_info, null, &buffer));
    defer {
        std.debug.print("  Destroying buffer...\n", .{});
        device.destroyBuffer(buffer, null);
    }
    
    // Get memory requirements
    var mem_requirements: vk.MemoryRequirements = undefined;
    device.getBufferMemoryRequirements(buffer, &mem_requirements);
    std.debug.print("  Buffer memory requirements:\n", .{});
    std.debug.print("    Size: {}\n", .{mem_requirements.size});
    std.debug.print("    Alignment: {}\n", .{mem_requirements.alignment});
    
    // Find a suitable memory type
    var memory_properties: vk.PhysicalDeviceMemoryProperties = undefined;
    physical_device.getMemoryProperties(&memory_properties);
    
    const memory_type_index = blk: {
        const properties = vk.MemoryPropertyFlags{ .host_visible_bit = true, .host_coherent_bit = true };
        
        for (0..memory_properties.memory_type_count) |i| {
            const type_bit = @as(u32, 1) << @intCast(i);
            const is_required_type = (mem_requirements.memory_type_bits & type_bit) != 0;
            const memory_type = memory_properties.memory_types[i];
            const has_required_properties = memory_type.property_flags.contains(properties);
            
            if (is_required_type and has_required_properties) {
                std.debug.print("  Found suitable memory type: {}\n", .{i});
                break :blk @as(u32, @intCast(i));
            }
        }
        
        std.debug.print("  No suitable memory type found\n", .{});
        return error.NoSuitableMemoryType;
    };
    
    // Allocate memory
    const alloc_info = std.mem.zeroInit(vk.MemoryAllocateInfo, .{
        .allocation_size = mem_requirements.size,
        .memory_type_index = memory_type_index,
    });
    
    var buffer_memory: vk.DeviceMemory = undefined;
    std.debug.print("  Allocating memory...\n", .{});
    try vk.check(device.allocateMemory(&alloc_info, null, &buffer_memory));
    defer {
        std.debug.print("  Freeing memory...\n", .{});
        device.freeMemory(buffer_memory, null);
    }
    
    // Bind memory to buffer
    std.debug.print("  Binding memory to buffer...\n", .{});
    try vk.check(device.bindBufferMemory(buffer, buffer_memory, 0));
    
    // Map memory and write some data
    std.debug.print("  Mapping memory...\n", .{});
    var mapped_ptr: ?*anyopaque = undefined;
    try vk.check(device.mapMemory(buffer_memory, 0, 16, .{}, &mapped_ptr));
    
    // Write some data
    const test_data = [_]u32{ 1, 2, 3, 4 };
    @memcpy(@as([*]u8, @ptrCast(mapped_ptr.?))[0..@sizeOf(@TypeOf(test_data))], std.mem.asBytes(&test_data));
    
    // Unmap memory
    device.unmapMemory(buffer_memory);
    
    // Map memory again to read back data
    std.debug.print("  Mapping memory for reading...\n", .{});
    try vk.check(device.mapMemory(buffer_memory, 0, 16, .{}, &mapped_ptr));
    
    // Read the data back
    var read_data: [4]u32 = undefined;
    @memcpy(std.mem.asBytes(&read_data), @as([*]const u8, @ptrCast(mapped_ptr.?))[0..@sizeOf(@TypeOf(read_data))]);
    
    // Unmap memory
    device.unmapMemory(buffer_memory);
    
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
