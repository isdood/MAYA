// src/vulkan/compute/context.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

// Import the vk module that was provided by the build system
const vk = @import("vk");

pub const VulkanError = error {
    InitializationFailed,
    NoPhysicalDevicesFound,
    NoSuitableDevice,
    DeviceCreationFailed,
    QueueCreationFailed,
    CommandPoolCreationFailed,
    PipelineCacheCreationFailed,
    DebugUtilsMessengerCreationFailed,
};

pub const VulkanContext = struct {
    instance: ?vk.VkInstance,
    physical_device: ?vk.VkPhysicalDevice,
    device: ?vk.VkDevice,
    compute_queue: ?vk.VkQueue,
    command_pool: ?vk.VkCommandPool,
    pipeline_cache: ?vk.VkPipelineCache,
    debug_messenger: ?vk.VkDebugUtilsMessengerEXT,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !VulkanContext {
        var self = VulkanContext{
            .instance = null,
            .physical_device = null,
            .device = null,
            .compute_queue = null,
            .command_pool = null,
            .pipeline_cache = null,
            .debug_messenger = null,
            .allocator = allocator,
        };
        try self.initVulkan();
        return self;
    }

    fn initVulkan(self: *VulkanContext) !void {
        std.debug.print("Initializing Vulkan...\n", .{});

        // Try to dynamically load vkEnumerateInstanceVersion
        const vk_lib = std.DynLib.openZ("libvulkan.so.1") catch |err| {
            std.debug.print("Failed to load Vulkan library: {s}\n", .{@errorName(err)});
            return error.VulkanNotAvailable;
        };
        defer vk_lib.close();

        // Get the vkGetInstanceProcAddr function
        const vkGetInstanceProcAddr = vk_lib.lookup(
            *const fn (instance: vk.VkInstance, pName: [*:0]const u8) callconv(.C) ?*const anyopaque,
            "vkGetInstanceProcAddr",
        ) orelse {
            std.debug.print("Failed to find vkGetInstanceProcAddr\n", .{});
            return error.VulkanNotAvailable;
        };

        // Get vkEnumerateInstanceVersion
        const vkEnumerateInstanceVersion = @as(
            *const fn (pApiVersion: *u32) callconv(.C) vk.VkResult,
            @ptrCast(vkGetInstanceProcAddr(null, "vkEnumerateInstanceVersion") orelse {
                std.debug.print("vkEnumerateInstanceVersion not available\n", .{});
                return error.VulkanNotAvailable;
            }),
        );

        // Check Vulkan version
        std.debug.print("Checking Vulkan version...\n", .{});
        var instance_version: u32 = 0;
        const version_result = vkEnumerateInstanceVersion(&instance_version);
        std.debug.print("  vkEnumerateInstanceVersion result: {}\n", .{version_result});
        if (version_result != vk.VK_SUCCESS) {
            std.debug.print("  Failed to get Vulkan version: {}\n", .{version_result});
            return error.InitializationFailed;
        }

        const major = vk.VK_API_VERSION_MAJOR(instance_version);
        const minor = vk.VK_API_VERSION_MINOR(instance_version);
        const patch = vk.VK_API_VERSION_PATCH(instance_version);
        std.debug.print("  Vulkan {}.{}.{} detected\n", .{ major, minor, patch });
        
        // Check for required Vulkan version
        const required_version = vk.VK_MAKE_VERSION(1, 0, 0);
        if (instance_version < required_version) {
            std.debug.print("  Error: Vulkan 1.0 or later is required\n", .{});
            return error.VulkanVersionTooLow;
        }

        // Create Vulkan instance
        std.debug.print("Creating Vulkan instance...\n", .{});
        
        const app_name = "MAYA";
        const engine_name = "MAYA Engine";
        const app_version = vk.VK_MAKE_VERSION(1, 0, 0);
        const engine_version = vk.VK_MAKE_VERSION(1, 0, 0);
        
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = app_name.ptr,
            .applicationVersion = app_version,
            .pEngineName = engine_name.ptr,
            .engineVersion = engine_version,
            .apiVersion = vk.VK_API_VERSION_1_0,
        };
        
        std.debug.print("  Application: {s} v{}.{}.{}\n", .{
            app_name,
            vk.VK_API_VERSION_MAJOR(app_version),
            vk.VK_API_VERSION_MINOR(app_version),
            vk.VK_API_VERSION_PATCH(app_version),
        });
        std.debug.print("  Engine: {s} v{}.{}.{}\n", .{
            engine_name,
            vk.VK_API_VERSION_MAJOR(engine_version),
            vk.VK_API_VERSION_MINOR(engine_version),
            vk.VK_API_VERSION_PATCH(engine_version),
        });

        // Required extensions
        const enabled_extensions = [_][*:0]const u8{
            vk.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
        };
        
        // Debug print enabled extensions
        std.debug.print("  Required instance extensions ({}):\n", .{enabled_extensions.len});
        for (enabled_extensions) |ext| {
            std.debug.print("    {s}\n", .{ext});
        }

        // List required extensions
        std.debug.print("  Required instance extensions:\n", .{});
        for (enabled_extensions) |ext| {
            std.debug.print("    {s}\n", .{ext});
        }
        
        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @intCast(enabled_extensions.len),
            .ppEnabledExtensionNames = &enabled_extensions[0],
        };
        
        std.debug.print("  Creating Vulkan instance...\n", .{});
        var instance: vk.VkInstance = undefined;
        std.debug.print("  Calling vkCreateInstance...\n", .{});
        const create_result = vk.vkCreateInstance(&create_info, null, &instance);
        std.debug.print("  vkCreateInstance result: {}\n", .{create_result});
        if (create_result != vk.VK_SUCCESS) {
            std.debug.print("  Failed to create Vulkan instance: {}\n", .{create_result});
            
            // Try to get more detailed error information
            if (create_result == vk.VK_ERROR_EXTENSION_NOT_PRESENT) {
                std.debug.print("  One or more required extensions are not available\n", .{});
                
                // List available extensions
                var extension_count: u32 = 0;
                _ = vk.vkEnumerateInstanceExtensionProperties(null, &extension_count, null);
                
                if (extension_count > 0) {
                    const extensions = try self.allocator.alloc(vk.VkExtensionProperties, extension_count);
                    defer self.allocator.free(extensions);
                    
                    _ = vk.vkEnumerateInstanceExtensionProperties(null, &extension_count, extensions.ptr);
                    
                    std.debug.print("  Available instance extensions ({}):\n", .{extension_count});
                    for (extensions) |ext| {
                        const ext_name = std.mem.sliceTo(&ext.extensionName, 0);
                        std.debug.print("    {s}\n", .{ext_name});
                    }
                }
            }
            
            return error.InitializationFailed;
        }

        self.instance = instance;
        std.debug.print("Vulkan instance created successfully\n", .{});

        // Pick physical device
        try self.pickPhysicalDevice();
        
        // Create logical device
        try self.createLogicalDevice();
        
        // Create command pool
        try self.createCommandPool();
        
        // Create pipeline cache
        try self.createPipelineCache();
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
    
    fn createLogicalDevice(self: *VulkanContext) !void {
        const physical_device = self.physical_device orelse return error.PhysicalDeviceNotSelected;
        
        // For now, just request a single compute queue
        const queue_priority = [_]f32{1.0};
        const queue_create_info = vk.VkDeviceQueueCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = 0, // Assuming first queue family supports compute
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
        if (self.instance) |instance| {
            // Clean up device resources first
            if (self.device) |device| {
                if (self.pipeline_cache) |pipeline_cache| {
                    vk.vkDestroyPipelineCache(device, pipeline_cache, null);
                }
                
                if (self.command_pool) |command_pool| {
                    vk.vkDestroyCommandPool(device, command_pool, null);
                }
                
                vk.vkDestroyDevice(device, null);
            }
            
            // Clean up debug messenger if it exists
            if (self.debug_messenger) |debug_messenger| {
                const debug_utils = vk.loadDebugUtilsFunctions(instance);
                debug_utils.destroyDebugUtilsMessengerEXT(instance, debug_messenger, null);
            }
            
            // Finally destroy the instance
            vk.vkDestroyInstance(instance, null);
            self.instance = null;
            std.debug.print("Vulkan instance destroyed\n", .{});
        }
    }
};
