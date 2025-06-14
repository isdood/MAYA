const std = @import("std");
const vk_types = @import("vulkan_types.zig");
const vk = vk_types.vk;
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});

fn createRotationMatrix(angle: f32) [4][4]f32 {
    const c = @cos(angle);
    const s = @sin(angle);
    return [4][4]f32{
        [4]f32{ c, -s, 0.0, 0.0 },
        [4]f32{ s, c, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, 1.0, 0.0 },
        [4]f32{ 0.0, 0.0, 0.0, 1.0 },
    };
}

pub const VulkanRenderer = struct {
    const Self = @This();
    const MAX_FRAMES_IN_FLIGHT = 2;
    const REQUIRED_DEVICE_EXTENSIONS = [_][*:0]const u8{
        vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };
    const REQUIRED_INSTANCE_EXTENSIONS = [_][*:0]const u8{
        vk.VK_KHR_SURFACE_EXTENSION_NAME,
        vk.VK_KHR_XCB_SURFACE_EXTENSION_NAME,
    };

    const QueueFamilyIndices = struct {
        graphics_family: ?u32 = null,
        present_family: ?u32 = null,

        fn isComplete(self: QueueFamilyIndices) bool {
            return self.graphics_family != null and self.present_family != null;
        }
    };

    const SwapChainSupportDetails = struct {
        capabilities: vk.VkSurfaceCapabilitiesKHR,
        formats: []vk.VkSurfaceFormatKHR,
        present_modes: []vk.VkPresentModeKHR,
    };

    const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

    instance: vk.VkInstance,
    surface: vk.VkSurfaceKHR,
    physical_device: vk.VkPhysicalDevice,
    device: vk_types.VkDevice,
    queue: vk.VkQueue,
    swapchain: vk.VkSwapchainKHR,
    swapchain_images: []vk.VkImage,
    swapchain_image_views: []vk.VkImageView,
    swapchain_format: vk.VkFormat,
    swapchain_extent: vk.VkExtent2D,
    render_pass: vk.VkRenderPass,
    pipeline_layout: vk.VkPipelineLayout,
    graphics_pipeline: vk.VkPipeline,
    framebuffers: []vk.VkFramebuffer,
    command_pool: vk.VkCommandPool,
    command_buffers: []vk.VkCommandBuffer,
    image_available_semaphores: []vk.VkSemaphore,
    render_finished_semaphores: []vk.VkSemaphore,
    in_flight_fences: []vk.VkFence,
    images_in_flight: []?vk.VkFence,
    current_frame: usize,
    allocator: std.mem.Allocator,
    rotation: f32,
    framebuffer_resized: bool,
    depth_image: vk.VkImage,
    depth_image_memory: vk.VkDeviceMemory,
    depth_image_view: vk.VkImageView,
    window: *glfw.GLFWwindow,
    uniform_buffer: vk.VkBuffer,
    uniform_buffer_memory: vk.VkDeviceMemory,
    uniform_buffer_mapped: ?*anyopaque,
    vertex_buffer: vk.VkBuffer,
    vertex_buffer_memory: vk.VkDeviceMemory,
    descriptor_set_layout: vk.VkDescriptorSetLayout,
    descriptor_pool: vk.VkDescriptorPool,
    descriptor_set: vk.VkDescriptorSet,

    pub fn init(window: *glfw.GLFWwindow) !Self {
        var self = Self{
            .instance = undefined,
            .surface = undefined,
            .physical_device = undefined,
            .device = undefined,
            .queue = undefined,
            .swapchain = undefined,
            .swapchain_images = undefined,
            .swapchain_image_views = undefined,
            .swapchain_format = undefined,
            .swapchain_extent = undefined,
            .render_pass = undefined,
            .pipeline_layout = undefined,
            .graphics_pipeline = undefined,
            .framebuffers = undefined,
            .command_pool = undefined,
            .command_buffers = undefined,
            .image_available_semaphores = undefined,
            .render_finished_semaphores = undefined,
            .in_flight_fences = undefined,
            .images_in_flight = undefined,
            .current_frame = 0,
            .allocator = std.heap.page_allocator,
            .rotation = 0.0,
            .framebuffer_resized = false,
            .depth_image = undefined,
            .depth_image_memory = undefined,
            .depth_image_view = undefined,
            .window = window,
            .uniform_buffer = undefined,
            .uniform_buffer_memory = undefined,
            .uniform_buffer_mapped = null,
            .vertex_buffer = undefined,
            .vertex_buffer_memory = undefined,
            .descriptor_set_layout = undefined,
            .descriptor_pool = undefined,
            .descriptor_set = undefined,
        };

        try self.createInstance();
        try self.createSurface(window);
        try self.pickPhysicalDevice();
        try self.createLogicalDevice();
        try self.createSwapChain();
        try self.createImageViews();
        try self.createDepthResources();
        try self.createRenderPass();
        try self.createDescriptorSetLayout();
        try self.createGraphicsPipeline();
        try self.createFramebuffers();
        try self.createCommandPool();
        try self.createVertexBuffer();
        try self.createUniformBuffers();
        try self.createDescriptorPool();
        try self.createDescriptorSet();
        try self.createCommandBuffers();
        try self.createSyncObjects();

        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = vk.vkDeviceWaitIdle(self.device);

        // Clean up sync objects
        for (self.in_flight_fences) |fence| {
            vk.vkDestroyFence(self.device, fence, null);
        }
        for (self.render_finished_semaphores) |semaphore| {
            vk.vkDestroySemaphore(self.device, semaphore, null);
        }
        for (self.image_available_semaphores) |semaphore| {
            vk.vkDestroySemaphore(self.device, semaphore, null);
        }
        std.heap.page_allocator.free(self.images_in_flight);
        std.heap.page_allocator.free(self.image_available_semaphores);
        std.heap.page_allocator.free(self.render_finished_semaphores);
        std.heap.page_allocator.free(self.in_flight_fences);

        // Clean up command buffers and pool
        vk.vkFreeCommandBuffers(
            self.device,
            self.command_pool,
            @as(u32, @intCast(self.command_buffers.len)),
            self.command_buffers.ptr,
        );
        vk.vkDestroyCommandPool(self.device, self.command_pool, null);
        std.heap.page_allocator.free(self.command_buffers);

        // Clean up descriptor resources
        vk.vkDestroyDescriptorSetLayout(self.device, self.descriptor_set_layout, null);
        vk.vkDestroyDescriptorPool(self.device, self.descriptor_pool, null);

        // Clean up uniform buffer
        vk.vkDestroyBuffer(self.device, self.uniform_buffer, null);
        vk.vkFreeMemory(self.device, self.uniform_buffer_memory, null);

        // Clean up vertex buffer
        vk.vkDestroyBuffer(self.device, self.vertex_buffer, null);
        vk.vkFreeMemory(self.device, self.vertex_buffer_memory, null);

        // Clean up framebuffers
        for (self.framebuffers) |framebuffer| {
            vk.vkDestroyFramebuffer(self.device, framebuffer, null);
        }
        std.heap.page_allocator.free(self.framebuffers);

        // Clean up graphics pipeline
        vk.vkDestroyPipeline(self.device, self.graphics_pipeline, null);
        vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);

        // Clean up render pass
        vk.vkDestroyRenderPass(self.device, self.render_pass, null);

        // Clean up depth resources
        vk.vkDestroyImageView(self.device, self.depth_image_view, null);
        vk.vkDestroyImage(self.device, self.depth_image, null);
        vk.vkFreeMemory(self.device, self.depth_image_memory, null);

        // Clean up swapchain resources
        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }
        std.heap.page_allocator.free(self.swapchain_image_views);
        vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);

        // Clean up device and instance
        vk.vkDestroyDevice(self.device, null);
        vk.vkDestroySurfaceKHR(self.instance, self.surface, null);
        vk.vkDestroyInstance(self.instance, null);
    }

    fn createInstance(self: *Self) !void {
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "MAYA",
            .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
            .pNext = null,
        };

        // Get required extensions from GLFW
        var glfw_extension_count: u32 = 0;
        const glfw_extensions = glfw.glfwGetRequiredInstanceExtensions(&glfw_extension_count);
        if (glfw_extensions == null) {
            return error.GLFWExtensionsFailed;
        }

        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = glfw_extension_count,
            .ppEnabledExtensionNames = glfw_extensions,
            .enabledLayerCount = validation_layers.len,
            .ppEnabledLayerNames = &validation_layers,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateInstance(&create_info, null, &self.instance) != vk.VK_SUCCESS) {
            return error.InstanceCreationFailed;
        }
    }

    fn createSurface(self: *Self, window: *glfw.GLFWwindow) !void {
        const result = glfw.glfwCreateWindowSurface(
            @ptrCast(self.instance),
            window,
            null,
            &self.surface,
        );
        if (result != vk.VK_SUCCESS) {
            std.log.err("Failed to create window surface: {d}", .{result});
            return error.SurfaceCreationFailed;
        }
    }

    fn pickPhysicalDevice(self: *Self) !void {
        var device_count: u32 = undefined;
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, null);
        if (device_count == 0) {
            return error.NoVulkanDevices;
        }

        const devices = try std.heap.page_allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer std.heap.page_allocator.free(devices);
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr);

        for (devices) |device| {
            var device_properties: vk.VkPhysicalDeviceProperties = undefined;
            vk.vkGetPhysicalDeviceProperties(device, &device_properties);
            std.log.info("Found physical device: {s}", .{std.mem.span(@as([*:0]const u8, @ptrCast(&device_properties.deviceName)))});

            if (try isDeviceSuitable(device, self.surface)) {
                self.physical_device = device;
                std.log.info("Selected physical device: {s}", .{std.mem.span(@as([*:0]const u8, @ptrCast(&device_properties.deviceName)))});
                break;
            }
        }

        if (self.physical_device == null) {
            return error.NoSuitableDevice;
        }
    }

    fn createLogicalDevice(self: *Self) !void {
        const indices = try findQueueFamilies(self.physical_device, self.surface);
        if (!indices.isComplete()) {
            return error.QueueFamilyNotFound;
        }

        var queue_create_infos = std.ArrayList(vk.VkDeviceQueueCreateInfo).init(std.heap.page_allocator);
        defer queue_create_infos.deinit();

        const queue_priority = [_]f32{1.0};
        if (indices.graphics_family) |family| {
            try queue_create_infos.append(vk.VkDeviceQueueCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = family,
                .queueCount = 1,
                .pQueuePriorities = &queue_priority,
                .pNext = null,
                .flags = 0,
            });
        }

        const device_create_info = vk.VkDeviceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = @intCast(queue_create_infos.items.len),
            .pQueueCreateInfos = queue_create_infos.items.ptr,
            .enabledExtensionCount = @intCast(REQUIRED_DEVICE_EXTENSIONS.len),
            .ppEnabledExtensionNames = &REQUIRED_DEVICE_EXTENSIONS,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pEnabledFeatures = null,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateDevice(self.physical_device, &device_create_info, null, &self.device) != vk.VK_SUCCESS) {
            return error.DeviceCreationFailed;
        }

        // Get the graphics queue
        if (indices.graphics_family) |family| {
            vk.vkGetDeviceQueue(self.device, family, 0, &self.queue);
            std.log.info("Got graphics queue from family {d}", .{family});
        } else {
            return error.GraphicsQueueNotFound;
        }
    }

    fn createSwapChain(self: *Self) !void {
        const swap_chain_support = try querySwapChainSupport(self.physical_device, self.surface);
        const surface_format = try chooseSwapSurfaceFormat(swap_chain_support.formats);
        const present_mode = try chooseSwapPresentMode(swap_chain_support.present_modes);
        const extent = try chooseSwapExtent(swap_chain_support.capabilities, self.window);

        var image_count = swap_chain_support.capabilities.minImageCount + 1;
        if (swap_chain_support.capabilities.maxImageCount > 0 and image_count > swap_chain_support.capabilities.maxImageCount) {
            image_count = swap_chain_support.capabilities.maxImageCount;
        }

        const indices = try findQueueFamilies(self.physical_device, self.surface);
        if (indices.graphics_family == null or indices.present_family == null) {
            return error.QueueFamilyNotFound;
        }

        const queue_family_indices = [_]u32{ indices.graphics_family.?, indices.present_family.? };
        const image_sharing_mode = if (indices.graphics_family != indices.present_family)
            @as(vk.VkSharingMode, vk.VK_SHARING_MODE_CONCURRENT)
        else
            @as(vk.VkSharingMode, vk.VK_SHARING_MODE_EXCLUSIVE);

        const swapchain_create_info = vk.VkSwapchainCreateInfoKHR{
            .sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = self.surface,
            .minImageCount = image_count,
            .imageFormat = surface_format.format,
            .imageColorSpace = surface_format.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = image_sharing_mode,
            .queueFamilyIndexCount = if (image_sharing_mode == vk.VK_SHARING_MODE_CONCURRENT) 2 else 0,
            .pQueueFamilyIndices = if (image_sharing_mode == vk.VK_SHARING_MODE_CONCURRENT) &queue_family_indices else null,
            .preTransform = swap_chain_support.capabilities.currentTransform,
            .compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = present_mode,
            .clipped = vk.VK_TRUE,
            .oldSwapchain = null,
            .pNext = null,
            .flags = 0,
        };

        var swapchain: vk.VkSwapchainKHR = undefined;
        const result = vk.vkCreateSwapchainKHR(self.device, &swapchain_create_info, null, &swapchain);
        if (result != vk.VK_SUCCESS) {
            std.log.err("Failed to create swapchain: {d}", .{result});
            return error.SwapchainCreationFailed;
        }
        self.swapchain = swapchain;

        // Get swapchain images
        var image_count_actual: u32 = 0;
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count_actual, null);
        if (image_count_actual == 0) {
            return error.NoSwapchainImages;
        }

        self.swapchain_images = try std.heap.page_allocator.alloc(vk.VkImage, image_count_actual);
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &image_count_actual, self.swapchain_images.ptr);

        self.swapchain_format = surface_format.format;
        self.swapchain_extent = extent;
    }

    fn chooseSwapSurfaceFormat(available_formats: []vk.VkSurfaceFormatKHR) !vk.VkSurfaceFormatKHR {
        for (available_formats) |format| {
            if (format.format == vk.VK_FORMAT_B8G8R8A8_UNORM and
                format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                return format;
            }
        }
        return available_formats[0];
    }

    fn chooseSwapPresentMode(available_present_modes: []vk.VkPresentModeKHR) !vk.VkPresentModeKHR {
        for (available_present_modes) |present_mode| {
            if (present_mode == vk.VK_PRESENT_MODE_MAILBOX_KHR) {
                return present_mode;
            }
        }
        return vk.VK_PRESENT_MODE_FIFO_KHR;
    }

    fn chooseSwapExtent(capabilities: vk.VkSurfaceCapabilitiesKHR, window: *glfw.GLFWwindow) !vk.VkExtent2D {
        if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
            return capabilities.currentExtent;
        }

        var width: i32 = undefined;
        var height: i32 = undefined;
        glfw.glfwGetFramebufferSize(window, &width, &height);

        const extent = vk.VkExtent2D{
            .width = @as(u32, @intCast(@max(
                capabilities.minImageExtent.width,
                @min(capabilities.maxImageExtent.width, @as(u32, @intCast(@max(0, width))))
            ))),
            .height = @as(u32, @intCast(@max(
                capabilities.minImageExtent.height,
                @min(capabilities.maxImageExtent.height, @as(u32, @intCast(@max(0, height))))
            ))),
        };

        return extent;
    }

    fn createImageViews(self: *Self) !void {
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

    fn createDepthResources(self: *Self) !void {
        const depth_format = try self.findDepthFormat();

        const image_info = vk.VkImageCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .imageType = vk.VK_IMAGE_TYPE_2D,
            .format = depth_format,
            .extent = vk.VkExtent3D{
                .width = self.swapchain_extent.width,
                .height = self.swapchain_extent.height,
                .depth = 1,
            },
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = vk.VK_SAMPLE_COUNT_1_BIT,
            .tiling = vk.VK_IMAGE_TILING_OPTIMAL,
            .usage = vk.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
            .flags = 0,
            .pNext = null,
        };

        if (vk.vkCreateImage(self.device, &image_info, null, &self.depth_image) != vk.VK_SUCCESS) {
            return error.ImageCreationFailed;
        }

        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetImageMemoryRequirements(self.device, self.depth_image, &mem_requirements);

        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = try self.findMemoryType(
                mem_requirements.memoryTypeBits,
                vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            ),
            .pNext = null,
        };

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, &self.depth_image_memory) != vk.VK_SUCCESS) {
            return error.MemoryAllocationFailed;
        }

        if (vk.vkBindImageMemory(self.device, self.depth_image, self.depth_image_memory, 0) != vk.VK_SUCCESS) {
            return error.ImageMemoryBindingFailed;
        }

        const view_info = vk.VkImageViewCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = self.depth_image,
            .viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
            .format = depth_format,
            .subresourceRange = vk.VkImageSubresourceRange{
                .aspectMask = vk.VK_IMAGE_ASPECT_DEPTH_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .components = vk.VkComponentMapping{
                .r = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .flags = 0,
            .pNext = null,
        };

        if (vk.vkCreateImageView(self.device, &view_info, null, &self.depth_image_view) != vk.VK_SUCCESS) {
            return error.ImageViewCreationFailed;
        }
    }

    fn createRenderPass(self: *Self) !void {
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

        const depth_attachment = vk.VkAttachmentDescription{
            .format = try self.findDepthFormat(),
            .samples = vk.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            .flags = 0,
        };

        const color_attachment_ref = vk.VkAttachmentReference{
            .attachment = 0,
            .layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        };

        const depth_attachment_ref = vk.VkAttachmentReference{
            .attachment = 1,
            .layout = vk.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        };

        const subpass = vk.VkSubpassDescription{
            .pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1,
            .pColorAttachments = &color_attachment_ref,
            .pDepthStencilAttachment = &depth_attachment_ref,
            .inputAttachmentCount = 0,
            .pInputAttachments = null,
            .pResolveAttachments = null,
            .preserveAttachmentCount = 0,
            .pPreserveAttachments = null,
            .flags = 0,
        };

        const dependency = vk.VkSubpassDependency{
            .srcSubpass = vk.VK_SUBPASS_EXTERNAL,
            .dstSubpass = 0,
            .srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
            .dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | vk.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
            .srcAccessMask = 0,
            .dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | vk.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
            .dependencyFlags = 0,
        };

        const attachments = [_]vk.VkAttachmentDescription{ color_attachment, depth_attachment };
        const render_pass_info = vk.VkRenderPassCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = attachments.len,
            .pAttachments = &attachments,
            .subpassCount = 1,
            .pSubpasses = &subpass,
            .dependencyCount = 1,
            .pDependencies = &dependency,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateRenderPass(self.device, &render_pass_info, null, &self.render_pass) != vk.VK_SUCCESS) {
            return error.RenderPassCreationFailed;
        }
    }

    fn createGraphicsPipeline(self: *Self) !void {
        const shader = @import("shader.zig").ShaderModule;

        // Load shaders
        const device = self.device;
        var vert_shader = try shader.loadFromFile(device, "shaders/spv/triangle.vert.spv");
        defer vert_shader.deinit();
        var frag_shader = try shader.loadFromFile(device, "shaders/spv/triangle.frag.spv");
        defer frag_shader.deinit();

        // Create pipeline layout
        const pipeline_layout_info = vk.VkPipelineLayoutCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 1,
            .pSetLayouts = &self.descriptor_set_layout,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreatePipelineLayout(device, &pipeline_layout_info, null, &self.pipeline_layout) != vk.VK_SUCCESS) {
            return error.PipelineLayoutCreationFailed;
        }

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
                pos: [3]f32,
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
                .format = vk.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(struct {
                    pos: [3]f32,
                    color: [3]f32,
                }, "pos"),
            },
            // Color attribute
            vk.VkVertexInputAttributeDescription{
                .binding = 0,
                .location = 1,
                .format = vk.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(struct {
                    pos: [3]f32,
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

        // Add depth stencil state
        const depth_stencil = vk.VkPipelineDepthStencilStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .depthTestEnable = vk.VK_TRUE,
            .depthWriteEnable = vk.VK_TRUE,
            .depthCompareOp = vk.VK_COMPARE_OP_LESS,
            .depthBoundsTestEnable = vk.VK_FALSE,
            .minDepthBounds = 0.0,
            .maxDepthBounds = 1.0,
            .stencilTestEnable = vk.VK_FALSE,
            .front = undefined,
            .back = undefined,
            .pNext = null,
            .flags = 0,
        };

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
            .pDepthStencilState = &depth_stencil,
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
            &self.graphics_pipeline,
        ));
    }

    fn createFramebuffers(self: *Self) !void {
        self.framebuffers = try std.heap.page_allocator.alloc(vk.VkFramebuffer, self.swapchain_image_views.len);

        for (self.swapchain_image_views, 0..) |image_view, i| {
            const attachments = [_]vk.VkImageView{ image_view, self.depth_image_view };
            const framebuffer_info = vk.VkFramebufferCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = self.render_pass,
                .attachmentCount = attachments.len,
                .pAttachments = &attachments,
                .width = self.swapchain_extent.width,
                .height = self.swapchain_extent.height,
                .layers = 1,
                .pNext = null,
                .flags = 0,
            };

            if (vk.vkCreateFramebuffer(self.device, &framebuffer_info, null, &self.framebuffers[i]) != vk.VK_SUCCESS) {
                return error.FramebufferCreationFailed;
            }
        }
    }

    pub fn createSyncObjects(self: *Self) !void {
        // Create semaphores for each swapchain image
        self.image_available_semaphores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain_images.len);
        self.render_finished_semaphores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain_images.len);
        self.in_flight_fences = try self.allocator.alloc(vk.VkFence, MAX_FRAMES_IN_FLIGHT);
        self.images_in_flight = try self.allocator.alloc(?vk.VkFence, self.swapchain_images.len);
        @memset(self.images_in_flight, null);

        const semaphore_info = vk.VkSemaphoreCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
        };

        const fence_info = vk.VkFenceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .pNext = null,
            .flags = vk.VK_FENCE_CREATE_SIGNALED_BIT,
        };

        // Create semaphores for each swapchain image
        for (0..self.swapchain_images.len) |i| {
            if (vk.vkCreateSemaphore(
                self.device,
                &semaphore_info,
                null,
                &self.image_available_semaphores[i],
            ) != vk.VK_SUCCESS) {
                return error.FailedToCreateSemaphore;
            }

            if (vk.vkCreateSemaphore(
                self.device,
                &semaphore_info,
                null,
                &self.render_finished_semaphores[i],
            ) != vk.VK_SUCCESS) {
                return error.FailedToCreateSemaphore;
            }
        }

        // Create fences for frames in flight
        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            if (vk.vkCreateFence(
                self.device,
                &fence_info,
                null,
                &self.in_flight_fences[i],
            ) != vk.VK_SUCCESS) {
                return error.FailedToCreateFence;
            }
        }
    }

    pub fn drawFrame(self: *Self) !void {
        // Wait for the previous frame to finish
        if (vk.vkWaitForFences(
            self.device,
            1,
            &self.in_flight_fences[self.current_frame],
            vk.VK_TRUE,
            std.math.maxInt(u64),
        ) != vk.VK_SUCCESS) {
            return error.FenceWaitFailed;
        }

        // Reset the fence for the current frame
        if (vk.vkResetFences(self.device, 1, &self.in_flight_fences[self.current_frame]) != vk.VK_SUCCESS) {
            return error.FenceResetFailed;
        }

        // Update rotation and uniform buffer
        self.rotation += 0.01;
        self.updateUniformBuffer();

        // Acquire the next image from the swapchain
        var image_index: u32 = undefined;
        const acquire_result = vk.vkAcquireNextImageKHR(
            self.device,
            self.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[self.current_frame],
            null,
            &image_index,
        );

        // Handle swapchain recreation
        if (acquire_result == vk.VK_ERROR_OUT_OF_DATE_KHR or acquire_result == vk.VK_SUBOPTIMAL_KHR) {
            try self.recreateSwapChain();
            return;
        } else if (acquire_result != vk.VK_SUCCESS) {
            return error.FailedToAcquireSwapchainImage;
        }

        // Check if a previous frame is using this image
        if (self.images_in_flight[image_index]) |fence| {
            if (vk.vkWaitForFences(
                self.device,
                1,
                &fence,
                vk.VK_TRUE,
                std.math.maxInt(u64),
            ) != vk.VK_SUCCESS) {
                return error.FenceWaitFailed;
            }
        }

        // Mark the image as now being in use by this frame
        self.images_in_flight[image_index] = self.in_flight_fences[self.current_frame];

        // Record the command buffer
        try self.recordCommandBuffer(self.command_buffers[self.current_frame], image_index);

        // Submit the command buffer
        const wait_semaphores = [_]vk.VkSemaphore{self.image_available_semaphores[self.current_frame]};
        const wait_stages = [_]vk.VkPipelineStageFlags{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
        const signal_semaphores = [_]vk.VkSemaphore{self.render_finished_semaphores[image_index]};
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

        if (vk.vkQueueSubmit(
            self.queue,
            1,
            &submit_info,
            self.in_flight_fences[self.current_frame],
        ) != vk.VK_SUCCESS) {
            return error.FailedToSubmitDrawCommandBuffer;
        }

        // Present the frame
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
        if (present_result == vk.VK_ERROR_OUT_OF_DATE_KHR or present_result == vk.VK_SUBOPTIMAL_KHR) {
            try self.recreateSwapChain();
        } else if (present_result != vk.VK_SUCCESS) {
            return error.FailedToPresentSwapchainImage;
        }

        // Advance to the next frame
        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn recordCommandBuffer(self: *Self, command_buffer: vk.VkCommandBuffer, image_index: u32) !void {
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
            .pNext = null,
        };

        if (vk.vkBeginCommandBuffer(command_buffer, &begin_info) != vk.VK_SUCCESS) {
            return error.CommandBufferBeginFailed;
        }

        const clear_values = [_]vk.VkClearValue{
            vk.VkClearValue{
                .color = vk.VkClearColorValue{
                    .float32 = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
                },
            },
            vk.VkClearValue{
                .depthStencil = vk.VkClearDepthStencilValue{
                    .depth = 1.0,
                    .stencil = 0,
                },
            },
        };

        const render_pass_info = vk.VkRenderPassBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .renderArea = vk.VkRect2D{
                .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
                .extent = self.swapchain_extent,
            },
            .clearValueCount = clear_values.len,
            .pClearValues = &clear_values,
            .pNext = null,
        };

        vk.vkCmdBeginRenderPass(command_buffer, &render_pass_info, vk.VK_SUBPASS_CONTENTS_INLINE);
        vk.vkCmdBindPipeline(command_buffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphics_pipeline);

        const viewport = vk.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = @as(f32, @floatFromInt(self.swapchain_extent.width)),
            .height = @as(f32, @floatFromInt(self.swapchain_extent.height)),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };
        vk.vkCmdSetViewport(command_buffer, 0, 1, &viewport);

        const scissor = vk.VkRect2D{
            .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
            .extent = self.swapchain_extent,
        };
        vk.vkCmdSetScissor(command_buffer, 0, 1, &scissor);

        vk.vkCmdBindDescriptorSets(
            command_buffer,
            vk.VK_PIPELINE_BIND_POINT_GRAPHICS,
            self.pipeline_layout,
            0,
            1,
            &self.descriptor_set,
            0,
            null,
        );

        vk.vkCmdBindVertexBuffers(command_buffer, 0, 1, &self.vertex_buffer, &[_]vk.VkDeviceSize{0});
        vk.vkCmdDraw(command_buffer, 3, 1, 0, 0);

        vk.vkCmdEndRenderPass(command_buffer);

        if (vk.vkEndCommandBuffer(command_buffer) != vk.VK_SUCCESS) {
            return error.CommandBufferEndFailed;
        }
    }

    fn findSupportedFormat(
        self: *Self,
        candidates: []const vk.VkFormat,
        tiling: vk.VkImageTiling,
        features: vk.VkFormatFeatureFlags,
    ) !vk.VkFormat {
        for (candidates) |format| {
            var props: vk.VkFormatProperties = undefined;
            vk.vkGetPhysicalDeviceFormatProperties(self.physical_device, format, &props);

            if (tiling == vk.VK_IMAGE_TILING_LINEAR and (props.linearTilingFeatures & features) == features) {
                return format;
            } else if (tiling == vk.VK_IMAGE_TILING_OPTIMAL and (props.optimalTilingFeatures & features) == features) {
                return format;
            }
        }

        return error.FormatNotSupported;
    }

    fn findDepthFormat(self: *Self) !vk.VkFormat {
        return try self.findSupportedFormat(
            &[_]vk.VkFormat{
                vk.VK_FORMAT_D32_SFLOAT,
                vk.VK_FORMAT_D32_SFLOAT_S8_UINT,
                vk.VK_FORMAT_D24_UNORM_S8_UINT,
            },
            vk.VK_IMAGE_TILING_OPTIMAL,
            vk.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
        );
    }

    fn findMemoryType(self: *Self, type_filter: u32, properties: vk.VkMemoryPropertyFlags) !u32 {
        var memory_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &memory_properties);

        for (0..memory_properties.memoryTypeCount) |i| {
            if ((type_filter & (@as(u32, 1) << @intCast(i))) != 0 and
                (memory_properties.memoryTypes[i].propertyFlags & properties) == properties)
            {
                return @intCast(i);
            }
        }

        return error.MemoryTypeNotFound;
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

    fn isDeviceSuitable(device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) !bool {
        const indices = try findQueueFamilies(device, surface);
        const extensions_supported = try checkDeviceExtensionSupport(device);
        var swap_chain_adequate = false;
        if (extensions_supported) {
            const swap_chain_support = try querySwapChainSupport(device, surface);
            swap_chain_adequate = swap_chain_support.formats.len > 0 and swap_chain_support.present_modes.len > 0;
        }

        return indices.isComplete() and extensions_supported and swap_chain_adequate;
    }

    fn findQueueFamilies(device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) !QueueFamilyIndices {
        var indices = QueueFamilyIndices{};
        var queue_family_count: u32 = undefined;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        const queue_families = try std.heap.page_allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer std.heap.page_allocator.free(queue_families);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

        var i: u32 = 0;
        while (i < queue_family_count) : (i += 1) {
            const graphics_bit = @as(u32, @intCast(vk.VK_QUEUE_GRAPHICS_BIT));
            if (queue_families[i].queueFlags & graphics_bit != 0) {
                indices.graphics_family = i;
            }

            var present_support: vk.VkBool32 = undefined;
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(device, i, surface, &present_support);
            if (present_support != 0) {
                indices.present_family = i;
            }

            if (indices.isComplete()) break;
        }

        return indices;
    }

    fn checkDeviceExtensionSupport(device: vk.VkPhysicalDevice) !bool {
        var extension_count: u32 = undefined;
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, null);

        const available_extensions = try std.heap.page_allocator.alloc(vk.VkExtensionProperties, extension_count);
        defer std.heap.page_allocator.free(available_extensions);
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, available_extensions.ptr);

        for (REQUIRED_DEVICE_EXTENSIONS) |required_extension| {
            var extension_found = false;
            for (available_extensions) |extension| {
                const extension_name = std.mem.span(@as([*:0]const u8, @ptrCast(&extension.extensionName)));
                const required_name = std.mem.span(required_extension);
                if (std.mem.eql(u8, required_name, extension_name)) {
                    extension_found = true;
                    break;
                }
            }
            if (!extension_found) {
                return false;
            }
        }

        return true;
    }

    fn querySwapChainSupport(device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) !SwapChainSupportDetails {
        var details = SwapChainSupportDetails{
            .capabilities = undefined,
            .formats = undefined,
            .present_modes = undefined,
        };

        // Capabilities
        _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities);

        // Formats
        var format_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, null);
        if (format_count != 0) {
            details.formats = try std.heap.page_allocator.alloc(vk.VkSurfaceFormatKHR, format_count);
            _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, details.formats.ptr);
        }

        // Present modes
        var present_mode_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null);
        if (present_mode_count != 0) {
            details.present_modes = try std.heap.page_allocator.alloc(vk.VkPresentModeKHR, present_mode_count);
            _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, details.present_modes.ptr);
        }

        return details;
    }

    fn createVertexBuffer(self: *Self) !void {
        std.log.info("Creating vertex buffer...", .{});
        
        const vertices = [_]struct {
            pos: [3]f32,
            color: [3]f32,
        }{
            .{ .pos = [3]f32{ -0.5, -0.5, 0.0 }, .color = [3]f32{ 1.0, 0.0, 0.0 } },
            .{ .pos = [3]f32{ 0.5, -0.5, 0.0 }, .color = [3]f32{ 0.0, 1.0, 0.0 } },
            .{ .pos = [3]f32{ 0.0, 0.5, 0.0 }, .color = [3]f32{ 0.0, 0.0, 1.0 } },
        };

        const buffer_size = @sizeOf(@TypeOf(vertices));
        std.log.info("Buffer size: {d}", .{buffer_size});

        // Create staging buffer
        const staging_buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = buffer_size,
            .usage = vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        var staging_buffer: vk.VkBuffer = undefined;
        if (vk.vkCreateBuffer(self.device, &staging_buffer_info, null, &staging_buffer) != vk.VK_SUCCESS) {
            return error.StagingBufferCreationFailed;
        }
        defer vk.vkDestroyBuffer(self.device, staging_buffer, null);

        var staging_memory_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(self.device, staging_buffer, &staging_memory_requirements);

        const staging_alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = staging_memory_requirements.size,
            .memoryTypeIndex = try self.findMemoryType(
                staging_memory_requirements.memoryTypeBits,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            ),
            .pNext = null,
        };

        var staging_memory: vk.VkDeviceMemory = undefined;
        if (vk.vkAllocateMemory(self.device, &staging_alloc_info, null, &staging_memory) != vk.VK_SUCCESS) {
            return error.StagingMemoryAllocationFailed;
        }
        defer vk.vkFreeMemory(self.device, staging_memory, null);

        if (vk.vkBindBufferMemory(self.device, staging_buffer, staging_memory, 0) != vk.VK_SUCCESS) {
            return error.StagingMemoryBindingFailed;
        }

        // Map and copy data to staging buffer
        var data: ?*anyopaque = undefined;
        if (vk.vkMapMemory(self.device, staging_memory, 0, buffer_size, 0, &data) != vk.VK_SUCCESS) {
            return error.StagingMemoryMappingFailed;
        }

        const dest = @as([*]u8, @ptrCast(data))[0..buffer_size];
        const src = @as([*]const u8, @ptrCast(&vertices))[0..buffer_size];
        @memcpy(dest, src);

        vk.vkUnmapMemory(self.device, staging_memory);

        // Create vertex buffer
        const vertex_buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = buffer_size,
            .usage = vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT | vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        if (vk.vkCreateBuffer(self.device, &vertex_buffer_info, null, &self.vertex_buffer) != vk.VK_SUCCESS) {
            return error.VertexBufferCreationFailed;
        }

        var vertex_memory_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(self.device, self.vertex_buffer, &vertex_memory_requirements);

        const vertex_alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = vertex_memory_requirements.size,
            .memoryTypeIndex = try self.findMemoryType(
                vertex_memory_requirements.memoryTypeBits,
                vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            ),
            .pNext = null,
        };

        if (vk.vkAllocateMemory(self.device, &vertex_alloc_info, null, &self.vertex_buffer_memory) != vk.VK_SUCCESS) {
            vk.vkDestroyBuffer(self.device, self.vertex_buffer, null);
            return error.VertexMemoryAllocationFailed;
        }

        if (vk.vkBindBufferMemory(self.device, self.vertex_buffer, self.vertex_buffer_memory, 0) != vk.VK_SUCCESS) {
            vk.vkDestroyBuffer(self.device, self.vertex_buffer, null);
            vk.vkFreeMemory(self.device, self.vertex_buffer_memory, null);
            return error.VertexMemoryBindingFailed;
        }

        std.log.info("Creating command buffer for transfer...", .{});

        // Create command buffer for transfer
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
            vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
            return error.CommandBufferBeginFailed;
        }

        const copy_region = vk.VkBufferCopy{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = buffer_size,
        };

        vk.vkCmdCopyBuffer(command_buffer, staging_buffer, self.vertex_buffer, 1, &copy_region);

        if (vk.vkEndCommandBuffer(command_buffer) != vk.VK_SUCCESS) {
            vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
            return error.CommandBufferEndFailed;
        }

        std.log.info("Submitting command buffer...", .{});

        const submit_info = vk.VkSubmitInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer,
            .pNext = null,
            .waitSemaphoreCount = 0,
            .pWaitSemaphores = null,
            .pWaitDstStageMask = null,
            .signalSemaphoreCount = 0,
            .pSignalSemaphores = null,
        };

        if (vk.vkQueueSubmit(self.queue, 1, &submit_info, null) != vk.VK_SUCCESS) {
            vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
            return error.QueueSubmitFailed;
        }

        std.log.info("Waiting for queue idle...", .{});

        if (vk.vkQueueWaitIdle(self.queue) != vk.VK_SUCCESS) {
            vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
            return error.QueueWaitIdleFailed;
        }

        vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
        std.log.info("Vertex buffer creation complete", .{});
    }

    pub fn updateUniformBuffer(self: *Self) void {
        const rotation_matrix = createRotationMatrix(self.rotation);
        const dest = @as([*]u8, @ptrCast(self.uniform_buffer_mapped))[0..@sizeOf([4][4]f32)];
        const src = @as([*]const u8, @ptrCast(&rotation_matrix))[0..@sizeOf([4][4]f32)];
        @memcpy(dest, src);
    }

    fn createCommandPool(self: *Self) !void {
        const indices = try findQueueFamilies(self.physical_device, self.surface);
        if (indices.graphics_family == null) {
            return error.GraphicsQueueFamilyNotFound;
        }

        const pool_info = vk.VkCommandPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .queueFamilyIndex = indices.graphics_family.?,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .pNext = null,
        };

        if (vk.vkCreateCommandPool(self.device, &pool_info, null, &self.command_pool) != vk.VK_SUCCESS) {
            return error.CommandPoolCreationFailed;
        }
    }

    fn createUniformBuffers(self: *Self) !void {
        const buffer_size = @sizeOf([4][4]f32);

        const buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = buffer_size,
            .usage = vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        if (vk.vkCreateBuffer(self.device, &buffer_info, null, &self.uniform_buffer) != vk.VK_SUCCESS) {
            return error.UniformBufferCreationFailed;
        }

        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(self.device, self.uniform_buffer, &mem_requirements);

        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = try self.findMemoryType(
                mem_requirements.memoryTypeBits,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            ),
            .pNext = null,
        };

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, &self.uniform_buffer_memory) != vk.VK_SUCCESS) {
            return error.UniformMemoryAllocationFailed;
        }

        if (vk.vkBindBufferMemory(self.device, self.uniform_buffer, self.uniform_buffer_memory, 0) != vk.VK_SUCCESS) {
            return error.UniformMemoryBindingFailed;
        }

        if (vk.vkMapMemory(self.device, self.uniform_buffer_memory, 0, buffer_size, 0, &self.uniform_buffer_mapped) != vk.VK_SUCCESS) {
            return error.UniformMemoryMappingFailed;
        }

        // Initialize the uniform buffer with identity matrix
        const initial_matrix = [4][4]f32{
            [4]f32{ 1.0, 0.0, 0.0, 0.0 },
            [4]f32{ 0.0, 1.0, 0.0, 0.0 },
            [4]f32{ 0.0, 0.0, 1.0, 0.0 },
            [4]f32{ 0.0, 0.0, 0.0, 1.0 },
        };
        const dest = @as([*]u8, @ptrCast(self.uniform_buffer_mapped))[0..@sizeOf([4][4]f32)];
        const src = @as([*]const u8, @ptrCast(&initial_matrix))[0..@sizeOf([4][4]f32)];
        @memcpy(dest, src);
    }

    fn createDescriptorPool(self: *Self) !void {
        const pool_size = vk.VkDescriptorPoolSize{
            .type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
        };

        const pool_info = vk.VkDescriptorPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .poolSizeCount = 1,
            .pPoolSizes = &pool_size,
            .maxSets = 1,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateDescriptorPool(self.device, &pool_info, null, &self.descriptor_pool) != vk.VK_SUCCESS) {
            return error.DescriptorPoolCreationFailed;
        }
    }

    fn createDescriptorSet(self: *Self) !void {
        const alloc_info = vk.VkDescriptorSetAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool = self.descriptor_pool,
            .descriptorSetCount = 1,
            .pSetLayouts = &self.descriptor_set_layout,
            .pNext = null,
        };

        if (vk.vkAllocateDescriptorSets(self.device, &alloc_info, &self.descriptor_set) != vk.VK_SUCCESS) {
            return error.DescriptorSetAllocationFailed;
        }

        const buffer_info = vk.VkDescriptorBufferInfo{
            .buffer = self.uniform_buffer,
            .offset = 0,
            .range = @sizeOf([4][4]f32),
        };

        const descriptor_write = vk.VkWriteDescriptorSet{
            .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = self.descriptor_set,
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorCount = 1,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .pImageInfo = null,
            .pBufferInfo = &buffer_info,
            .pTexelBufferView = null,
            .pNext = null,
        };

        vk.vkUpdateDescriptorSets(self.device, 1, &descriptor_write, 0, null);
    }

    fn createCommandBuffers(self: *Self) !void {
        self.command_buffers = try self.allocator.alloc(vk.VkCommandBuffer, MAX_FRAMES_IN_FLIGHT);

        const alloc_info = vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = self.command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = @as(u32, @intCast(self.command_buffers.len)),
            .pNext = null,
        };

        if (vk.vkAllocateCommandBuffers(self.device, &alloc_info, self.command_buffers.ptr) != vk.VK_SUCCESS) {
            return error.CommandBufferAllocationFailed;
        }
    }

    fn recreateSwapChain(self: *Self) !void {
        var width: i32 = undefined;
        var height: i32 = undefined;
        glfw.glfwGetFramebufferSize(self.window, &width, &height);
        while (width == 0 or height == 0) {
            glfw.glfwGetFramebufferSize(self.window, &width, &height);
            glfw.glfwWaitEvents();
        }

        _ = vk.vkDeviceWaitIdle(self.device);

        // Clean up old swapchain resources
        for (self.framebuffers) |framebuffer| {
            vk.vkDestroyFramebuffer(self.device, framebuffer, null);
        }
        std.heap.page_allocator.free(self.framebuffers);

        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }
        std.heap.page_allocator.free(self.swapchain_image_views);

        vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);

        // Recreate swapchain
        try self.createSwapChain();
        try self.createImageViews();
        try self.createFramebuffers();
    }

    fn createDescriptorSetLayout(self: *Self) !void {
        const ubo_layout_binding = vk.VkDescriptorSetLayoutBinding{
            .binding = 0,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT,
            .pImmutableSamplers = null,
        };

        const layout_info = vk.VkDescriptorSetLayoutCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .bindingCount = 1,
            .pBindings = &ubo_layout_binding,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateDescriptorSetLayout(self.device, &layout_info, null, &self.descriptor_set_layout) != vk.VK_SUCCESS) {
            return error.DescriptorSetLayoutCreationFailed;
        }
    }
}; 