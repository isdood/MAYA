// src/vulkan/compute/context.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

// Import Vulkan bindings using C import
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

// Alias the C Vulkan types to match our existing code
const vk = c;

pub const VulkanError = error {
    InitializationFailed,
    NoPhysicalDevicesFound,
    NoSuitableDevice,
    DeviceCreationFailed,
    QueueCreationFailed,
    CommandPoolCreationFailed,
    PipelineCacheCreationFailed,
    DebugUtilsMessengerCreationFailed,
    ExtensionNotPresent,
};

pub const VulkanContext = struct {
    instance: ?vk.VkInstance,
    physical_device: ?vk.VkPhysicalDevice,
    device: ?vk.VkDevice,
    compute_queue: ?vk.VkQueue,
    compute_queue_family_index: ?u32,
    command_pool: ?vk.VkCommandPool,
    pipeline_cache: ?vk.VkPipelineCache,
    debug_messenger: ?vk.VkDebugUtilsMessengerEXT,
    allocator: std.mem.Allocator,
    enable_validation: bool,

    // Debug callback function for Vulkan validation layers (temporarily disabled)
    fn debugCallback(
        messageSeverity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
        messageType: vk.VkDebugUtilsMessageTypeFlagsEXT,
        pCallbackData: ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
        pUserData: ?*anyopaque,
    ) callconv(.C) vk.VkBool32 {
        _ = messageSeverity;
        _ = messageType;
        _ = pCallbackData;
        _ = pUserData;
        return vk.VK_FALSE;
    }
    
    fn printVulkanError(self: *VulkanContext, result: vk.VkResult) void {
        _ = self; // Unused parameter
        std.debug.print("Vulkan Error: ", .{});
        
        switch (result) {
            vk.VK_ERROR_OUT_OF_HOST_MEMORY => {
                std.debug.print("Out of host memory\n", .{});
            },
            vk.VK_ERROR_OUT_OF_DEVICE_MEMORY => {
                std.debug.print("Out of device memory\n", .{});
            },
            vk.VK_ERROR_INITIALIZATION_FAILED => {
                std.debug.print("Initialization failed\n", .{});
                std.debug.print("  - Check if Vulkan is properly installed on your system\n", .{});
                std.debug.print("  - Make sure your GPU supports Vulkan\n", .{});
                std.debug.print("  - Verify that your GPU drivers are up to date\n", .{});
            },
            vk.VK_ERROR_LAYER_NOT_PRESENT => {
                std.debug.print("Layer not present\n", .{});
                std.debug.print("  - Make sure you have installed the Vulkan SDK\n", .{});
            },
            vk.VK_ERROR_EXTENSION_NOT_PRESENT => {
                std.debug.print("Extension not present\n", .{});
                std.debug.print("  - Required Vulkan extensions are not supported\n", .{});
            },
            vk.VK_ERROR_INCOMPATIBLE_DRIVER => {
                std.debug.print("Incompatible driver\n", .{});
                std.debug.print("  - Your GPU driver may not support the requested Vulkan version\n", .{});
                std.debug.print("  - Try updating your graphics drivers\n", .{});
            },
            else => {
                std.debug.print("Unknown error ({})\n", .{result});
            },
        }
    }

    pub fn init(allocator: std.mem.Allocator) !VulkanContext {
        std.debug.print("Creating Vulkan instance...\n", .{});
        var self = VulkanContext{
            .instance = null,
            .physical_device = null,
            .device = null,
            .compute_queue = null,
            .compute_queue_family_index = null,
            .command_pool = null,
            .pipeline_cache = null,
            .debug_messenger = null,
            .allocator = allocator,
            .enable_validation = false,  // Disable validation for now to simplify
        };
        try self.initVulkan();
        return self;
    }


    // Helper function to check if an extension is available
    fn isExtensionAvailable(extensions: []const [*:0]const u8, required: []const u8) bool {
        for (extensions) |ext| {
            if (std.mem.eql(u8, std.mem.span(ext), required)) {
                return true;
            }
        }
        return false;
    }
    
    pub fn initVulkan(self: *VulkanContext) !void {
        std.debug.print("=== Starting Vulkan Initialization ===\n", .{});
        
        // 1. Create application info
        std.debug.print("1. Creating application info...\n", .{});
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "MAYA",
            .applicationVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
            .pEngineName = "MAYA Engine",
            .engineVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
        };
        
        // 2. Try with no extensions first
        const required_extensions = [_][*:0]const u8{};
        
        // 3. Create instance with minimal configuration
        std.debug.print("\n2. Creating Vulkan instance...\n", .{});
        std.debug.print("   Using {} extensions\n", .{required_extensions.len});
        
        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @as(u32, required_extensions.len),
            .ppEnabledExtensionNames = if (required_extensions.len > 0) &required_extensions[0] else null,
        };
        
        var instance: vk.VkInstance = undefined;
        const result = vk.vkCreateInstance(&create_info, null, @ptrCast(&instance));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create Vulkan instance: {s}\n", .{
                switch (result) {
                    vk.VK_ERROR_OUT_OF_HOST_MEMORY => "VK_ERROR_OUT_OF_HOST_MEMORY",
                    vk.VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
                    vk.VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
                    vk.VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
                    vk.VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
                    vk.VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
                    else => "Unknown error",
                }
            });
            return VulkanError.InitializationFailed;
        }
        
        self.instance = instance;
        std.debug.print("\n3. Vulkan instance created successfully!\n", .{});
        
        // 4. Initialize the rest of Vulkan
        std.debug.print("\n4. Initializing Vulkan components...\n", .{});
        
        // 5. Continue with the rest of Vulkan initialization
                    vk.VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
                    vk.VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
                    vk.VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
                    vk.VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
                    vk.VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
                    else => "Unknown error",
                }
            });
            return VulkanError.InitializationFailed;
        }
        
        self.instance = instance;
        std.debug.print("\n4. Vulkan instance created successfully!\n", .{});
        
        // 6. Initialize the rest of Vulkan
        std.debug.print("\n5. Initializing Vulkan components...\n", .{});
        
        std.debug.print("   Picking physical device...\n", .{});
        try self.pickPhysicalDevice();
        
        std.debug.print("   Creating logical device...\n", .{});
        try self.createLogicalDevice();
        
        std.debug.print("   Creating command pool...\n", .{});
        try self.createCommandPool();
        
        // Initialize pipeline cache
        self.pipeline_cache = null;  // Will be created when needed
        
        std.debug.print("\n=== Vulkan initialization completed successfully ===\n\n", .{});
    }
    
    fn pickPhysicalDevice(self: *VulkanContext) !void {
        const instance = self.instance orelse return error.InstanceNotInitialized;
        
        var device_count: u32 = 0;
        var result = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
        if (result != vk.VK_SUCCESS or device_count == 0) {
            return error.NoPhysicalDevicesFound;
        }
        
        // For now, just pick the first available device
        const devices = try self.allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer self.allocator.free(devices);
        
        result = vk.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToEnumerateDevices;
        }
        
        self.physical_device = devices[0];
    }
    
    fn findComputeQueueFamily(self: *VulkanContext) !u32 {
        const physical_device = self.physical_device orelse return error.PhysicalDeviceNotSelected;
        
        var queue_family_count: u32 = 0;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
        
        const queue_family_properties = try self.allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer self.allocator.free(queue_family_properties);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_family_properties.ptr);
        
        for (queue_family_properties, 0..) |props, i| {
            const queue_family_index = @as(u32, @intCast(i));
            if ((props.queueFlags & vk.VK_QUEUE_COMPUTE_BIT) != 0) {
                return queue_family_index;
            }
        }
        
        return error.NoComputeQueue;
    }
    
    fn createLogicalDevice(self: *VulkanContext) !void {
        const physical_device = self.physical_device orelse return error.PhysicalDeviceNotSelected;
        
        // Find a queue family that supports compute operations
        const queue_family_index = try self.findComputeQueueFamily();
        self.compute_queue_family_index = queue_family_index;
        
        // For now, just request a single compute queue
        const queue_priority = [_]f32{1.0};
        const queue_create_info = vk.VkDeviceQueueCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = queue_family_index,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };
        
        const device_features = vk.VkPhysicalDeviceFeatures{
            .robustBufferAccess = vk.VK_FALSE,
            .fullDrawIndexUint32 = vk.VK_FALSE,
            .imageCubeArray = vk.VK_FALSE,
            .independentBlend = vk.VK_FALSE,
            .geometryShader = vk.VK_FALSE,
            .tessellationShader = vk.VK_FALSE,
            .sampleRateShading = vk.VK_FALSE,
            .dualSrcBlend = vk.VK_FALSE,
            .logicOp = vk.VK_FALSE,
            .multiDrawIndirect = vk.VK_FALSE,
            .drawIndirectFirstInstance = vk.VK_FALSE,
            .depthClamp = vk.VK_FALSE,
            .depthBiasClamp = vk.VK_FALSE,
            .fillModeNonSolid = vk.VK_FALSE,
            .depthBounds = vk.VK_FALSE,
            .wideLines = vk.VK_FALSE,
            .largePoints = vk.VK_FALSE,
            .alphaToOne = vk.VK_FALSE,
            .multiViewport = vk.VK_FALSE,
            .samplerAnisotropy = vk.VK_FALSE,
            .textureCompressionETC2 = vk.VK_FALSE,
            .textureCompressionASTC_LDR = vk.VK_FALSE,
            .textureCompressionBC = vk.VK_FALSE,
            .occlusionQueryPrecise = vk.VK_FALSE,
            .pipelineStatisticsQuery = vk.VK_FALSE,
            .vertexPipelineStoresAndAtomics = vk.VK_FALSE,
            .fragmentStoresAndAtomics = vk.VK_FALSE,
            .shaderTessellationAndGeometryPointSize = vk.VK_FALSE,
            .shaderImageGatherExtended = vk.VK_FALSE,
            .shaderStorageImageExtendedFormats = vk.VK_FALSE,
            .shaderStorageImageMultisample = vk.VK_FALSE,
            .shaderStorageImageReadWithoutFormat = vk.VK_FALSE,
            .shaderStorageImageWriteWithoutFormat = vk.VK_FALSE,
            .shaderUniformBufferArrayDynamicIndexing = vk.VK_FALSE,
            .shaderSampledImageArrayDynamicIndexing = vk.VK_FALSE,
            .shaderStorageBufferArrayDynamicIndexing = vk.VK_FALSE,
            .shaderStorageImageArrayDynamicIndexing = vk.VK_FALSE,
            .shaderClipDistance = vk.VK_FALSE,
            .shaderCullDistance = vk.VK_FALSE,
            .shaderFloat64 = vk.VK_FALSE,
            .shaderInt64 = vk.VK_FALSE,
            .shaderInt16 = vk.VK_FALSE,
            .shaderResourceResidency = vk.VK_FALSE,
            .shaderResourceMinLod = vk.VK_FALSE,
            .sparseBinding = vk.VK_FALSE,
            .sparseResidencyBuffer = vk.VK_FALSE,
            .sparseResidencyImage2D = vk.VK_FALSE,
            .sparseResidencyImage3D = vk.VK_FALSE,
            .sparseResidency2Samples = vk.VK_FALSE,
            .sparseResidency4Samples = vk.VK_FALSE,
            .sparseResidency8Samples = vk.VK_FALSE,
            .sparseResidency16Samples = vk.VK_FALSE,
            .sparseResidencyAliased = vk.VK_FALSE,
            .variableMultisampleRate = vk.VK_FALSE,
            .inheritedQueries = vk.VK_FALSE,
        };
        
        const device_extensions = [_][*:0]const u8{
            vk.VK_KHR_STORAGE_BUFFER_STORAGE_CLASS_EXTENSION_NAME,
        };
        
        const device_create_info = vk.VkDeviceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @intCast(device_extensions.len),
            .ppEnabledExtensionNames = &device_extensions[0],
            .pEnabledFeatures = &device_features,
        };
        
        var device: vk.VkDevice = undefined;
        const result = vk.vkCreateDevice(physical_device, &device_create_info, null, &device);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToCreateLogicalDevice;
        }
        
        self.device = device;
        
        // Get the compute queue
        var queue: vk.VkQueue = undefined;
        vk.vkGetDeviceQueue(device, 0, 0, &queue); // Assuming first queue family, first queue
        self.compute_queue = queue;
    }
    
    fn createCommandPool(self: *VulkanContext) !void {
        const device = self.device orelse return error.DeviceNotInitialized;
        
        const pool_info = vk.VkCommandPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = 0, // Assuming first queue family
        };
        
        var command_pool: vk.VkCommandPool = undefined;
        const result = vk.vkCreateCommandPool(device, &pool_info, null, &command_pool);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToCreateCommandPool;
        }
        
        self.command_pool = command_pool;
    }
    
    fn createPipelineCache(self: *VulkanContext) !void {
        const device = self.device orelse return error.DeviceNotInitialized;
        
        const cache_info = vk.VkPipelineCacheCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .initialDataSize = 0,
            .pInitialData = null,
        };
        
        var pipeline_cache: vk.VkPipelineCache = undefined;
        const result = vk.vkCreatePipelineCache(device, &cache_info, null, &pipeline_cache);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToCreatePipelineCache;
        }
        
        self.pipeline_cache = pipeline_cache;
    }
    
    pub fn createCommandBuffer(self: *VulkanContext) !vk.VkCommandBuffer {
        const device = self.device orelse return error.DeviceNotInitialized;
        const command_pool = self.command_pool orelse return error.CommandPoolNotInitialized;
        
        const alloc_info = vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };
        
        var command_buffer: vk.VkCommandBuffer = undefined;
        const result = vk.vkAllocateCommandBuffers(device, &alloc_info, &command_buffer);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToAllocateCommandBuffer;
        }
        
        // Begin command buffer
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        };
        
        const begin_result = vk.vkBeginCommandBuffer(command_buffer, &begin_info);
        if (begin_result != vk.VK_SUCCESS) {
            return error.FailedToBeginCommandBuffer;
        }
        
        return command_buffer;
    }
    
    pub fn destroyCommandBuffer(self: *VulkanContext, command_buffer: vk.VkCommandBuffer) void {
        const device = self.device orelse return;
        const command_pool = self.command_pool orelse return;
        
        // End command buffer if still recording
        _ = vk.vkEndCommandBuffer(command_buffer);
        
        // Free the command buffer
        const command_buffers = [_]vk.VkCommandBuffer{command_buffer};
        vk.vkFreeCommandBuffers(device, command_pool, 1, &command_buffers[0]);
    }
    
    pub fn submitCommandBuffer(self: *VulkanContext, command_buffer: vk.VkCommandBuffer) !void {
        _ = self.device orelse return error.DeviceNotInitialized;
        const queue = self.compute_queue orelse return error.QueueNotInitialized;
        
        // End command buffer if still recording
        _ = vk.vkEndCommandBuffer(command_buffer);
        
        // Submit the command buffer
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
        
        const result = vk.vkQueueSubmit(queue, 1, &submit_info, null);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToSubmitCommandBuffer;
        }
        
        // Wait for the queue to finish
        _ = vk.vkQueueWaitIdle(queue);
    }
    
    pub fn deinit(self: *VulkanContext) void {
        if (self.device) |device| {
            if (self.command_pool) |command_pool| {
                vk.vkDestroyCommandPool(device, command_pool, null);
            }
            
            if (self.pipeline_cache) |pipeline_cache| {
                vk.vkDestroyPipelineCache(device, pipeline_cache, null);
            }
            
            vk.vkDestroyDevice(device, null);
        }
        
        if (self.instance) |instance| {
            vk.vkDestroyInstance(instance, null);
        }
    }
};
