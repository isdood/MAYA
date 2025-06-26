const std = @import("std");
const vk = @import("vk");

// Import our Vulkan modules
const memory = @import("memory");

const pipeline = @import("pipeline");
const debug = @import("debug");
const context = @import("context");

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
        const has_type = (type_filter & type_bit) != 0;
        const has_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;

        if (has_type and has_properties) {
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

    std.debug.print("=== Starting Vulkan Compute Test ===\n", .{});
    std.debug.print("Initialized allocator\n", .{});
    
    // Create Vulkan instance
    std.debug.print("=== Starting Vulkan Instance Creation ===\n", .{});
    
    // Check Vulkan loader version
    var api_version: u32 = 0;
    const loader_version_result = vk.vkEnumerateInstanceVersion(&api_version);
    if (loader_version_result == vk.VK_SUCCESS) {
        const major = vk.VK_API_VERSION_MAJOR(api_version);
        const minor = vk.VK_API_VERSION_MINOR(api_version);
        const patch = vk.VK_API_VERSION_PATCH(api_version);
        std.debug.print("Vulkan loader version: {}.{}.{}\n", .{major, minor, patch});
    } else {
        std.debug.print("vkEnumerateInstanceVersion failed: {}\n", .{loader_version_result});
    }
    
    // Get required instance extensions
    // Enumerate instance extensions
    var extension_count: u32 = 0;
    var enumerate_result = vk.vkEnumerateInstanceExtensionProperties(null, &extension_count, null);
    if (enumerate_result != vk.VK_SUCCESS and enumerate_result != vk.VK_INCOMPLETE) {
        std.debug.print("Failed to enumerate instance extensions: {}\n", .{enumerate_result});
        return error.FailedToEnumerateExtensions;
    }
    std.debug.print("Found {} instance extensions\n", .{extension_count});
    
    // List available extensions
    if (extension_count > 0) {
        const extensions = try std.heap.c_allocator.alloc(vk.VkExtensionProperties, extension_count);
        defer std.heap.c_allocator.free(extensions);
        
        enumerate_result = vk.vkEnumerateInstanceExtensionProperties(null, &extension_count, extensions.ptr);
        if (enumerate_result != vk.VK_SUCCESS) {
            std.debug.print("Failed to get instance extensions: {}\n", .{enumerate_result});
            return error.FailedToGetExtensions;
        }
        
        std.debug.print("Available instance extensions ({}):\n", .{extension_count});
        for (extensions, 0..) |ext, i| {
            const name = std.mem.span(@as([*:0]const u8, @ptrCast(&ext.extensionName)));
            std.debug.print("  {:3}: {s} (spec version: {})\n", .{i, name, ext.specVersion});
        }
    }
    
    // Check for debug utils extension
    var debug_utils_available = false;
    if (extension_count > 0) {
        const extensions = try std.heap.c_allocator.alloc(vk.VkExtensionProperties, extension_count);
        defer std.heap.c_allocator.free(extensions);
        
        enumerate_result = vk.vkEnumerateInstanceExtensionProperties(null, &extension_count, extensions.ptr);
        if (enumerate_result == vk.VK_SUCCESS) {
            for (extensions) |ext| {
                const name = std.mem.span(@as([*:0]const u8, @ptrCast(&ext.extensionName)));
                if (std.mem.eql(u8, name, vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME)) {
                    debug_utils_available = true;
                    std.debug.print("Found debug utils extension\n", .{});
                    break;
                }
            }
        }
    }
    
    if (!debug_utils_available) {
        std.debug.print("Debug utils extension not found\n", .{});
    }
    
    // Create application info
    const app_info = vk.VkApplicationInfo{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Vulkan Compute Test",
        .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "No Engine",
        .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = vk.VK_API_VERSION_1_0,
    };
    
    std.debug.print("Using Vulkan API version: {}.{}.{}\n", .{
        vk.VK_API_VERSION_MAJOR(app_info.apiVersion),
        vk.VK_API_VERSION_MINOR(app_info.apiVersion),
        vk.VK_API_VERSION_PATCH(app_info.apiVersion),
    });

    // Request validation layers if available
    const enable_validation_layers = true;
    const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
    
    // Check if validation layers are available
    var layer_count: u32 = 0;
    _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, null);
    const available_layers = try allocator.alloc(vk.VkLayerProperties, layer_count);
    defer allocator.free(available_layers);
    _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, available_layers.ptr);
    
    const enable_validation = enable_validation_layers and blk: {
        for (available_layers) |layer| {
            const layer_name = std.mem.span(@as([*:0]const u8, @ptrCast(&layer.layerName)));
            if (std.mem.eql(u8, layer_name, "VK_LAYER_KHRONOS_validation")) {
                break :blk true;
            }
        }
        break :blk false;
    };
    
    // Required extensions
    const extensions = [_][*:0]const u8{
        vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME,
    };
    
    // Print enabled extensions
    std.debug.print("Enabling {} instance extensions:\n", .{extensions.len});
    for (extensions, 0..) |ext, i| {
        std.debug.print("  {}: {s}\n", .{i, ext});
    }
    
    // Print enabled layers if any
    if (enable_validation and validation_layers.len > 0) {
        std.debug.print("Enabling {} validation layers:\n", .{validation_layers.len});
        for (validation_layers, 0..) |layer, i| {
            std.debug.print("  {}: {s}\n", .{i, layer});
        }
    } else {
        std.debug.print("No validation layers enabled\n", .{});
    }
    
    // Create instance create info
    var instance_create_info = vk.VkInstanceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = if (enable_validation) @as(u32, @intCast(validation_layers.len)) else 0,
        .ppEnabledLayerNames = if (enable_validation) &validation_layers else null,
        .enabledExtensionCount = @as(u32, @intCast(extensions.len)),
        .ppEnabledExtensionNames = if (extensions.len > 0) &extensions else null,
    };
    
    // Setup debug messenger create info if debug utils are available
    var debug_create_info: vk.VkDebugUtilsMessengerCreateInfoEXT = undefined;
    if (debug_utils_available) {
        debug_create_info = vk.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .pNext = null,
            .flags = 0,
            .messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                             vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                             vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                          vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                          vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = debug.getDebugCallback(),
            .pUserData = null,
        };
        
        // Link debug messenger create info to instance create info if validation is enabled
        if (enable_validation) {
            std.debug.print("Enabling debug messenger for validation layers\n", .{});
            instance_create_info.pNext = &debug_create_info;
        }
    } else if (enable_validation) {
        std.debug.print("Warning: Validation layers requested but debug utils extension not available\n", .{});
    }

    var instance: vk.VkInstance = undefined;
    const create_instance_result = vk.vkCreateInstance(&instance_create_info, null, &instance);
    if (create_instance_result != vk.VK_SUCCESS) {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{create_instance_result});
        
        // Try to get more detailed error information
        if (debug_utils_available) {
            std.debug.print("Debug utils are available but instance creation still failed\n", .{});
            
            // Try to create a temporary instance without validation to see if that works
            var temp_create_info = instance_create_info;
            temp_create_info.enabledLayerCount = 0;
            temp_create_info.ppEnabledLayerNames = null;
            
            const temp_result = vk.vkCreateInstance(&temp_create_info, null, &instance);
            if (temp_result == vk.VK_SUCCESS) {
                std.debug.print("Successfully created instance without validation layers\n", .{});
                vk.vkDestroyInstance(instance, null);
                return error.ValidationLayersNotAvailable;
            } else {
                std.debug.print("Also failed to create instance without validation layers: {}\n", .{temp_result});
            }
        }
        
        return error.InstanceCreationFailed;
    }
    defer vk.vkDestroyInstance(instance, null);

    // Pick a physical device
    std.debug.print("Finding physical device...\n", .{});
    var device_count: u32 = 0;
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
    if (device_count == 0) {
        std.debug.print("No Vulkan devices found\n", .{});
        return error.NoVulkanDevicesFound;
    }

    const devices = try allocator.alloc(vk.VkPhysicalDevice, device_count);
    defer allocator.free(devices);
    _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);

    // Just use the first device for now
    const physical_device = devices[0];

    // Find a queue family with compute support
    std.debug.print("Finding compute queue family...\n", .{});
    var queue_family_count: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

    const queue_families = try allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
    defer allocator.free(queue_families);
    vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);

    var compute_queue_family: ?u32 = null;
    for (queue_families, 0..) |queue_family, i| {
        if ((queue_family.queueFlags & vk.VK_QUEUE_COMPUTE_BIT) != 0) {
            compute_queue_family = @as(u32, @intCast(i));
            break;
        }
    }

    if (compute_queue_family == null) {
        std.debug.print("No compute queue family found\n", .{});
        return error.NoComputeQueueFamily;
    }

    // Create logical device
    std.debug.print("Creating logical device...\n", .{});
    const queue_priorities = [_]f32{1.0};
    const queue_info = [_]vk.VkDeviceQueueCreateInfo{
        vk.VkDeviceQueueCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = compute_queue_family.?,
            .queueCount = 1,
            .pQueuePriorities = &queue_priorities,
        }
    };

    const device_create_info = vk.VkDeviceCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
        .pEnabledFeatures = null,
    };

    var device: vk.VkDevice = undefined;
    if (vk.vkCreateDevice(physical_device, &device_create_info, null, &device) != vk.VK_SUCCESS) {
        std.debug.print("Failed to create logical device\n", .{});
        return error.DeviceCreationFailed;
    }
    defer vk.vkDestroyDevice(device, null);

    // Get the compute queue
    std.debug.print("Getting compute queue...\n", .{});
    var queue: vk.VkQueue = undefined;
    vk.vkGetDeviceQueue(device, compute_queue_family.?, 0, &queue);

    // 4. Create input/output buffers
    std.debug.print("Creating input buffer...\n", .{});
    
    const buffer_size = @as(u64, @sizeOf(f32)) * TENSOR_SIZE;
    
    // Create input buffer
    var input_buffer = try memory.Buffer.init(
        device,
        physical_device,
        buffer_size,
        vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );
    defer input_buffer.deinit(device);
    
    // Create output buffer
    var output_buffer = try memory.Buffer.init(
        device,
        physical_device,
        buffer_size,
        vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
    );
    defer output_buffer.deinit(device);
    
    // Map and initialize input buffer
    std.debug.print("Mapping input buffer...\n", .{});
    const input_data_ptr = try input_buffer.map(device, 0, 0);
    const input_data = @as([*]f32, @ptrCast(@alignCast(input_data_ptr)))[0..TENSOR_SIZE];
    defer {
        std.debug.print("Unmapping input buffer...\n", .{});
        input_buffer.unmap(device);
    }
    
    std.debug.print("Initializing input data...\n", .{});
    
    for (0..TENSOR_SIZE) |i| {
        input_data[i] = @as(f32, @floatFromInt(i));
    }
    std.debug.print("Input data initialized with {} elements\n", .{TENSOR_SIZE});
    
    std.debug.print("Input data initialized. First few values: {d:.2} {d:.2} {d:.2} {d:.2}\n", 
        .{input_data[0], input_data[1], input_data[2], input_data[3]});
    
    // 6. Create compute pipeline
    std.debug.print("Creating compute pipeline...\n", .{});
    
    // Define descriptor set layout bindings for input and output buffers
    const bindings = [_]vk.VkDescriptorSetLayoutBinding{
        // Input buffer binding
        .{
            .binding = 0,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        // Output buffer binding
        .{
            .binding = 1,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
    };
    
    // TODO: Load shader code from file or embedded
    const shader_code = [_]u32{0x07230203, 0x00010000, 0x00080001, 0x0000001e, 0x00000000, 0x00020011, 0x00000001, 0x0006000b, 0x00000001, 0x4c534c47, 0x6474732e, 0x3035342e, 0x00000000, 0x0003000e, 0x00000000, 0x00000001, 0x0006000f, 0x00000005, 0x00000004, 0x6e69616d, 0x00000000, 0x0000000d, 0x00060010, 0x00000004, 0x00000011, 0x00000001, 0x00000001, 0x00000001, 0x00030003, 0x00000002, 0x000001c2, 0x00040005, 0x00000004, 0x6e69616d, 0x00000000, 0x00050005, 0x00000009, 0x726f6f66, 0x6e696d61, 0x00000000, 0x00050005, 0x0000000d, 0x67617266, 0x6f6c6f43, 0x00000072, 0x00040047, 0x0000000d, 0x0000000b, 0x0000001c, 0x00020013, 0x00000002, 0x00030021, 0x00000003, 0x00000002, 0x00030016, 0x00000006, 0x00000020, 0x00040017, 0x00000007, 0x00000006, 0x00000004, 0x00040020, 0x00000008, 0x00000007, 0x00000007, 0x0004002b, 0x00000006, 0x0000000a, 0x3f800000, 0x0004002b, 0x00000006, 0x0000000c, 0x00000000, 0x00040020, 0x0000000e, 0x00000001, 0x00000007, 0x0004003b, 0x0000000e, 0x0000000f, 0x00000001, 0x0004002b, 0x00000006, 0x00000013, 0x3f000000, 0x00050036, 0x00000002, 0x00000004, 0x00000000, 0x00000003, 0x000200f8, 0x00000005, 0x0004003b, 0x00000008, 0x00000009, 0x00000007, 0x0004003d, 0x00000007, 0x00000010, 0x0000000f, 0x0005008e, 0x00000007, 0x00000011, 0x00000010, 0x00000013, 0x00050081, 0x00000007, 0x00000012, 0x00000011, 0x0000000a, 0x0003003e, 0x00000009, 0x00000012, 0x000100fd, 0x00010038};
    
    // Create the compute pipeline
    var compute_pipeline = try pipeline.ComputePipeline.init(
        device,
        &shader_code,
        &bindings,
    );
    defer compute_pipeline.deinit();
    
    std.debug.print("Compute pipeline created successfully!\n", .{});
    
    // 7. Create command buffer and dispatch compute
    std.debug.print("Dispatching compute...\n", .{});
    
    // TODO: Implement command buffer recording and submission
    // This requires creating a command pool, allocating command buffers,
    // recording the dispatch command, and submitting it to the queue
    
    // 8. Read back results and verify
    std.debug.print("Verifying results...\n", .{});
    
    // TODO: Map the output buffer and verify the results
    
    std.debug.print("Test completed successfully!\n", .{});
}
