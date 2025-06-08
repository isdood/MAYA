const std = @import("std");
const vk = @cImport({
    @cDefine("VK_USE_PLATFORM_XCB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});

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

    instance: vk.VkInstance,
    surface: vk.VkSurfaceKHR,
    physical_device: vk.VkPhysicalDevice,
    device: vk.VkDevice,
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
    current_frame: usize,
    allocator: std.mem.Allocator,
    rotation: f32,
    framebuffer_resized: bool,

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
            .current_frame = 0,
            .allocator = std.heap.page_allocator,
            .rotation = 0.0,
            .framebuffer_resized = false,
        };

        try self.createInstance();
        try self.createSurface(window);
        try self.pickPhysicalDevice();
        try self.createLogicalDevice();
        try self.createSwapChain();
        try self.createImageViews();
        try self.createRenderPass();
        try self.createGraphicsPipeline();
        try self.createFramebuffers();
        try self.createCommandPool();
        try self.createCommandBuffers();
        try self.createSyncObjects();

        return self;
    }

    pub fn deinit(self: *Self) void {
        vk.vkDeviceWaitIdle(self.device);

        for (self.in_flight_fences) |fence| {
            vk.vkDestroyFence(self.device, fence, null);
        }
        for (self.render_finished_semaphores) |semaphore| {
            vk.vkDestroySemaphore(self.device, semaphore, null);
        }
        for (self.image_available_semaphores) |semaphore| {
            vk.vkDestroySemaphore(self.device, semaphore, null);
        }
        vk.vkDestroyCommandPool(self.device, self.command_pool, null);
        for (self.framebuffers) |framebuffer| {
            vk.vkDestroyFramebuffer(self.device, framebuffer, null);
        }
        vk.vkDestroyPipeline(self.device, self.graphics_pipeline, null);
        vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);
        vk.vkDestroyRenderPass(self.device, self.render_pass, null);
        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }
        vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);
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

        const extensions = [_][*:0]const u8{
            vk.VK_KHR_SURFACE_EXTENSION_NAME,
            vk.VK_KHR_XCB_SURFACE_EXTENSION_NAME,
        };

        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = extensions.len,
            .ppEnabledExtensionNames = &extensions,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateInstance(&create_info, null, &self.instance) != vk.VK_SUCCESS) {
            return error.InstanceCreationFailed;
        }
    }

    fn createSurface(self: *Self, window: *glfw.GLFWwindow) !void {
        const result = glfw.glfwCreateWindowSurface(
            @ptrCast(*glfw.VkInstance, self.instance),
            window,
            null,
            &self.surface,
        );
        if (result != vk.VK_SUCCESS) {
            return error.SurfaceCreationFailed;
        }
    }

    fn pickPhysicalDevice(self: *Self) !void {
        var device_count: u32 = undefined;
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, null);

        if (device_count == 0) {
            return error.NoVulkanDevicesFound;
        }

        const devices = try self.allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer self.allocator.free(devices);
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr);

        for (devices) |device| {
            if (try isDeviceSuitable(device, self.surface)) {
                self.physical_device = device;
                var device_properties: vk.VkPhysicalDeviceProperties = undefined;
                vk.vkGetPhysicalDeviceProperties(device, &device_properties);
                std.log.info("Selected physical device: {s}", .{std.mem.span(&device_properties.deviceName)});
                return;
            }
        }

        return error.NoSuitableDeviceFound;
    }

    fn createLogicalDevice(self: *Self) !void {
        var queue_family_count: u32 = undefined;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, null);

        const queue_families = try std.heap.page_allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer std.heap.page_allocator.free(queue_families);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, queue_families.ptr);

        var graphics_queue_family: ?u32 = null;
        var present_queue_family: ?u32 = null;

        var i: usize = 0;
        for (queue_families) |queue_family| {
            if (queue_family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                graphics_queue_family = @intCast(i);
            }

            var present_support: vk.VkBool32 = undefined;
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(self.physical_device, @intCast(i), self.surface, &present_support);
            if (present_support != 0) {
                present_queue_family = @intCast(i);
            }

            if (graphics_queue_family != null and present_queue_family != null) break;
            i += 1;
        }

        var queue_create_infos = std.ArrayList(vk.VkDeviceQueueCreateInfo).init(std.heap.page_allocator);
        defer queue_create_infos.deinit();

        const queue_priority = [_]f32{1.0};
        if (graphics_queue_family) |family| {
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

        try checkVulkanResult(vk.vkCreateDevice(self.physical_device, &device_create_info, null, &self.device));
    }

    fn createSwapChain(self: *Self) !void {
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
            &self.pipeline,
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

    fn createCommandPool(self: *Self) !void {
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

        var memory_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &memory_properties);

        var memory_type_index: u32 = undefined;
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

        if (vk.vkAllocateMemory(self.device, &alloc_info, null, &self.uniform_buffer_memory) != vk.VK_SUCCESS) {
            return error.UniformMemoryAllocationFailed;
        }

        if (vk.vkBindBufferMemory(self.device, self.uniform_buffer, self.uniform_buffer_memory, 0) != vk.VK_SUCCESS) {
            return error.UniformMemoryBindingFailed;
        }

        if (vk.vkMapMemory(self.device, self.uniform_buffer_memory, 0, buffer_size, 0, &self.uniform_buffer_mapped) != vk.VK_SUCCESS) {
            return error.UniformMemoryMappingFailed;
        }
    }

    fn updateUniformBuffer(self: *Self) void {
        const rotation_matrix = createRotationMatrix(self.rotation);
        const dest = @as([*]u8, @ptrCast(self.uniform_buffer_mapped))[0..@sizeOf([4][4]f32)];
        const src = @as([*]const u8, @ptrCast(&rotation_matrix))[0..@sizeOf([4][4]f32)];
        std.mem.copy(u8, dest, src);
    }

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

    fn createDescriptorSetLayout(self: *Self) !void {
        const descriptor_set_layout_info = vk.VkDescriptorSetLayoutCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .bindingCount = 1,
            .pBindings = &[_]vk.VkDescriptorSetLayoutBinding{
                vk.VkDescriptorSetLayoutBinding{
                    .binding = 0,
                    .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    .descriptorCount = 1,
                    .stageFlags = vk.VK_SHADER_STAGE_VERTEX_BIT,
                    .pImmutableSamplers = null,
                },
            },
            .pNext = null,
            .flags = 0,
        };

        try checkVulkanResult(vk.vkCreateDescriptorSetLayout(
            self.device,
            &descriptor_set_layout_info,
            null,
            &self.descriptor_set_layout,
        ));
    }

    fn createDescriptorPool(self: *Self) !void {
        const pool_sizes = [_]vk.VkDescriptorPoolSize{
            vk.VkDescriptorPoolSize{
                .type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1,
            },
        };

        const pool_info = vk.VkDescriptorPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .maxSets = 1,
            .poolSizeCount = pool_sizes.len,
            .pPoolSizes = pool_sizes.ptr,
            .pNext = null,
            .flags = 0,
        };

        try checkVulkanResult(vk.vkCreateDescriptorPool(
            self.device,
            &pool_info,
            null,
            &self.descriptor_pool,
        ));
    }

    fn createDescriptorSets(self: *Self) !void {
        const descriptor_set_alloc_info = vk.VkDescriptorSetAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
            .descriptorPool = self.descriptor_pool,
            .descriptorSetCount = 1,
            .pSetLayouts = &self.descriptor_set_layout,
            .pNext = null,
        };

        try checkVulkanResult(vk.vkAllocateDescriptorSets(
            self.device,
            &descriptor_set_alloc_info,
            &self.descriptor_set,
        ));

        const buffer_info = vk.VkDescriptorBufferInfo{
            .buffer = self.uniform_buffer,
            .offset = 0,
            .range = @sizeOf([4][4]f32),
        };

        const write_descriptor_set = vk.VkWriteDescriptorSet{
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

        vk.vkUpdateDescriptorSets(self.device, 1, &write_descriptor_set, 0, null);
    }

    fn createCommandBuffers(self: *Self) !void {
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

    fn createSyncObjects(self: *Self) !void {
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

    fn framebufferResizeCallback(window: *glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
        _ = width;
        _ = height;
        const ptr = glfw.glfwGetWindowUserPointer(window);
        const self = @as(*Self, @ptrCast(ptr));
        self.framebuffer_resized = true;
    }

    fn recreateSwapChain(self: *Self) !void {
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
        try self.createDepthResources();
        try self.createRenderPass();
        try self.createGraphicsPipeline();
        try self.createFramebuffers();
        try self.createCommandBuffers();
    }

    fn cleanupSwapChain(self: *Self) void {
        // Clean up framebuffers
        for (self.framebuffers) |framebuffer| {
            vk.vkDestroyFramebuffer(self.device, framebuffer, null);
        }

        // Clean up depth resources
        vk.vkDestroyImageView(self.device, self.depth_image_view, null);
        vk.vkDestroyImage(self.device, self.depth_image, null);
        vk.vkFreeMemory(self.device, self.depth_image_memory, null);

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

    pub fn drawFrame(self: *Self) !void {
        // Wait for the previous frame to finish
        try checkVulkanResult(vk.vkWaitForFences(
            self.device,
            1,
            &self.in_flight_fences[self.current_frame],
            vk.VK_TRUE,
            std.math.maxInt(u64),
        ));

        // Acquire an image from the swapchain
        var image_index: u32 = undefined;
        const acquire_result = vk.vkAcquireNextImageKHR(
            self.device,
            self.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[self.current_frame],
            null,
            &image_index,
        );

        if (acquire_result == vk.VK_ERROR_OUT_OF_DATE_KHR) {
            try self.recreateSwapChain();
            return;
        } else if (acquire_result != vk.VK_SUCCESS and acquire_result != vk.VK_SUBOPTIMAL_KHR) {
            return error.FailedToAcquireSwapChainImage;
        }

        // Update uniform buffer
        self.rotation += 0.01;
        self.updateUniformBuffer();

        // Reset the fence for the current frame
        try checkVulkanResult(vk.vkResetFences(
            self.device,
            1,
            &self.in_flight_fences[self.current_frame],
        ));

        // Record the command buffer
        try self.recordCommandBuffer(self.command_buffers[self.current_frame], image_index);

        // Submit the command buffer
        const wait_semaphores = [_]vk.VkSemaphore{self.image_available_semaphores[self.current_frame]};
        const signal_semaphores = [_]vk.VkSemaphore{self.render_finished_semaphores[self.current_frame]};
        const wait_stages = [_]vk.VkPipelineStageFlags{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

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

        // Present the image
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

    fn recordCommandBuffer(self: *Self, command_buffer: vk.VkCommandBuffer, image_index: u32) !void {
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = 0,
            .pNext = null,
            .pInheritanceInfo = null,
        };

        try checkVulkanResult(vk.vkBeginCommandBuffer(command_buffer, &begin_info));

        const clear_values = [_]vk.VkClearValue{
            vk.VkClearValue{
                .color = vk.VkClearColorValue{
                    .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
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

        vk.vkCmdBindPipeline(command_buffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline);

        const vertex_buffers = [_]vk.VkBuffer{self.vertex_buffer};
        const offsets = [_]vk.VkDeviceSize{0};
        vk.vkCmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffers, &offsets);

        vk.vkCmdDraw(command_buffer, 9, 1, 0, 0); // Draw all 9 vertices (3 triangles)

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

    fn isDeviceSuitable(self: *Self, device: vk.VkPhysicalDevice) !bool {
        // Check device extension support
        try checkDeviceExtensionSupport(device);

        // Check swapchain support
        var format_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, null);
        if (format_count == 0) return false;

        var present_mode_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_mode_count, null);
        if (present_mode_count == 0) return false;

        // Check queue families
        var queue_family_count: u32 = undefined;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        var queue_families = try std.heap.page_allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer std.heap.page_allocator.free(queue_families);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_families.ptr);

        var graphics_queue_found = false;
        var present_queue_found = false;

        var i: usize = 0;
        for (queue_families) |queue_family| {
            if (queue_family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                graphics_queue_found = true;
            }

            var present_support: vk.VkBool32 = undefined;
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), self.surface, &present_support);
            if (present_support != 0) {
                present_queue_found = true;
            }

            if (graphics_queue_found and present_queue_found) break;
            i += 1;
        }

        return graphics_queue_found and present_queue_found;
    }

    fn checkDeviceExtensionSupport(device: vk.VkPhysicalDevice) !void {
        var extension_count: u32 = undefined;
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, null);

        const available_extensions = try std.heap.page_allocator.alloc(vk.VkExtensionProperties, extension_count);
        defer std.heap.page_allocator.free(available_extensions);
        _ = vk.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, available_extensions.ptr);

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

    fn findQueueFamilies(device: vk.VkPhysicalDevice, self: *Self) !QueueFamilyIndices {
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
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(device, i, self.surface, &present_support);
            if (present_support != 0) {
                indices.present_family = i;
            }

            if (indices.isComplete()) break;
        }

        return indices;
    }
}; 