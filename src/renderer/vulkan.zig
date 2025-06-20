
const std = @import("std");
const vk_types = @import("vulkan_types.zig");
const vk = vk_types.vk;
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const math = std.math;
const vk_types_vk = vk_types.vk;

const UniformBufferObject = struct {
    model: [4][4]f32,
    view: [4][4]f32,
    proj: [4][4]f32,
};

fn createRotationMatrix(angle: f32) [4][4]f32 {
    const cos_val = @cos(angle);
    const sin_val = @sin(angle);

    return [4][4]f32{
        [4]f32{ cos_val, -sin_val, 0.0, 0.0 },
        [4]f32{ sin_val, cos_val, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, 1.0, 0.0 },
        [4]f32{ 0.0, 0.0, 0.0, 1.0 },
    };
}

fn createLookAtMatrix(eye: [3]f32, center: [3]f32, up: [3]f32) [4][4]f32 {
    const f = normalize(subtract(center, eye));
    const s = normalize(cross(f, up));
    const u = cross(s, f);

    return [4][4]f32{
        [4]f32{ s[0], u[0], -f[0], 0.0 },
        [4]f32{ s[1], u[1], -f[1], 0.0 },
        [4]f32{ s[2], u[2], -f[2], 0.0 },
        [4]f32{ -dot(s, eye), -dot(u, eye), dot(f, eye), 1.0 },
    };
}

fn createPerspectiveMatrix(aspect: f32, near: f32, far: f32) [4][4]f32 {
    const f = 1.0 / @tan(std.math.pi / 4.0);
    const nf = 1.0 / (near - far);

    return [4][4]f32{
        [4]f32{ f / aspect, 0.0, 0.0, 0.0 },
        [4]f32{ 0.0, f, 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, (far + near) * nf, -1.0 },
        [4]f32{ 0.0, 0.0, 2.0 * far * near * nf, 0.0 },
    };
}

fn normalize(v: [3]f32) [3]f32 {
    const length = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    return [3]f32{ v[0] / length, v[1] / length, v[2] / length };
}

fn subtract(a: [3]f32, b: [3]f32) [3]f32 {
    return [3]f32{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

fn cross(a: [3]f32, b: [3]f32) [3]f32 {
    return [3]f32{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

fn dot(a: [3]f32, b: [3]f32) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

pub const VulkanRenderer = struct {
    const Self = @This();
    const MAX_FRAMES_IN_FLIGHT = 2;
    const REQUIRED_DEVICE_EXTENSIONS = [_][*:0]const u8{
        vk_types_vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
    };
    const REQUIRED_INSTANCE_EXTENSIONS = [_][*:0]const u8{
        vk_types_vk.VK_KHR_SURFACE_EXTENSION_NAME,
        vk_types_vk.VK_KHR_XCB_SURFACE_EXTENSION_NAME,
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

    window: *glfw.GLFWwindow,
    instance: vk.VkInstance,
    surface: vk.VkSurfaceKHR,
    physical_device: vk.VkPhysicalDevice,
    device: vk.VkDevice,
    graphics_queue: vk.VkQueue,
    present_queue: vk.VkQueue,
    swapchain: vk.VkSwapchainKHR,
    swapchain_images: []vk.VkImage,
    swapchain_image_format: vk.VkFormat,
    swapchain_extent: vk.VkExtent2D,
    swapchain_image_views: []vk.VkImageView,
    render_pass: vk.VkRenderPass,
    pipeline_layout: vk.VkPipelineLayout,
    graphics_pipeline: vk.VkPipeline,
    framebuffers: []vk.VkFramebuffer,
    command_pool: vk.VkCommandPool,
    command_buffers: []vk.VkCommandBuffer,
    image_available_semaphores: []vk.VkSemaphore,
    render_finished_semaphores: []vk.VkSemaphore,
    in_flight_fences: []vk.VkFence,
    images_in_flight: []vk.VkFence,
    current_frame: usize,
    framebuffer_resized: bool,
    graphics_queue_family: u32,
    present_queue_family: u32,
    allocator: std.mem.Allocator,
    rotation: f32,
    depth_image: vk.VkImage,
    depth_image_memory: vk.VkDeviceMemory,
    depth_image_view: vk.VkImageView,
    uniform_buffers: []vk.VkBuffer,
    uniform_buffers_memory: []vk.VkDeviceMemory,
    uniform_buffers_mapped: [][*]u8,
    vertex_buffer: vk.VkBuffer,
    vertex_buffer_memory: vk.VkDeviceMemory,
    descriptor_set_layout: vk.VkDescriptorSetLayout,
    descriptor_pool: vk.VkDescriptorPool,
    descriptor_sets: []vk.VkDescriptorSet,
    index_buffer: vk.VkBuffer,
    index_buffer_memory: vk.VkDeviceMemory,
    texture_image: vk.VkImage,
    texture_image_memory: vk.VkDeviceMemory,
    texture_image_view: vk.VkImageView,
    texture_sampler: vk.VkSampler,
    msaa_samples: vk.VkSampleCountFlagBits,
    color_image: vk.VkImage,
    color_image_memory: vk.VkDeviceMemory,
    color_image_view: vk.VkImageView,

    pub fn init(window: *glfw.GLFWwindow) !Self {
        var self = Self{
            .window = window,
            .instance = undefined,
            .surface = undefined,
            .physical_device = undefined,
            .device = undefined,
            .graphics_queue = undefined,
            .present_queue = undefined,
            .swapchain = undefined,
            .swapchain_images = undefined,
            .swapchain_image_format = undefined,
            .swapchain_extent = undefined,
            .swapchain_image_views = undefined,
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
            .framebuffer_resized = false,
            .graphics_queue_family = undefined,
            .present_queue_family = undefined,
            .allocator = std.heap.page_allocator,
            .rotation = 0.0,
            .depth_image = undefined,
            .depth_image_memory = undefined,
            .depth_image_view = undefined,
            .uniform_buffers = undefined,
            .uniform_buffers_memory = undefined,
            .uniform_buffers_mapped = undefined,
            .vertex_buffer = undefined,
            .vertex_buffer_memory = undefined,
            .descriptor_set_layout = undefined,
            .descriptor_pool = undefined,
            .descriptor_sets = undefined,
            .index_buffer = undefined,
            .index_buffer_memory = undefined,
            .texture_image = undefined,
            .texture_image_memory = undefined,
            .texture_image_view = undefined,
            .texture_sampler = undefined,
            .msaa_samples = vk.VK_SAMPLE_COUNT_1_BIT,
            .color_image = undefined,
            .color_image_memory = undefined,
            .color_image_view = undefined,
        };

        try self.createInstance();
        try self.createSurface();
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
        try self.createDescriptorSets();
        try self.createCommandBuffers();
        try self.createSyncObjects();

        _ = glfw.glfwSetFramebufferSizeCallback(window, framebufferResizeCallback);
        glfw.glfwSetWindowUserPointer(window, @ptrCast(&self));

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
        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            vk.vkDestroyBuffer(self.device, self.uniform_buffers[i], null);
            vk.vkFreeMemory(self.device, self.uniform_buffers_memory[i], null);
        }
        std.heap.page_allocator.free(self.uniform_buffers);
        std.heap.page_allocator.free(self.uniform_buffers_memory);
        std.heap.page_allocator.free(self.uniform_buffers_mapped);

        // Clean up vertex buffer
        vk.vkDestroyBuffer(self.device, self.vertex_buffer, null);
        vk.vkFreeMemory(self.device, self.vertex_buffer_memory, null);

        // Clean up index buffer
        vk.vkDestroyBuffer(self.device, self.index_buffer, null);
        vk.vkFreeMemory(self.device, self.index_buffer_memory, null);

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
        if (self.depth_image_view != null) {
            vk.vkDestroyImageView(self.device, self.depth_image_view, null);
        }
        if (self.depth_image != null) {
            vk.vkDestroyImage(self.device, self.depth_image, null);
        }
        if (self.depth_image_memory != null) {
            vk.vkFreeMemory(self.device, self.depth_image_memory, null);
        }

        // Clean up swapchain resources
        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }
        std.heap.page_allocator.free(self.swapchain_image_views);
        vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);

        // Clean up texture resources
        vk.vkDestroyImageView(self.device, self.texture_image_view, null);
        vk.vkDestroyImage(self.device, self.texture_image, null);
        vk.vkFreeMemory(self.device, self.texture_image_memory, null);

        // Clean up MSAA color buffer
        vk.vkDestroyImageView(self.device, self.color_image_view, null);
        vk.vkDestroyImage(self.device, self.color_image, null);
        vk.vkFreeMemory(self.device, self.color_image_memory, null);

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

    fn createSurface(self: *Self) !void {
        const result = glfw.glfwCreateWindowSurface(
            @ptrCast(self.instance),
            self.window,
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
            return error.NoVulkanDevicesFound;
        }
        const devices = try std.heap.page_allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer std.heap.page_allocator.free(devices);
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr);
        for (devices) |device| {
            if (isDeviceSuitable(device, self.surface)) {
                self.physical_device = device;
                break;
            }
        }
        if (self.physical_device == null) {
            return error.NoSuitableVulkanDeviceFound;
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
            .queueCreateInfoCount = @as(u32, @intCast(queue_create_infos.items.len)),
            .pQueueCreateInfos = queue_create_infos.items.ptr,
            .enabledExtensionCount = @as(u32, @intCast(REQUIRED_DEVICE_EXTENSIONS.len)),
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
            vk.vkGetDeviceQueue(self.device, family, 0, &self.graphics_queue);
            self.graphics_queue_family = family;
            std.log.info("Got graphics queue from family {d}", .{family});
        } else {
            return error.GraphicsQueueNotFound;
        }

        // Get the present queue
        if (indices.present_family) |family| {
            vk.vkGetDeviceQueue(self.device, family, 0, &self.present_queue);
            self.present_queue_family = family;
            std.log.info("Got present queue from family {d}", .{family});
        } else {
            return error.PresentQueueNotFound;
        }
    }

    pub fn createSwapChain(self: *Self) !void {
        const swapchain_support = try querySwapChainSupport(self.physical_device, self.surface);
        defer {
            if (swapchain_support.formats.len > 0) {
                std.heap.page_allocator.free(swapchain_support.formats);
            }
            if (swapchain_support.present_modes.len > 0) {
                std.heap.page_allocator.free(swapchain_support.present_modes);
            }
        }

        const surface_format = try chooseSwapSurfaceFormat(swapchain_support.formats);
        const present_mode = try chooseSwapPresentMode(swapchain_support.present_modes);
        const extent = self.chooseSwapExtent(swapchain_support.capabilities);

        var image_count = swapchain_support.capabilities.minImageCount + 1;
        if (swapchain_support.capabilities.maxImageCount > 0 and image_count > swapchain_support.capabilities.maxImageCount) {
            image_count = swapchain_support.capabilities.maxImageCount;
        }

        var create_info = vk.VkSwapchainCreateInfoKHR{
            .sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = self.surface,
            .minImageCount = image_count,
            .imageFormat = surface_format.format,
            .imageColorSpace = surface_format.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .preTransform = swapchain_support.capabilities.currentTransform,
            .compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = present_mode,
            .clipped = vk.VK_TRUE,
            .oldSwapchain = null,
            .pNext = null,
            .flags = 0,
        };

        if (self.graphics_queue_family != self.present_queue_family) {
            const queue_family_indices = [_]u32{ self.graphics_queue_family, self.present_queue_family };
            create_info.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT;
            create_info.queueFamilyIndexCount = 2;
            create_info.pQueueFamilyIndices = &queue_family_indices;
        }

        if (vk.vkCreateSwapchainKHR(self.device, &create_info, null, &self.swapchain) != vk.VK_SUCCESS) {
            return error.FailedToCreateSwapchain;
        }

        var swapchain_image_count: u32 = undefined;
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &swapchain_image_count, null);
        self.swapchain_images = try std.heap.page_allocator.alloc(vk.VkImage, swapchain_image_count);
        _ = vk.vkGetSwapchainImagesKHR(self.device, self.swapchain, &swapchain_image_count, self.swapchain_images.ptr);

        self.swapchain_image_format = surface_format.format;
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

    fn chooseSwapExtent(self: *Self, capabilities: vk.VkSurfaceCapabilitiesKHR) vk.VkExtent2D {
        if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
            return capabilities.currentExtent;
        }

        var width: c_int = undefined;
        var height: c_int = undefined;
        glfw.glfwGetFramebufferSize(self.window, &width, &height);

        var extent = vk.VkExtent2D{
            .width = @intCast(width),
            .height = @intCast(height),
        };

        extent.width = @max(capabilities.minImageExtent.width, @min(capabilities.maxImageExtent.width, extent.width));
        extent.height = @max(capabilities.minImageExtent.height, @min(capabilities.maxImageExtent.height, extent.height));

        return extent;
    }

    fn createImageViews(self: *Self) !void {
        self.swapchain_image_views = try std.heap.page_allocator.alloc(vk.VkImageView, self.swapchain_images.len);
        errdefer std.heap.page_allocator.free(self.swapchain_image_views);

        for (self.swapchain_images, 0..) |image, i| {
            const components = vk.VkComponentMapping{
                .r = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            };

            const subresource_range = vk.VkImageSubresourceRange{
                .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            };

            const create_info = vk.VkImageViewCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = image,
                .viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
                .format = self.swapchain_image_format,
                .components = components,
                .subresourceRange = subresource_range,
                .flags = 0,
                .pNext = null,
            };

            if (vk.vkCreateImageView(self.device, &create_info, null, &self.swapchain_image_views[i]) != vk.VK_SUCCESS) {
                return error.FailedToCreateImageView;
            }
        }
    }

    fn createDepthResources(self: *Self) !void {
        std.log.info("[Vulkan] Creating depth resources: swapchain extent = {d}x{d}", .{self.swapchain_extent.width, self.swapchain_extent.height});
        const depth_format = try self.findDepthFormat();

        // Create depth image with exact same dimensions as swapchain images
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
        std.log.info("[Vulkan] Depth image created: {d}x{d}", .{image_info.extent.width, image_info.extent.height});

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
            return error.FailedToCreateImageView;
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

    pub fn createGraphicsPipeline(self: *Self) !void {
        const vert_shader_code = try self.readFile("shaders/vert.spv");
        defer std.heap.page_allocator.free(vert_shader_code);
        const frag_shader_code = try self.readFile("shaders/frag.spv");
        defer std.heap.page_allocator.free(frag_shader_code);

        const vert_shader_module = try self.createShaderModule(vert_shader_code);
        defer vk.vkDestroyShaderModule(self.device, vert_shader_module, null);
        const frag_shader_module = try self.createShaderModule(frag_shader_code);
        defer vk.vkDestroyShaderModule(self.device, frag_shader_module, null);

        const vert_shader_stage_info = vk.VkPipelineShaderStageCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = vk.VK_SHADER_STAGE_VERTEX_BIT,
            .module = vert_shader_module,
            .pName = "main",
            .pSpecializationInfo = null,
            .flags = 0,
            .pNext = null,
        };

        const frag_shader_stage_info = vk.VkPipelineShaderStageCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = frag_shader_module,
            .pName = "main",
            .pSpecializationInfo = null,
            .flags = 0,
            .pNext = null,
        };

        const shader_stages = [_]vk.VkPipelineShaderStageCreateInfo{
            vert_shader_stage_info,
            frag_shader_stage_info,
        };

        const vertex_input_info = vk.VkPipelineVertexInputStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 0,
            .pVertexBindingDescriptions = null,
            .vertexAttributeDescriptionCount = 0,
            .pVertexAttributeDescriptions = null,
            .flags = 0,
            .pNext = null,
        };

        const input_assembly = vk.VkPipelineInputAssemblyStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = vk.VK_FALSE,
            .flags = 0,
            .pNext = null,
        };

        // Add dynamic state for viewport and scissor
        const dynamic_states = [_]vk.VkDynamicState{
            vk.VK_DYNAMIC_STATE_VIEWPORT,
            vk.VK_DYNAMIC_STATE_SCISSOR,
        };

        const dynamic_state = vk.VkPipelineDynamicStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = dynamic_states.len,
            .pDynamicStates = &dynamic_states,
            .flags = 0,
            .pNext = null,
        };

        // Create viewport with proper scaling
        const viewport = vk.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(self.swapchain_extent.width),
            .height = @floatFromInt(self.swapchain_extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };

        const scissor = vk.VkRect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.swapchain_extent,
        };

        const viewport_state = vk.VkPipelineViewportStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = &viewport,
            .scissorCount = 1,
            .pScissors = &scissor,
            .flags = 0,
            .pNext = null,
        };

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
            .flags = 0,
            .pNext = null,
        };

        const multisampling = vk.VkPipelineMultisampleStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = vk.VK_FALSE,
            .rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT,
            .minSampleShading = 1.0,
            .pSampleMask = null,
            .alphaToCoverageEnable = vk.VK_FALSE,
            .alphaToOneEnable = vk.VK_FALSE,
            .flags = 0,
            .pNext = null,
        };

        const color_blend_attachment = vk.VkPipelineColorBlendAttachmentState{
            .colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT | vk.VK_COLOR_COMPONENT_G_BIT | vk.VK_COLOR_COMPONENT_B_BIT | vk.VK_COLOR_COMPONENT_A_BIT,
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
            .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            .flags = 0,
            .pNext = null,
        };

        const pipeline_layout_info = vk.VkPipelineLayoutCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 0,
            .pSetLayouts = null,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
            .flags = 0,
            .pNext = null,
        };

        if (vk.vkCreatePipelineLayout(self.device, &pipeline_layout_info, null, &self.pipeline_layout) != vk.VK_SUCCESS) {
            return error.FailedToCreatePipelineLayout;
        }

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
            .flags = 0,
            .pNext = null,
        };

        if (vk.vkCreateGraphicsPipelines(self.device, null, 1, &pipeline_info, null, &self.graphics_pipeline) != vk.VK_SUCCESS) {
            return error.FailedToCreateGraphicsPipeline;
        }
    }

    fn createFramebuffers(self: *Self) !void {
        self.framebuffers = try std.heap.page_allocator.alloc(vk.VkFramebuffer, self.swapchain_image_views.len);
        errdefer std.heap.page_allocator.free(self.framebuffers);

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
                .flags = 0,
                .pNext = null,
            };

            if (vk.vkCreateFramebuffer(self.device, &framebuffer_info, null, &self.framebuffers[i]) != vk.VK_SUCCESS) {
                return error.FailedToCreateFramebuffer;
            }
        }
    }

    pub fn createSyncObjects(self: *Self) !void {
        // Create semaphores for each swapchain image
        self.image_available_semaphores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain_images.len);
        self.render_finished_semaphores = try self.allocator.alloc(vk.VkSemaphore, self.swapchain_images.len);
        self.in_flight_fences = try self.allocator.alloc(vk.VkFence, MAX_FRAMES_IN_FLIGHT);
        self.images_in_flight = try self.allocator.alloc(vk.VkFence, self.swapchain_images.len);
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
        _ = vk.vkWaitForFences(self.device, 1, &self.in_flight_fences[self.current_frame], vk.VK_TRUE, std.math.maxInt(u64));

        var image_index: u32 = undefined;
        const result = vk.vkAcquireNextImageKHR(
            self.device,
            self.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[self.current_frame],
            null,
            &image_index,
        );

        if (result == vk.VK_ERROR_OUT_OF_DATE_KHR or result == vk.VK_SUBOPTIMAL_KHR or self.framebuffer_resized) {
            self.framebuffer_resized = false;
            try self.recreateSwapChain();
            return;
        } else if (result != vk.VK_SUCCESS) {
            return error.FailedToAcquireSwapchainImage;
        }

        // Check if a previous frame is using this image
        if (self.images_in_flight[image_index] != null) {
            _ = vk.vkWaitForFences(self.device, 1, &self.images_in_flight[image_index].?, vk.VK_TRUE, std.math.maxInt(u64));
        }
        // Mark the image as now being in use by this frame
        self.images_in_flight[image_index] = self.in_flight_fences[self.current_frame];

        try self.updateUniformBuffer(self.current_frame);

        const submit_info = vk.VkSubmitInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.image_available_semaphores[self.current_frame],
            .pWaitDstStageMask = &[_]vk.VkPipelineStageFlags{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
            .commandBufferCount = 1,
            .pCommandBuffers = &self.command_buffers[image_index],
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &self.render_finished_semaphores[self.current_frame],
            .pNext = null,
        };

        _ = vk.vkResetFences(self.device, 1, &self.in_flight_fences[self.current_frame]);

        if (vk.vkQueueSubmit(self.graphics_queue, 1, &submit_info, self.in_flight_fences[self.current_frame]) != vk.VK_SUCCESS) {
            return error.FailedToSubmitDrawCommandBuffer;
        }

        const present_info = vk.VkPresentInfoKHR{
            .sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.render_finished_semaphores[self.current_frame],
            .swapchainCount = 1,
            .pSwapchains = &self.swapchain,
            .pImageIndices = &image_index,
            .pResults = null,
            .pNext = null,
        };

        const present_result = vk.vkQueuePresentKHR(self.present_queue, &present_info);

        if (present_result == vk.VK_ERROR_OUT_OF_DATE_KHR or present_result == vk.VK_SUBOPTIMAL_KHR or self.framebuffer_resized) {
            self.framebuffer_resized = false;
            try self.recreateSwapChain();
        } else if (present_result != vk.VK_SUCCESS) {
            return error.FailedToPresentSwapchainImage;
        }

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn recordCommandBuffer(self: *Self, command_buffer: vk.VkCommandBuffer, image_index: u32) !void {
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = 0,
            .pInheritanceInfo = null,
            .pNext = null,
        };

        if (vk.vkBeginCommandBuffer(command_buffer, &begin_info) != vk.VK_SUCCESS) {
            return error.FailedToBeginCommandBuffer;
        }

        const clear_color = vk.VkClearValue{
            .color = .{
                .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        };

        const render_pass_info = vk.VkRenderPassBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.swapchain_extent,
            },
            .clearValueCount = 1,
            .pClearValues = &clear_color,
            .pNext = null,
        };

        vk.vkCmdBeginRenderPass(command_buffer, &render_pass_info, vk.VK_SUBPASS_CONTENTS_INLINE);

        vk.vkCmdBindPipeline(command_buffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphics_pipeline);

        // Calculate viewport with proper scaling
        const viewport = vk.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(self.swapchain_extent.width),
            .height = @floatFromInt(self.swapchain_extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };

        const scissor = vk.VkRect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.swapchain_extent,
        };

        vk.vkCmdSetViewport(command_buffer, 0, 1, &viewport);
        vk.vkCmdSetScissor(command_buffer, 0, 1, &scissor);

        vk.vkCmdDraw(command_buffer, 3, 1, 0, 0);

        vk.vkCmdEndRenderPass(command_buffer);

        if (vk.vkEndCommandBuffer(command_buffer) != vk.VK_SUCCESS) {
            return error.FailedToEndCommandBuffer;
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

    fn findMemoryType(
        self: *Self,
        type_filter: u32,
        properties: vk.VkMemoryPropertyFlags,
    ) !u32 {
        var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &mem_properties);

        for (0..mem_properties.memoryTypeCount) |i| {
            if ((type_filter & (@as(u32, 1) << @intCast(i))) != 0 and
                (mem_properties.memoryTypes[i].propertyFlags & properties) == properties)
            {
                return @intCast(i);
            }
        }

        return error.NoSuitableMemoryType;
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

    fn querySwapChainSupport(device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) !SwapChainSupportDetails {
        var details = SwapChainSupportDetails{
            .capabilities = undefined,
            .formats = undefined,
            .present_modes = undefined,
        };

        if (vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities) != vk.VK_SUCCESS) {
            return error.FailedToGetSurfaceCapabilities;
        }

        var format_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, null);

        if (format_count != 0) {
            details.formats = try std.heap.page_allocator.alloc(vk.VkSurfaceFormatKHR, format_count);
            _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, details.formats.ptr);
        }

        var present_mode_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null);

        if (present_mode_count != 0) {
            details.present_modes = try std.heap.page_allocator.alloc(vk.VkPresentModeKHR, present_mode_count);
            _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, details.present_modes.ptr);
        }

        return details;
    }

    fn isDeviceSuitable(device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) bool {
        const indices = findQueueFamilies(device, surface) catch return false;
        const extensions_supported = checkDeviceExtensionSupport(device) catch return false;
        var swap_chain_adequate = false;
        if (extensions_supported) {
            const swap_chain_support = querySwapChainSupport(device, surface) catch return false;
            defer {
                if (swap_chain_support.formats.len > 0) {
                    std.heap.page_allocator.free(swap_chain_support.formats);
                }
                if (swap_chain_support.present_modes.len > 0) {
                    std.heap.page_allocator.free(swap_chain_support.present_modes);
                }
            }
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

        if (vk.vkQueueSubmit(self.graphics_queue, 1, &submit_info, null) != vk.VK_SUCCESS) {
            vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
            return error.QueueSubmitFailed;
        }

        std.log.info("Waiting for queue idle...", .{});

        if (vk.vkQueueWaitIdle(self.graphics_queue) != vk.VK_SUCCESS) {
            vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
            return error.QueueWaitIdleFailed;
        }

        vk.vkFreeCommandBuffers(self.device, self.command_pool, 1, &command_buffer);
        std.log.info("Vertex buffer creation complete", .{});
    }

    pub fn updateUniformBuffer(self: *Self, current_frame: usize) !void {
        const time = @as(f32, @floatCast(glfw.glfwGetTime()));
        const model = createRotationMatrix(time * @as(f32, std.math.pi) / 2.0);
        const view = createLookAtMatrix(
            [3]f32{ 2.0, 2.0, 2.0 },
            [3]f32{ 0.0, 0.0, 0.0 },
            [3]f32{ 0.0, 0.0, 1.0 },
        );
        const proj = createPerspectiveMatrix(
            @as(f32, @floatFromInt(self.swapchain_extent.width)) / @as(f32, @floatFromInt(self.swapchain_extent.height)),
            0.1,
            10.0,
        );

        const ubo = UniformBufferObject{
            .model = model,
            .view = view,
            .proj = proj,
        };

        const data = @as([*]u8, @ptrCast(self.uniform_buffers_mapped[current_frame]));
        @memcpy(data[0..@sizeOf(UniformBufferObject)], std.mem.asBytes(&ubo));
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

    pub fn createUniformBuffers(self: *Self) !void {
        const buffer_size = @sizeOf(UniformBufferObject);

        self.uniform_buffers = try self.allocator.alloc(vk.VkBuffer, MAX_FRAMES_IN_FLIGHT);
        self.uniform_buffers_memory = try self.allocator.alloc(vk.VkDeviceMemory, MAX_FRAMES_IN_FLIGHT);
        self.uniform_buffers_mapped = try self.allocator.alloc([*]u8, MAX_FRAMES_IN_FLIGHT);

        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            try self.createBuffer(
                buffer_size,
                vk.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                &self.uniform_buffers[i],
                &self.uniform_buffers_memory[i],
            );

            var data: [*]u8 = undefined;
            _ = vk.vkMapMemory(
                self.device,
                self.uniform_buffers_memory[i],
                0,
                buffer_size,
                0,
                @ptrCast(&data),
            );
            self.uniform_buffers_mapped[i] = data;
        }
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

    pub fn createDescriptorSets(self: *Self) !void {
        const layouts = try self.allocator.alloc(vk.VkDescriptorSetLayout, MAX_FRAMES_IN_FLIGHT);
        defer self.allocator.free(layouts);
        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            layouts[i] = self.descriptor_set_layout;
        }

        const alloc_info = vk.VkDescriptorSetAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool = self.descriptor_pool,
            .descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
            .pSetLayouts = layouts.ptr,
            .pNext = null,
        };

        self.descriptor_sets = try self.allocator.alloc(vk.VkDescriptorSet, MAX_FRAMES_IN_FLIGHT);
        if (vk.vkAllocateDescriptorSets(self.device, &alloc_info, self.descriptor_sets.ptr) != vk.VK_SUCCESS) {
            return error.DescriptorSetAllocationFailed;
        }

        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            const buffer_info = vk.VkDescriptorBufferInfo{
                .buffer = self.uniform_buffers[i],
                .offset = 0,
                .range = @sizeOf(UniformBufferObject),
            };

            const descriptor_write = vk.VkWriteDescriptorSet{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .dstSet = self.descriptor_sets[i],
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1,
                .pBufferInfo = &buffer_info,
                .pImageInfo = null,
                .pTexelBufferView = null,
                .pNext = null,
            };

            vk.vkUpdateDescriptorSets(self.device, 1, &descriptor_write, 0, null);
        }
    }

    pub fn cleanupDescriptorSets(self: *Self) void {
        self.allocator.free(self.descriptor_sets);
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

    pub fn recreateSwapChain(self: *Self) !void {
        var width: c_int = undefined;
        var height: c_int = undefined;
        glfw.glfwGetFramebufferSize(self.window, &width, &height);
        while (width == 0 or height == 0) {
            glfw.glfwGetFramebufferSize(self.window, &width, &height);
            glfw.glfwWaitEvents();
        }
        std.log.info("[Vulkan] Resizing: window size = {d}x{d}", .{width, height});

        _ = vk.vkDeviceWaitIdle(self.device);

        self.cleanupSwapChain();

        try self.createSwapChain();
        try self.createImageViews();
        try self.createRenderPass();
        try self.createDepthResources();
        try self.createGraphicsPipeline();
        try self.createFramebuffers();
        try self.createCommandBuffers();
    }

    fn cleanupSwapChain(self: *Self) void {
        if (self.command_buffers.len > 0) {
            vk.vkFreeCommandBuffers(self.device, self.command_pool, @intCast(self.command_buffers.len), self.command_buffers.ptr);
            self.allocator.free(self.command_buffers);
        }

        for (self.framebuffers) |framebuffer| {
            vk.vkDestroyFramebuffer(self.device, framebuffer, null);
        }
        self.allocator.free(self.framebuffers);

        if (self.graphics_pipeline != null) {
            vk.vkDestroyPipeline(self.device, self.graphics_pipeline, null);
        }

        if (self.pipeline_layout != null) {
            vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);
        }

        if (self.render_pass != null) {
            vk.vkDestroyRenderPass(self.device, self.render_pass, null);
        }

        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }
        self.allocator.free(self.swapchain_image_views);

        if (self.swapchain != null) {
            vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);
        }
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

    fn framebufferResizeCallback(window: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
        _ = width;
        _ = height;
        const app = @as(*Self, @alignCast(@ptrCast(glfw.glfwGetWindowUserPointer(window).?)));
        app.framebuffer_resized = true;
    }

    fn readFile(self: *Self, path: []const u8) ![]u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try self.allocator.alloc(u8, file_size);
        errdefer self.allocator.free(buffer);

        const bytes_read = try file.readAll(buffer);
        if (bytes_read != file_size) {
            return error.IncompleteRead;
        }

        return buffer;
    }

    fn createShaderModule(self: *Self, code: []const u8) !vk.VkShaderModule {
        var create_info = vk.VkShaderModuleCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = code.len,
            .pCode = @ptrCast(@alignCast(code.ptr)),
            .pNext = null,
            .flags = 0,
        };

        var shader_module: vk.VkShaderModule = undefined;
        if (vk.vkCreateShaderModule(self.device, &create_info, null, &shader_module) != vk.VK_SUCCESS) {
            return error.FailedToCreateShaderModule;
        }

        return shader_module;
    }

    fn createBuffer(
        self: *Self,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        properties: vk.VkMemoryPropertyFlags,
        buffer: *vk.VkBuffer,
        buffer_memory: *vk.VkDeviceMemory,
    ) !void {
        const buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = size,
            .usage = usage,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        if (vk.vkCreateBuffer(self.device, &buffer_info, null, buffer) != vk.VK_SUCCESS) {
            return error.BufferCreationFailed;
        }

        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(self.device, buffer.*, &mem_requirements);

        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = try self.findMemoryType(
                mem_requirements.memoryTypeBits,
                properties,
            ),
            .pNext = null,
        };

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, buffer_memory) != vk.VK_SUCCESS) {
            vk.vkDestroyBuffer(self.device, buffer.*, null);
            return error.MemoryAllocationFailed;
        }

        if (vk.vkBindBufferMemory(self.device, buffer.*, buffer_memory.*, 0) != vk.VK_SUCCESS) {
            vk.vkDestroyBuffer(self.device, buffer.*, null);
            vk.vkFreeMemory(self.device, buffer_memory.*, null);
            return error.MemoryBindingFailed;
        }
    }
}; 
