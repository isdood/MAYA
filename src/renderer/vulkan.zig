const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const glfw = @import("glfw");
const Window = @import("window.zig").Window;

const VulkanError = error{
    ValidationLayerNotAvailable,
    FailedToLoadDebugUtilsMessenger,
    FailedToCreateInstance,
    FailedToCreateSurface,
    FailedToPickPhysicalDevice,
    FailedToCreateLogicalDevice,
    FailedToCreateSwapChain,
    FailedToCreateImageViews,
    FailedToCreateRenderPass,
    FailedToCreateGraphicsPipeline,
    FailedToCreateFramebuffers,
    FailedToCreateCommandPool,
    FailedToCreateCommandBuffers,
    FailedToCreateSyncObjects,
    FailedToAcquireSwapChainImage,
    FailedToPresentSwapChainImage,
    OutOfMemory,
    DeviceLost,
    SurfaceLost,
    OutOfDate,
    Suboptimal,
    Unknown,
};

const LogLevel = enum {
    Debug,
    Info,
    Warning,
    Error,
    Fatal,
};

const VulkanRenderer = struct {
    instance: vk.VkInstance,
    surface: vk.VkSurfaceKHR,
    physical_device: vk.VkPhysicalDevice,
    device: vk.VkDevice,
    queue: vk.VkQueue,
    command_pool: vk.VkCommandPool,
    swapchain: vk.VkSwapchainKHR,
    swapchain_images: []vk.VkImage,
    swapchain_image_views: []vk.VkImageView,
    render_pass: vk.VkRenderPass,
    framebuffers: []vk.VkFramebuffer,
    pipeline: vk.VkPipeline,
    pipeline_layout: vk.VkPipelineLayout,
    vertex_buffer: vk.VkBuffer,
    vertex_buffer_memory: vk.VkDeviceMemory,
    command_buffers: []vk.VkCommandBuffer,
    image_available_semaphores: []vk.VkSemaphore,
    render_finished_semaphores: []vk.VkSemaphore,
    in_flight_fences: []vk.VkFence,
    current_frame: usize,
    window: *Window,
    framebuffer_resized: bool,
    debug_messenger: vk.VkDebugUtilsMessengerEXT,
    validation_layers_enabled: bool,
    allocator: std.mem.Allocator,
    logger: std.log.Logger,

    const MAX_FRAMES_IN_FLIGHT = 2;

    const VALIDATION_LAYERS = [_][*:0]const u8{
        "VK_LAYER_KHRONOS_validation",
    };

    const REQUIRED_DEVICE_EXTENSIONS = [_][*:0]const u8{
        vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };

    const REQUIRED_DEVICE_FEATURES = struct {
        const features = vk.VkPhysicalDeviceFeatures{
            // Enable features for better performance and quality
            .robustBufferAccess = vk.VK_TRUE,  // For safer buffer access
            .fullDrawIndexUint32 = vk.VK_TRUE, // Support for 32-bit indices
            .imageCubeArray = vk.VK_TRUE,      // For cube map textures
            .independentBlend = vk.VK_TRUE,    // For advanced blending
            .geometryShader = vk.VK_TRUE,      // For geometry shaders
            .tessellationShader = vk.VK_TRUE,  // For tessellation
            .sampleRateShading = vk.VK_TRUE,   // For per-sample shading
            .dualSrcBlend = vk.VK_TRUE,        // For advanced blending modes
            .logicOp = vk.VK_TRUE,             // For logical operations
            .multiDrawIndirect = vk.VK_TRUE,   // For efficient multi-draw
            .drawIndirectFirstInstance = vk.VK_TRUE, // For indirect drawing
            .depthClamp = vk.VK_TRUE,          // For depth clamping
            .depthBiasClamp = vk.VK_TRUE,      // For depth bias
            .fillModeNonSolid = vk.VK_TRUE,    // For wireframe/point rendering
            .depthBounds = vk.VK_TRUE,         // For depth bounds testing
            .wideLines = vk.VK_TRUE,           // For wide line rendering
            .largePoints = vk.VK_TRUE,         // For point sprites
            .alphaToOne = vk.VK_TRUE,          // For alpha-to-one
            .multiViewport = vk.VK_TRUE,       // For multiple viewports
            .samplerAnisotropy = vk.VK_TRUE,   // For anisotropic filtering
            .textureCompressionETC2 = vk.VK_TRUE, // For ETC2 texture compression
            .textureCompressionASTC_LDR = vk.VK_TRUE, // For ASTC texture compression
            .textureCompressionBC = vk.VK_TRUE, // For BC texture compression
            .occlusionQueryPrecise = vk.VK_TRUE, // For precise occlusion queries
            .pipelineStatisticsQuery = vk.VK_TRUE, // For pipeline statistics
            .vertexPipelineStoresAndAtomics = vk.VK_TRUE, // For vertex shader atomics
            .fragmentStoresAndAtomics = vk.VK_TRUE, // For fragment shader atomics
            .shaderTessellationAndGeometryPointSize = vk.VK_TRUE, // For point size in tess/geo shaders
            .shaderImageGatherExtended = vk.VK_TRUE, // For extended image gather
            .shaderStorageImageExtendedFormats = vk.VK_TRUE, // For extended storage image formats
            .shaderStorageImageMultisample = vk.VK_TRUE, // For multisample storage images
            .shaderStorageImageReadWithoutFormat = vk.VK_TRUE, // For formatless image reads
            .shaderStorageImageWriteWithoutFormat = vk.VK_TRUE, // For formatless image writes
            .shaderUniformBufferArrayDynamicIndexing = vk.VK_TRUE, // For dynamic indexing of uniform buffers
            .shaderSampledImageArrayDynamicIndexing = vk.VK_TRUE, // For dynamic indexing of sampled images
            .shaderStorageBufferArrayDynamicIndexing = vk.VK_TRUE, // For dynamic indexing of storage buffers
            .shaderStorageImageArrayDynamicIndexing = vk.VK_TRUE, // For dynamic indexing of storage images
            .shaderClipDistance = vk.VK_TRUE,  // For clip distances
            .shaderCullDistance = vk.VK_TRUE,  // For cull distances
            .shaderFloat64 = vk.VK_TRUE,       // For double precision
            .shaderInt64 = vk.VK_TRUE,         // For 64-bit integers
            .shaderInt16 = vk.VK_TRUE,         // For 16-bit integers
            .shaderResourceResidency = vk.VK_TRUE, // For resource residency
            .shaderResourceMinLod = vk.VK_TRUE, // For minimum LOD
            .sparseBinding = vk.VK_TRUE,       // For sparse resources
            .sparseResidencyBuffer = vk.VK_TRUE, // For sparse buffer residency
            .sparseResidencyImage2D = vk.VK_TRUE, // For sparse 2D image residency
            .sparseResidencyImage3D = vk.VK_TRUE, // For sparse 3D image residency
            .sparseResidency2Samples = vk.VK_TRUE, // For sparse 2-sample residency
            .sparseResidency4Samples = vk.VK_TRUE, // For sparse 4-sample residency
            .sparseResidency8Samples = vk.VK_TRUE, // For sparse 8-sample residency
            .sparseResidency16Samples = vk.VK_TRUE, // For sparse 16-sample residency
            .sparseResidencyAliased = vk.VK_TRUE, // For sparse aliased residency
            .variableMultisampleRate = vk.VK_TRUE, // For variable multisample rates
            .inheritedQueries = vk.VK_TRUE,    // For inherited queries
        };
    };

    pub fn init(allocator: std.mem.Allocator, window: *Window) !*VulkanRenderer {
        var self = try allocator.create(VulkanRenderer);
        self.* = VulkanRenderer{
            .allocator = allocator,
            .logger = std.log.scoped(.vulkan),
            .instance = undefined,
            .surface = undefined,
            .physical_device = undefined,
            .device = undefined,
            .queue = undefined,
            .command_pool = undefined,
            .swapchain = undefined,
            .swapchain_images = undefined,
            .swapchain_image_views = undefined,
            .render_pass = undefined,
            .framebuffers = undefined,
            .pipeline = undefined,
            .pipeline_layout = undefined,
            .vertex_buffer = undefined,
            .vertex_buffer_memory = undefined,
            .command_buffers = undefined,
            .image_available_semaphores = undefined,
            .render_finished_semaphores = undefined,
            .in_flight_fences = undefined,
            .current_frame = 0,
            .window = window,
            .framebuffer_resized = false,
            .debug_messenger = undefined,
            .validation_layers_enabled = false,
        };

        self.logger.info("Initializing Vulkan renderer", .{});
        try self.createInstance();
        self.logger.info("Vulkan instance created", .{});

        try self.setupDebugMessenger();
        self.logger.info("Debug messenger setup complete", .{});

        try self.createSurface();
        self.logger.info("Surface created", .{});

        try self.pickPhysicalDevice();
        self.logger.info("Physical device selected", .{});

        try self.createLogicalDevice();
        self.logger.info("Logical device created", .{});

        try self.createSwapChain();
        self.logger.info("Swapchain created", .{});

        try self.createImageViews();
        self.logger.info("Image views created", .{});

        try self.createRenderPass();
        self.logger.info("Render pass created", .{});

        try self.createGraphicsPipeline();
        self.logger.info("Graphics pipeline created", .{});

        try self.createFramebuffers();
        self.logger.info("Framebuffers created", .{});

        try self.createCommandPool();
        self.logger.info("Command pool created", .{});

        try self.createVertexBuffer();
        self.logger.info("Vertex buffer created", .{});

        try self.createCommandBuffers();
        self.logger.info("Command buffers created", .{});

        try self.createSyncObjects();
        self.logger.info("Sync objects created", .{});

        // Set up resize callback
        try window.setResizeCallback(resizeCallback);

        return self;
    }

    pub fn deinit(self: *VulkanRenderer) void {
        self.logger.info("Shutting down Vulkan renderer", .{});

        try vk.vkDeviceWaitIdle(self.device);

        self.cleanupSwapChain();
        self.logger.info("Swapchain cleaned up", .{});

        if (VALIDATION_LAYERS.len > 0) {
            const destroy_debug_utils_messenger_ext = @ptrCast(
                fn (vk.VkInstance, vk.VkDebugUtilsMessengerEXT, ?*const vk.VkAllocationCallbacks) callconv(.C) void,
                vk.vkGetInstanceProcAddr(self.instance, "vkDestroyDebugUtilsMessengerEXT"),
            );

            if (destroy_debug_utils_messenger_ext) |func| {
                func(self.instance, self.debug_messenger, null);
                self.logger.info("Debug messenger destroyed", .{});
            }
        }

        // Cleanup sync objects
        for (self.image_available_semaphores) |semaphore| {
            vk.vkDestroySemaphore(self.device, semaphore, null);
        }
        for (self.render_finished_semaphores) |semaphore| {
            vk.vkDestroySemaphore(self.device, semaphore, null);
        }
        for (self.in_flight_fences) |fence| {
            vk.vkDestroyFence(self.device, fence, null);
        }

        // Cleanup command buffers and pool
        vk.vkFreeCommandBuffers(self.device, self.command_pool, @intCast(self.command_buffers.len), self.command_buffers.ptr);
        vk.vkDestroyCommandPool(self.device, self.command_pool, null);

        // Cleanup vertex buffer
        vk.vkDestroyBuffer(self.device, self.vertex_buffer, null);
        vk.vkFreeMemory(self.device, self.vertex_buffer_memory, null);

        // Cleanup pipeline
        vk.vkDestroyPipeline(self.device, self.pipeline, null);
        vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);

        // Cleanup framebuffers
        for (self.framebuffers) |framebuffer| {
            vk.vkDestroyFramebuffer(self.device, framebuffer, null);
        }

        // Cleanup render pass
        vk.vkDestroyRenderPass(self.device, self.render_pass, null);

        // Clean up image views
        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }

        // Cleanup swapchain
        vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);

        // Cleanup device and instance
        vk.vkDestroyDevice(self.device, null);
        vk.vkDestroyInstance(self.instance, null);

        self.allocator.destroy(self);
        self.logger.info("Vulkan renderer shutdown complete", .{});
    }

    fn checkValidationLayerSupport() !void {
        var layer_count: u32 = undefined;
        _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, null);

        var available_layers = try std.heap.page_allocator.alloc(vk.VkLayerProperties, layer_count);
        defer std.heap.page_allocator.free(available_layers);
        _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, available_layers.ptr);

        for (VALIDATION_LAYERS) |layer_name| {
            var layer_found = false;
            for (available_layers) |layer_properties| {
                if (std.mem.eql(u8, std.mem.span(layer_name), std.mem.span(&layer_properties.layerName))) {
                    layer_found = true;
                    break;
                }
            }
            if (!layer_found) {
                return error.ValidationLayerNotAvailable;
            }
        }
    }

    fn getRequiredExtensions() ![][]const u8 {
        var glfw_extension_count: u32 = undefined;
        const glfw_extensions = glfw.glfwGetRequiredInstanceExtensions(&glfw_extension_count);

        var extensions = std.ArrayList([]const u8).init(std.heap.page_allocator);
        defer extensions.deinit();

        var i: usize = 0;
        while (i < glfw_extension_count) : (i += 1) {
            try extensions.append(std.mem.span(glfw_extensions[i]));
        }

        if (VALIDATION_LAYERS.len > 0) {
            try extensions.append(vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        }

        return extensions.toOwnedSlice();
    }

    fn logVulkanResult(comptime level: LogLevel, result: vk.VkResult, comptime fmt: []const u8, args: anytype) void {
        const message = std.fmt.allocPrint(self.allocator, fmt, args) catch return;
        defer self.allocator.free(message);

        switch (level) {
            .Debug => self.logger.debug("{s}: {s}", .{ message, @tagName(result) }),
            .Info => self.logger.info("{s}: {s}", .{ message, @tagName(result) }),
            .Warning => self.logger.warn("{s}: {s}", .{ message, @tagName(result) }),
            .Error => self.logger.err("{s}: {s}", .{ message, @tagName(result) }),
            .Fatal => self.logger.err("{s}: {s}", .{ message, @tagName(result) }),
        }
    }

    fn checkVulkanResult(result: vk.VkResult) !void {
        switch (result) {
            vk.VK_SUCCESS => {},
            vk.VK_NOT_READY => return error.NotReady,
            vk.VK_TIMEOUT => return error.Timeout,
            vk.VK_EVENT_SET => return error.EventSet,
            vk.VK_EVENT_RESET => return error.EventReset,
            vk.VK_INCOMPLETE => return error.Incomplete,
            vk.VK_ERROR_OUT_OF_HOST_MEMORY => return error.OutOfHostMemory,
            vk.VK_ERROR_OUT_OF_DEVICE_MEMORY => return error.OutOfDeviceMemory,
            vk.VK_ERROR_INITIALIZATION_FAILED => return error.InitializationFailed,
            vk.VK_ERROR_DEVICE_LOST => return error.DeviceLost,
            vk.VK_ERROR_MEMORY_MAP_FAILED => return error.MemoryMapFailed,
            vk.VK_ERROR_LAYER_NOT_PRESENT => return error.LayerNotPresent,
            vk.VK_ERROR_EXTENSION_NOT_PRESENT => return error.ExtensionNotPresent,
            vk.VK_ERROR_FEATURE_NOT_PRESENT => return error.FeatureNotPresent,
            vk.VK_ERROR_INCOMPATIBLE_DRIVER => return error.IncompatibleDriver,
            vk.VK_ERROR_TOO_MANY_OBJECTS => return error.TooManyObjects,
            vk.VK_ERROR_FORMAT_NOT_SUPPORTED => return error.FormatNotSupported,
            vk.VK_ERROR_FRAGMENTED_POOL => return error.FragmentedPool,
            vk.VK_ERROR_UNKNOWN => return error.Unknown,
            vk.VK_ERROR_OUT_OF_POOL_MEMORY => return error.OutOfPoolMemory,
            vk.VK_ERROR_INVALID_EXTERNAL_HANDLE => return error.InvalidExternalHandle,
            vk.VK_ERROR_FRAGMENTATION => return error.Fragmentation,
            vk.VK_ERROR_INVALID_OPAQUE_CAPTURE_ADDRESS => return error.InvalidOpaqueCaptureAddress,
            vk.VK_ERROR_SURFACE_LOST_KHR => return error.SurfaceLost,
            vk.VK_ERROR_NATIVE_WINDOW_IN_USE_KHR => return error.NativeWindowInUse,
            vk.VK_SUBOPTIMAL_KHR => return error.Suboptimal,
            vk.VK_ERROR_OUT_OF_DATE_KHR => return error.OutOfDate,
            vk.VK_ERROR_INCOMPATIBLE_DISPLAY_KHR => return error.IncompatibleDisplay,
            vk.VK_ERROR_VALIDATION_FAILED_EXT => return error.ValidationFailed,
            vk.VK_ERROR_INVALID_SHADER_NV => return error.InvalidShader,
            else => return error.Unknown,
        }
    }

    fn debugCallback(
        message_severity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
        message_type: vk.VkDebugUtilsMessageTypeFlagsEXT,
        p_callback_data: ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
        p_user_data: ?*anyopaque,
    ) callconv(.C) vk.VkBool32 {
        _ = message_type;
        const self = @ptrCast(*VulkanRenderer, @alignCast(@alignOf(VulkanRenderer), p_user_data));

        const severity = switch (message_severity) {
            vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => LogLevel.Debug,
            vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => LogLevel.Info,
            vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => LogLevel.Warning,
            vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => LogLevel.Error,
            else => LogLevel.Info,
        };

        if (p_callback_data) |callback_data| {
            self.logVulkanResult(severity, vk.VK_SUCCESS, "{s}", .{std.mem.span(callback_data.pMessage)});
        }

        return vk.VK_FALSE;
    }

    fn setupDebugMessenger(self: *VulkanRenderer) !void {
        if (VALIDATION_LAYERS.len == 0) return;

        const create_info = vk.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = debugCallback,
            .pUserData = self,
            .pNext = null,
            .flags = 0,
        };

        const create_debug_utils_messenger_ext = @ptrCast(
            fn (vk.VkInstance, *const vk.VkDebugUtilsMessengerCreateInfoEXT, ?*const vk.VkAllocationCallbacks, *vk.VkDebugUtilsMessengerEXT) callconv(.C) vk.VkResult,
            vk.vkGetInstanceProcAddr(self.instance, "vkCreateDebugUtilsMessengerEXT"),
        );

        if (create_debug_utils_messenger_ext) |func| {
            try checkVulkanResult(func(
                self.instance,
                &create_info,
                null,
                &self.debug_messenger,
            ));
        } else {
            return error.FailedToLoadDebugUtilsMessenger;
        }
    }

    fn createInstance(self: *VulkanRenderer) !void {
        if (VALIDATION_LAYERS.len > 0) {
            try checkValidationLayerSupport();
        }

        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "MAYA",
            .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
            .pNext = null,
        };

        const extensions = try getRequiredExtensions();
        defer std.heap.page_allocator.free(extensions);

        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = @intCast(u32, extensions.len),
            .ppEnabledExtensionNames = @ptrCast([*]const [*:0]const u8, extensions.ptr),
            .enabledLayerCount = if (VALIDATION_LAYERS.len > 0) @intCast(u32, VALIDATION_LAYERS.len) else 0,
            .ppEnabledLayerNames = if (VALIDATION_LAYERS.len > 0) &VALIDATION_LAYERS else null,
            .pNext = null,
            .flags = 0,
        };

        try checkVulkanResult(vk.vkCreateInstance(&create_info, null, &self.instance));

        if (VALIDATION_LAYERS.len > 0) {
            try self.setupDebugMessenger();
        }
    }

    fn createSurface(self: *VulkanRenderer) !void {
        if (glfw.glfwCreateWindowSurface(self.instance, self.window.handle, null, &self.surface) != vk.VK_SUCCESS) {
            return error.SurfaceCreationFailed;
        }
    }

    fn checkDeviceExtensionSupport(physical_device: vk.VkPhysicalDevice) !void {
        var extension_count: u32 = undefined;
        _ = vk.vkEnumerateDeviceExtensionProperties(physical_device, null, &extension_count, null);

        var available_extensions = try std.heap.page_allocator.alloc(vk.VkExtensionProperties, extension_count);
        defer std.heap.page_allocator.free(available_extensions);
        _ = vk.vkEnumerateDeviceExtensionProperties(physical_device, null, &extension_count, available_extensions.ptr);

        for (REQUIRED_DEVICE_EXTENSIONS) |required_extension| {
            var extension_found = false;
            for (available_extensions) |extension| {
                if (std.mem.eql(u8, std.mem.span(required_extension), std.mem.span(&extension.extensionName))) {
                    extension_found = true;
                    break;
                }
            }
            if (!extension_found) {
                return error.DeviceExtensionNotSupported;
            }
        }
    }

    fn isDeviceSuitable(physical_device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) !bool {
        // Check device extension support
        try checkDeviceExtensionSupport(physical_device);

        // Check swapchain support
        var format_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null);
        if (format_count == 0) return false;

        var present_mode_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, null);
        if (present_mode_count == 0) return false;

        // Check device features
        var device_features: vk.VkPhysicalDeviceFeatures = undefined;
        vk.vkGetPhysicalDeviceFeatures(physical_device, &device_features);

        // Log available features
        self.logger.info("Device features:", .{});
        self.logger.info("  - Geometry shader: {}", .{device_features.geometryShader == vk.VK_TRUE});
        self.logger.info("  - Tessellation shader: {}", .{device_features.tessellationShader == vk.VK_TRUE});
        self.logger.info("  - Sampler anisotropy: {}", .{device_features.samplerAnisotropy == vk.VK_TRUE});
        self.logger.info("  - Multi viewport: {}", .{device_features.multiViewport == vk.VK_TRUE});
        self.logger.info("  - Shader float64: {}", .{device_features.shaderFloat64 == vk.VK_TRUE});
        self.logger.info("  - Shader int64: {}", .{device_features.shaderInt64 == vk.VK_TRUE});

        // Check if device supports required features
        if (!device_features.geometryShader or
            !device_features.tessellationShader or
            !device_features.samplerAnisotropy or
            !device_features.multiViewport)
        {
            self.logger.warn("Device does not support all required features", .{});
            return false;
        }

        // Log device properties
        var device_properties: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(physical_device, &device_properties);
        self.logger.info("Checking device: {s}", .{std.mem.span(&device_properties.deviceName)});

        // Check queue families
        var queue_family_count: u32 = undefined;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

        var queue_families = try std.heap.page_allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer std.heap.page_allocator.free(queue_families);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);

        var graphics_queue_found = false;
        var present_queue_found = false;

        for (queue_families) |queue_family, i| {
            if (queue_family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                graphics_queue_found = true;
            }

            var present_support: vk.VkBool32 = undefined;
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, @intCast(u32, i), surface, &present_support);
            if (present_support != 0) {
                present_queue_found = true;
            }

            if (graphics_queue_found and present_queue_found) break;
        }

        return graphics_queue_found and present_queue_found;
    }

    fn pickPhysicalDevice(self: *VulkanRenderer) !void {
        var device_count: u32 = undefined;
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, null);

        if (device_count == 0) {
            return error.NoVulkanDevicesFound;
        }

        var devices = try std.heap.page_allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer std.heap.page_allocator.free(devices);
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr);

        for (devices) |device| {
            if (try isDeviceSuitable(device, self.surface)) {
                self.physical_device = device;
                var device_properties: vk.VkPhysicalDeviceProperties = undefined;
                vk.vkGetPhysicalDeviceProperties(device, &device_properties);
                self.logger.info("Selected physical device: {s}", .{std.mem.span(&device_properties.deviceName)});
                return;
            }
        }

        return error.NoSuitableDeviceFound;
    }

    fn createLogicalDevice(self: *VulkanRenderer) !void {
        var queue_family_count: u32 = undefined;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, null);

        var queue_families = try std.heap.page_allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer std.heap.page_allocator.free(queue_families);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, queue_families.ptr);

        var graphics_queue_family: ?u32 = null;
        var present_queue_family: ?u32 = null;

        for (queue_families) |queue_family, i| {
            if (queue_family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                graphics_queue_family = @intCast(u32, i);
            }

            var present_support: vk.VkBool32 = undefined;
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(self.physical_device, @intCast(u32, i), self.surface, &present_support);
            if (present_support != 0) {
                present_queue_family = @intCast(u32, i);
            }

            if (graphics_queue_family != null and present_queue_family != null) break;
        }

        if (graphics_queue_family == null or present_queue_family == null) {
            return error.QueueFamilyNotFound;
        }

        const queue_priorities = [_]f32{1.0};
        var queue_create_infos = std.ArrayList(vk.VkDeviceQueueCreateInfo).init(self.allocator);
        defer queue_create_infos.deinit();

        const unique_queue_families = [_]u32{ graphics_queue_family.?, present_queue_family.? };
        for (unique_queue_families) |queue_family| {
            const queue_create_info = vk.VkDeviceQueueCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = queue_family,
                .queueCount = 1,
                .pQueuePriorities = &queue_priorities,
                .pNext = null,
                .flags = 0,
            };
            try queue_create_infos.append(queue_create_info);
        }

        const device_features = REQUIRED_DEVICE_FEATURES.features;

        const device_create_info = vk.VkDeviceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = @intCast(u32, queue_create_infos.items.len),
            .pQueueCreateInfos = queue_create_infos.items.ptr,
            .enabledExtensionCount = REQUIRED_DEVICE_EXTENSIONS.len,
            .ppEnabledExtensionNames = &REQUIRED_DEVICE_EXTENSIONS,
            .pEnabledFeatures = &device_features,
            .enabledLayerCount = if (VALIDATION_LAYERS.len > 0) @intCast(u32, VALIDATION_LAYERS.len) else 0,
            .ppEnabledLayerNames = if (VALIDATION_LAYERS.len > 0) &VALIDATION_LAYERS else null,
            .pNext = null,
            .flags = 0,
        };

        try checkVulkanResult(vk.vkCreateDevice(self.physical_device, &device_create_info, null, &self.device));

        vk.vkGetDeviceQueue(self.device, graphics_queue_family.?, 0, &self.queue);
    }

    fn createSwapChain(self: *VulkanRenderer) !void {
        // Basic swapchain creation - will be expanded
        var surface_capabilities: vk.VkSurfaceCapabilitiesKHR = undefined;
        _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.physical_device, self.surface, &surface_capabilities);

        const swapchain_create_info = vk.VkSwapchainCreateInfoKHR{
            .sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = self.surface,
            .minImageCount = surface_capabilities.minImageCount,
            .imageFormat = vk.VK_FORMAT_B8G8R8A8_UNORM,
            .imageColorSpace = vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            .imageExtent = surface_capabilities.currentExtent,
            .imageArrayLayers = 1,
            .imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .preTransform = surface_capabilities.currentTransform,
            .compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = vk.VK_PRESENT_MODE_FIFO_KHR,
            .clipped = vk.VK_TRUE,
            .oldSwapchain = null,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateSwapchainKHR(self.device, &swapchain_create_info, null, &self.swapchain) != vk.VK_SUCCESS) {
            return error.SwapchainCreationFailed;
        }

        // Get swapchain images
        var image_count: u32 = 0;
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count, null);
        self.swapchain_images = try std.heap.page_allocator.alloc(vk.VkImage, image_count);
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count, self.swapchain_images.ptr);
    }

    fn createImageViews(self: *VulkanRenderer) !void {
        self.swapchain_image_views = try std.heap.page_allocator.alloc(vk.VkImageView, self.swapchain_images.len);

        for (self.swapchain_images, 0..) |image, i| {
            const create_info = vk.VkImageViewCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = image,
                .viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
                .format = vk.VK_FORMAT_B8G8R8A8_UNORM,
                .components = vk.VkComponentMapping{
                    .r = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = vk.VkImageSubresourceRange{
                    .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
                .pNext = null,
                .flags = 0,
            };

            if (vk.vkCreateImageView(self.device, &create_info, null, &self.swapchain_image_views[i]) != vk.VK_SUCCESS) {
                return error.ImageViewCreationFailed;
            }
        }
    }

    fn createRenderPass(self: *VulkanRenderer) !void {
        const color_attachment = vk.VkAttachmentDescription{
            .format = vk.VK_FORMAT_B8G8R8A8_UNORM,
            .samples = vk.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
            .stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            .flags = 0,
        };

        const color_attachment_ref = vk.VkAttachmentReference{
            .attachment = 0,
            .layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        };

        const subpass = vk.VkSubpassDescription{
            .pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1,
            .pColorAttachments = &color_attachment_ref,
            .inputAttachmentCount = 0,
            .pInputAttachments = null,
            .pResolveAttachments = null,
            .pDepthStencilAttachment = null,
            .preserveAttachmentCount = 0,
            .pPreserveAttachments = null,
            .flags = 0,
        };

        const render_pass_info = vk.VkRenderPassCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = &color_attachment,
            .subpassCount = 1,
            .pSubpasses = &subpass,
            .dependencyCount = 0,
            .pDependencies = null,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateRenderPass(self.device, &render_pass_info, null, &self.render_pass) != vk.VK_SUCCESS) {
            return error.RenderPassCreationFailed;
        }
    }

    fn createGraphicsPipeline(self: *VulkanRenderer) !void {
        const shader = @import("shader.zig").ShaderModule;

        // Load shaders
        const vert_shader = try shader.loadFromFile(self.device, "shaders/triangle.vert");
        defer vert_shader.deinit();
        const frag_shader = try shader.loadFromFile(self.device, "shaders/triangle.frag");
        defer frag_shader.deinit();

        // Create shader stages
        const vert_stage_info = vk.VkPipelineShaderStageCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
            .module = vert_shader.handle,
            .pName = "main",
            .pNext = null,
            .flags = 0,
            .pSpecializationInfo = null,
        };

        const frag_stage_info = vk.VkPipelineShaderStageCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = frag_shader.handle,
            .pName = "main",
            .pNext = null,
            .flags = 0,
            .pSpecializationInfo = null,
        };

        const shader_stages = [_]vk.VkPipelineShaderStageCreateInfo{
            vert_stage_info,
            frag_stage_info,
        };

        // Vertex binding description
        const binding_description = vk.VkVertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(struct {
                pos: [2]f32,
                color: [3]f32,
            }),
            .inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        // Vertex attribute descriptions
        const attribute_descriptions = [_]vk.VkVertexInputAttributeDescription{
            // Position attribute
            vk.VkVertexInputAttributeDescription{
                .binding = 0,
                .location = 0,
                .format = vk.VK_FORMAT_R32G32_SFLOAT,
                .offset = @offsetOf(struct {
                    pos: [2]f32,
                    color: [3]f32,
                }, "pos"),
            },
            // Color attribute
            vk.VkVertexInputAttributeDescription{
                .binding = 0,
                .location = 1,
                .format = vk.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(struct {
                    pos: [2]f32,
                    color: [3]f32,
                }, "color"),
            },
        };

        // Vertex input state
        const vertex_input_info = vk.VkPipelineVertexInputStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = &binding_description,
            .vertexAttributeDescriptionCount = attribute_descriptions.len,
            .pVertexAttributeDescriptions = &attribute_descriptions,
            .pNext = null,
            .flags = 0,
        };

        // Input assembly state
        const input_assembly = vk.VkPipelineInputAssemblyStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = vk.VK_FALSE,
            .pNext = null,
            .flags = 0,
        };

        // Dynamic state
        const dynamic_states = [_]vk.VkDynamicState{
            vk.VK_DYNAMIC_STATE_VIEWPORT,
            vk.VK_DYNAMIC_STATE_SCISSOR,
        };

        const dynamic_state = vk.VkPipelineDynamicStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = dynamic_states.len,
            .pDynamicStates = &dynamic_states,
            .pNext = null,
            .flags = 0,
        };

        // Viewport state (now with dynamic viewport and scissor)
        const viewport_state = vk.VkPipelineViewportStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = null, // Will be set dynamically
            .scissorCount = 1,
            .pScissors = null, // Will be set dynamically
            .pNext = null,
            .flags = 0,
        };

        // Rasterization state
        const rasterizer = vk.VkPipelineRasterizationStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = vk.VK_FALSE,
            .rasterizerDiscardEnable = vk.VK_FALSE,
            .polygonMode = vk.VK_POLYGON_MODE_FILL,
            .lineWidth = 1.0,
            .cullMode = vk.VK_CULL_MODE_BACK_BIT,
            .frontFace = vk.VK_FRONT_FACE_CLOCKWISE,
            .depthBiasEnable = vk.VK_FALSE,
            .depthBiasConstantFactor = 0.0,
            .depthBiasClamp = 0.0,
            .depthBiasSlopeFactor = 0.0,
            .pNext = null,
            .flags = 0,
        };

        // Multisampling state
        const multisampling = vk.VkPipelineMultisampleStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = vk.VK_FALSE,
            .rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT,
            .minSampleShading = 1.0,
            .pSampleMask = null,
            .alphaToCoverageEnable = vk.VK_FALSE,
            .alphaToOneEnable = vk.VK_FALSE,
            .pNext = null,
            .flags = 0,
        };

        // Color blending state
        const color_blend_attachment = vk.VkPipelineColorBlendAttachmentState{
            .colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT |
                vk.VK_COLOR_COMPONENT_G_BIT |
                vk.VK_COLOR_COMPONENT_B_BIT |
                vk.VK_COLOR_COMPONENT_A_BIT,
            .blendEnable = vk.VK_FALSE,
            .srcColorBlendFactor = vk.VK_BLEND_FACTOR_ONE,
            .dstColorBlendFactor = vk.VK_BLEND_FACTOR_ZERO,
            .colorBlendOp = vk.VK_BLEND_OP_ADD,
            .srcAlphaBlendFactor = vk.VK_BLEND_FACTOR_ONE,
            .dstAlphaBlendFactor = vk.VK_BLEND_FACTOR_ZERO,
            .alphaBlendOp = vk.VK_BLEND_OP_ADD,
        };

        const color_blending = vk.VkPipelineColorBlendStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = vk.VK_FALSE,
            .logicOp = vk.VK_LOGIC_OP_COPY,
            .attachmentCount = 1,
            .pAttachments = &color_blend_attachment,
            .blendConstants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
            .pNext = null,
            .flags = 0,
        };

        // Pipeline layout
        const pipeline_layout_info = vk.VkPipelineLayoutCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 0,
            .pSetLayouts = null,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
            .pNext = null,
            .flags = 0,
        };

        try checkVulkanResult(vk.vkCreatePipelineLayout(
            self.device,
            &pipeline_layout_info,
            null,
            &self.pipeline_layout,
        ));

        // Create graphics pipeline
        const pipeline_info = vk.VkGraphicsPipelineCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = shader_stages.len,
            .pStages = &shader_stages,
            .pVertexInputState = &vertex_input_info,
            .pInputAssemblyState = &input_assembly,
            .pViewportState = &viewport_state,
            .pRasterizationState = &rasterizer,
            .pMultisampleState = &multisampling,
            .pDepthStencilState = null,
            .pColorBlendState = &color_blending,
            .pDynamicState = &dynamic_state,
            .layout = self.pipeline_layout,
            .renderPass = self.render_pass,
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
            .pNext = null,
            .flags = 0,
        };

        try checkVulkanResult(vk.vkCreateGraphicsPipelines(
            self.device,
            null,
            1,
            &pipeline_info,
            null,
            &self.pipeline,
        ));
    }

    fn createFramebuffers(self: *VulkanRenderer) !void {
        self.framebuffers = try std.heap.page_allocator.alloc(vk.VkFramebuffer, self.swapchain_image_views.len);

        for (self.swapchain_image_views, 0..) |image_view, i| {
            const framebuffer_info = vk.VkFramebufferCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = self.render_pass,
                .attachmentCount = 1,
                .pAttachments = &image_view,
                .width = 800, // TODO: Get from window
                .height = 600,
                .layers = 1,
                .pNext = null,
                .flags = 0,
            };

            if (vk.vkCreateFramebuffer(self.device, &framebuffer_info, null, &self.framebuffers[i]) != vk.VK_SUCCESS) {
                return error.FramebufferCreationFailed;
            }
        }
    }

    fn createCommandPool(self: *VulkanRenderer) !void {
        const pool_info = vk.VkCommandPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .queueFamilyIndex = 0, // TODO: Get from device
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .pNext = null,
        };

        if (vk.vkCreateCommandPool(self.device, &pool_info, null, &self.command_pool) != vk.VK_SUCCESS) {
            return error.CommandPoolCreationFailed;
        }
    }

    fn createVertexBuffer(self: *VulkanRenderer) !void {
        const vertices = [_]struct {
            pos: [2]f32,
            color: [3]f32,
        }{
            .{ .pos = [2]f32{ 0.0, -0.5 }, .color = [3]f32{ 1.0, 0.0, 0.0 } },
            .{ .pos = [2]f32{ 0.5, 0.5 }, .color = [3]f32{ 0.0, 1.0, 0.0 } },
            .{ .pos = [2]f32{ -0.5, 0.5 }, .color = [3]f32{ 0.0, 0.0, 1.0 } },
        };

        const buffer_size = @sizeOf(@TypeOf(vertices));

        // Create staging buffer
        var staging_buffer: vk.VkBuffer = undefined;
        var staging_buffer_memory: vk.VkDeviceMemory = undefined;

        const buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = buffer_size,
            .usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        if (vk.vkCreateBuffer(self.device, &buffer_info, null, &staging_buffer) != vk.VK_SUCCESS) {
            return error.StagingBufferCreationFailed;
        }

        // Get memory requirements
        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(self.device, staging_buffer, &mem_requirements);

        // Find memory type
        var memory_type_index: u32 = undefined;
        var memory_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &memory_properties);

        for (0..memory_properties.memoryTypeCount) |i| {
            if ((mem_requirements.memoryTypeBits & (@as(u32, 1) << @intCast(i))) != 0 and
                (memory_properties.memoryTypes[i].propertyFlags & vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) != 0 and
                (memory_properties.memoryTypes[i].propertyFlags & vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) != 0)
            {
                memory_type_index = @intCast(i);
                break;
            }
        }

        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
            .pNext = null,
        };

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, &staging_buffer_memory) != vk.VK_SUCCESS) {
            return error.StagingMemoryAllocationFailed;
        }

        // Bind memory to buffer
        if (vk.vkBindBufferMemory(self.device, staging_buffer, staging_buffer_memory, 0) != vk.VK_SUCCESS) {
            return error.StagingMemoryBindingFailed;
        }

        // Map memory and copy data
        var data: ?*anyopaque = null;
        if (vk.vkMapMemory(self.device, staging_buffer_memory, 0, buffer_size, 0, &data) != vk.VK_SUCCESS) {
            return error.MemoryMappingFailed;
        }

        @memcpy(@ptrCast(data), &vertices, buffer_size);
        vk.vkUnmapMemory(self.device, staging_buffer_memory);

        // Create vertex buffer
        const vertex_buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = buffer_size,
            .usage = vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        if (vk.vkCreateBuffer(self.device, &vertex_buffer_info, null, &self.vertex_buffer) != vk.VK_SUCCESS) {
            return error.VertexBufferCreationFailed;
        }

        // Get memory requirements for vertex buffer
        vk.vkGetBufferMemoryRequirements(self.device, self.vertex_buffer, &mem_requirements);

        // Find memory type for vertex buffer
        for (0..memory_properties.memoryTypeCount) |i| {
            if ((mem_requirements.memoryTypeBits & (@as(u32, 1) << @intCast(i))) != 0 and
                (memory_properties.memoryTypes[i].propertyFlags & vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) != 0)
            {
                memory_type_index = @intCast(i);
                break;
            }
        }

        const vertex_alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
            .pNext = null,
        };

        if (vk.vkAllocateMemory(self.device, &vertex_alloc_info, null, &self.vertex_buffer_memory) != vk.VK_SUCCESS) {
            return error.VertexMemoryAllocationFailed;
        }

        if (vk.vkBindBufferMemory(self.device, self.vertex_buffer, self.vertex_buffer_memory, 0) != vk.VK_SUCCESS) {
            return error.VertexMemoryBindingFailed;
        }

        // Copy data from staging buffer to vertex buffer
        const command_buffer = try self.beginSingleTimeCommands();

        const copy_region = vk.VkBufferCopy{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = buffer_size,
        };

        vk.vkCmdCopyBuffer(command_buffer, staging_buffer, self.vertex_buffer, 1, &copy_region);

        try self.endSingleTimeCommands(command_buffer);

        // Cleanup staging buffer
        vk.vkDestroyBuffer(self.device, staging_buffer, null);
        vk.vkFreeMemory(self.device, staging_buffer_memory, null);
    }

    fn beginSingleTimeCommands(self: *VulkanRenderer) !vk.VkCommandBuffer {
        const alloc_info = vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = self.command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
            .pNext = null,
        };

        var command_buffer: vk.VkCommandBuffer = undefined;
        if (vk.vkAllocateCommandBuffers(self.device, &alloc_info, &command_buffer) != vk.VK_SUCCESS) {
            return error.CommandBufferAllocationFailed;
        }

        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pNext = null,
            .pInheritanceInfo = null,
        };

        if (vk.vkBeginCommandBuffer(command_buffer, &begin_info) != vk.VK_SUCCESS) {
            return error.CommandBufferBeginFailed;
        }

        return command_buffer;
    }

    fn endSingleTimeCommands(self: *VulkanRenderer, command_buffer: vk.VkCommandBuffer) !void {
        if (vk.vkEndCommandBuffer(command_buffer) != vk.VK_SUCCESS) {
            return error.CommandBufferEndFailed;
        }

        const submit_info = vk.VkSubmitInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer,
            .waitSemaphoreCount = 0,
            .pWaitSemaphores = null,
            .pWaitDstStageMask = null,
            .signalSemaphoreCount = 0,
            .pSignalSemaphores = null,
            .pNext = null,
        };

        try checkVulkanResult(vk.vkQueueSubmit(self.queue, 1, &submit_info, null));

        if (vk.vkQueueWaitIdle(self.queue) != vk.VK_SUCCESS) {
            return error.QueueWaitIdleFailed;
        }

        vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
    }

    fn createCommandBuffers(self: *VulkanRenderer) !void {
        self.command_buffers = try std.heap.page_allocator.alloc(vk.VkCommandBuffer, self.framebuffers.len);

        const alloc_info = vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = self.command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = @intCast(self.command_buffers.len),
            .pNext = null,
        };

        if (vk.vkAllocateCommandBuffers(self.device, &alloc_info, self.command_buffers.ptr) != vk.VK_SUCCESS) {
            return error.CommandBufferAllocationFailed;
        }
    }

    fn createSyncObjects(self: *VulkanRenderer) !void {
        self.image_available_semaphores = try std.heap.page_allocator.alloc(vk.VkSemaphore, MAX_FRAMES_IN_FLIGHT);
        self.render_finished_semaphores = try std.heap.page_allocator.alloc(vk.VkSemaphore, MAX_FRAMES_IN_FLIGHT);
        self.in_flight_fences = try std.heap.page_allocator.alloc(vk.VkFence, MAX_FRAMES_IN_FLIGHT);

        const semaphore_info = vk.VkSemaphoreCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
        };

        const fence_info = vk.VkFenceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = vk.VK_FENCE_CREATE_SIGNALED_BIT,
            .pNext = null,
        };

        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            if (vk.vkCreateSemaphore(self.device, &semaphore_info, null, &self.image_available_semaphores[i]) != vk.VK_SUCCESS or
                vk.vkCreateSemaphore(self.device, &semaphore_info, null, &self.render_finished_semaphores[i]) != vk.VK_SUCCESS or
                vk.vkCreateFence(self.device, &fence_info, null, &self.in_flight_fences[i]) != vk.VK_SUCCESS)
            {
                return error.SyncObjectCreationFailed;
            }
        }
    }

    fn resizeCallback(window: *glfw.GLFWwindow, width: i32, height: i32) void {
        if (width == 0 or height == 0) return; // Minimized window

        const self = @fieldParentPtr(VulkanRenderer, "window", window);
        self.framebuffer_resized = true;
    }

    fn recreateSwapChain(self: *VulkanRenderer) !void {
        var width: i32 = 0;
        var height: i32 = 0;
        self.window.getFramebufferSize(&width, &height);
        while (width == 0 or height == 0) {
            self.window.getFramebufferSize(&width, &height);
            self.window.waitEvents();
        }

        try vk.vkDeviceWaitIdle(self.device);

        self.cleanupSwapChain();

        try self.createSwapChain();
        try self.createImageViews();
        try self.createRenderPass();
        try self.createGraphicsPipeline();
        try self.createFramebuffers();
        try self.createCommandBuffers();
    }

    fn cleanupSwapChain(self: *VulkanRenderer) void {
        // Clean up framebuffers
        for (self.framebuffers) |framebuffer| {
            vk.vkDestroyFramebuffer(self.device, framebuffer, null);
        }

        // Clean up graphics pipeline
        vk.vkDestroyPipeline(self.device, self.pipeline, null);
        vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);

        // Clean up render pass
        vk.vkDestroyRenderPass(self.device, self.render_pass, null);

        // Clean up image views
        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }

        // Clean up swapchain
        vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);
    }

    pub fn drawFrame(self: *VulkanRenderer) !void {
        try vk.vkWaitForFences(
            self.device,
            1,
            &self.in_flight_fences[self.current_frame],
            vk.VK_TRUE,
            std.math.maxInt(u64),
        );

        var image_index: u32 = undefined;
        const result = vk.vkAcquireNextImageKHR(
            self.device,
            self.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[self.current_frame],
            null,
            &image_index,
        );

        if (result == vk.VK_ERROR_OUT_OF_DATE_KHR) {
            self.framebuffer_resized = false;
            try self.recreateSwapChain();
            return;
        } else if (result != vk.VK_SUCCESS and result != vk.VK_SUBOPTIMAL_KHR) {
            return error.FailedToAcquireSwapChainImage;
        }

        // Reset fence only if we're submitting work
        try vk.vkResetFences(self.device, 1, &self.in_flight_fences[self.current_frame]);

        try vk.vkResetCommandBuffer(self.command_buffers[self.current_frame], 0);
        try self.recordCommandBuffer(self.command_buffers[self.current_frame], image_index);

        const wait_semaphores = [_]vk.VkSemaphore{self.image_available_semaphores[self.current_frame]};
        const wait_stages = [_]vk.VkPipelineStageFlags{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
        const signal_semaphores = [_]vk.VkSemaphore{self.render_finished_semaphores[self.current_frame]};

        const submit_info = vk.VkSubmitInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = wait_semaphores.len,
            .pWaitSemaphores = &wait_semaphores,
            .pWaitDstStageMask = &wait_stages,
            .commandBufferCount = 1,
            .pCommandBuffers = &self.command_buffers[self.current_frame],
            .signalSemaphoreCount = signal_semaphores.len,
            .pSignalSemaphores = &signal_semaphores,
            .pNext = null,
        };

        try checkVulkanResult(vk.vkQueueSubmit(
            self.queue,
            1,
            &submit_info,
            self.in_flight_fences[self.current_frame],
        ));

        const present_info = vk.VkPresentInfoKHR{
            .sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = signal_semaphores.len,
            .pWaitSemaphores = &signal_semaphores,
            .swapchainCount = 1,
            .pSwapchains = &self.swapchain,
            .pImageIndices = &image_index,
            .pResults = null,
            .pNext = null,
        };

        const present_result = vk.vkQueuePresentKHR(self.queue, &present_info);

        if (present_result == vk.VK_ERROR_OUT_OF_DATE_KHR or
            present_result == vk.VK_SUBOPTIMAL_KHR or
            self.framebuffer_resized)
        {
            self.framebuffer_resized = false;
            try self.recreateSwapChain();
        } else if (present_result != vk.VK_SUCCESS) {
            return error.FailedToPresentSwapChainImage;
        }

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn recordCommandBuffer(self: *VulkanRenderer, command_buffer: vk.VkCommandBuffer, image_index: u32) !void {
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = 0,
            .pNext = null,
            .pInheritanceInfo = null,
        };

        try checkVulkanResult(vk.vkBeginCommandBuffer(command_buffer, &begin_info));

        const clear_color = vk.VkClearValue{
            .color = vk.VkClearColorValue{
                .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        };

        const render_pass_info = vk.VkRenderPassBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .renderArea = vk.VkRect2D{
                .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
                .extent = vk.VkExtent2D{ .width = 800, .height = 600 }, // TODO: Get from window
            },
            .clearValueCount = 1,
            .pClearValues = &clear_color,
            .pNext = null,
        };

        vk.vkCmdBeginRenderPass(command_buffer, &render_pass_info, vk.VK_SUBPASS_CONTENTS_INLINE);

        // Bind the graphics pipeline
        vk.vkCmdBindPipeline(command_buffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline);

        // Set dynamic viewport
        const viewport = vk.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, self.swapchain_extent.width),
            .height = @intToFloat(f32, self.swapchain_extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };
        vk.vkCmdSetViewport(command_buffer, 0, 1, &viewport);

        // Set dynamic scissor
        const scissor = vk.VkRect2D{
            .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
            .extent = self.swapchain_extent,
        };
        vk.vkCmdSetScissor(command_buffer, 0, 1, &scissor);

        // Bind the vertex buffer
        const vertex_buffers = [_]vk.VkBuffer{self.vertex_buffer};
        const offsets = [_]vk.VkDeviceSize{0};
        vk.vkCmdBindVertexBuffers(
            command_buffer,
            0, // first binding
            1, // binding count
            &vertex_buffers,
            &offsets,
        );

        // Draw the triangle
        vk.vkCmdDraw(
            command_buffer,
            3, // vertex count
            1, // instance count
            0, // first vertex
            0, // first instance
        );

        vk.vkCmdEndRenderPass(command_buffer);

        try checkVulkanResult(vk.vkEndCommandBuffer(command_buffer));
    }
}; 