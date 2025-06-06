const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const colors = @import("../glimmer/colors.zig").GlimmerColors;

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
    window: *glfw.GLFWwindow,

    const MAX_FRAMES_IN_FLIGHT = 2;

    pub fn init(window: *glfw.GLFWwindow) !VulkanRenderer {
        var self = VulkanRenderer{
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
        };

        try self.createInstance();
        try self.createSurface();
        try self.pickPhysicalDevice();
        try self.createLogicalDevice();
        try self.createSwapChain();
        try self.createImageViews();
        try self.createRenderPass();
        try self.createGraphicsPipeline();
        try self.createFramebuffers();
        try self.createCommandPool();
        try self.createVertexBuffer();
        try self.createCommandBuffers();
        try self.createSyncObjects();

        return self;
    }

    pub fn deinit(self: *VulkanRenderer) void {
        vk.vkDeviceWaitIdle(self.device);

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

        // Cleanup image views
        for (self.swapchain_image_views) |image_view| {
            vk.vkDestroyImageView(self.device, image_view, null);
        }

        // Cleanup swapchain
        vk.vkDestroySwapchainKHR(self.device, self.swapchain, null);

        // Cleanup device and instance
        vk.vkDestroyDevice(self.device, null);
        vk.vkDestroyInstance(self.instance, null);
    }

    fn createInstance(self: *VulkanRenderer) !void {
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "MAYA",
            .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
            .pNext = null,
        };

        var glfw_extension_count: u32 = 0;
        const glfw_extensions = glfw.glfwGetRequiredInstanceExtensions(&glfw_extension_count);

        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = glfw_extension_count,
            .ppEnabledExtensionNames = glfw_extensions,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateInstance(&create_info, null, &self.instance) != vk.VK_SUCCESS) {
            return error.VulkanInstanceCreationFailed;
        }
    }

    fn createSurface(self: *VulkanRenderer) !void {
        if (glfw.glfwCreateWindowSurface(self.instance, self.window, null, &self.surface) != vk.VK_SUCCESS) {
            return error.SurfaceCreationFailed;
        }
    }

    fn pickPhysicalDevice(self: *VulkanRenderer) !void {
        var device_count: u32 = 0;
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, null);

        if (device_count == 0) {
            return error.NoVulkanDevicesFound;
        }

        var devices = try std.heap.page_allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer std.heap.page_allocator.free(devices);
        _ = vk.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr);

        // For now, just pick the first device
        self.physical_device = devices[0];
    }

    fn createLogicalDevice(self: *VulkanRenderer) !void {
        const queue_family_index: u32 = 0; // Assuming first queue family supports graphics

        const queue_priority: f32 = 1.0;
        const queue_create_info = vk.VkDeviceQueueCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queue_family_index,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
            .pNext = null,
            .flags = 0,
        };

        const device_create_info = vk.VkDeviceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pEnabledFeatures = null,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateDevice(self.physical_device, &device_create_info, null, &self.device) != vk.VK_SUCCESS) {
            return error.DeviceCreationFailed;
        }

        vk.vkGetDeviceQueue(self.device, queue_family_index, 0, &self.queue);
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

        // Vertex input state
        const vertex_input_info = vk.VkPipelineVertexInputStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 0,
            .pVertexBindingDescriptions = null,
            .vertexAttributeDescriptionCount = 0,
            .pVertexAttributeDescriptions = null,
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

        // Viewport state
        var viewport = vk.VkViewport{
            .x = 0.0,
            .y = 0.0,
            .width = 800.0, // TODO: Get from window
            .height = 600.0,
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };

        var scissor = vk.VkRect2D{
            .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
            .extent = vk.VkExtent2D{ .width = 800, .height = 600 }, // TODO: Get from window
        };

        const viewport_state = vk.VkPipelineViewportStateCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = &viewport,
            .scissorCount = 1,
            .pScissors = &scissor,
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

        if (vk.vkCreatePipelineLayout(self.device, &pipeline_layout_info, null, &self.pipeline_layout) != vk.VK_SUCCESS) {
            return error.PipelineLayoutCreationFailed;
        }

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
            .pDynamicState = null,
            .layout = self.pipeline_layout,
            .renderPass = self.render_pass,
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateGraphicsPipelines(self.device, null, 1, &pipeline_info, null, &self.pipeline) != vk.VK_SUCCESS) {
            return error.GraphicsPipelineCreationFailed;
        }
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

        if (vk.vkQueueSubmit(self.queue, 1, &submit_info, null) != vk.VK_SUCCESS) {
            return error.QueueSubmitFailed;
        }

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

    pub fn drawFrame(self: *VulkanRenderer) !void {
        // Wait for the previous frame to finish
        _ = vk.vkWaitForFences(self.device, 1, &self.in_flight_fences[self.current_frame], vk.VK_TRUE, std.math.maxInt(u64));

        // Acquire an image from the swapchain
        var image_index: u32 = undefined;
        _ = vk.vkAcquireNextImageKHR(
            self.device,
            self.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[self.current_frame],
            null,
            &image_index,
        );

        // Reset the fence for the current frame
        _ = vk.vkResetFences(self.device, 1, &self.in_flight_fences[self.current_frame]);

        // Record the command buffer
        const command_buffer = self.command_buffers[image_index];
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = 0,
            .pNext = null,
            .pInheritanceInfo = null,
        };

        _ = vk.vkBeginCommandBuffer(command_buffer, &begin_info);

        const render_pass_info = vk.VkRenderPassBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .renderArea = vk.VkRect2D{
                .offset = vk.VkOffset2D{ .x = 0, .y = 0 },
                .extent = vk.VkExtent2D{ .width = 800, .height = 600 }, // TODO: Get from window
            },
            .clearValueCount = 1,
            .pClearValues = &vk.VkClearValue{
                .color = vk.VkClearColorValue{
                    .float32 = [4]f32{ 0.0, 0.0, 0.0, 1.0 },
                },
            },
            .pNext = null,
        };

        vk.vkCmdBeginRenderPass(command_buffer, &render_pass_info, vk.VK_SUBPASS_CONTENTS_INLINE);
        vk.vkCmdBindPipeline(command_buffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline);
        vk.vkCmdDraw(command_buffer, 3, 1, 0, 0); // Draw a triangle
        vk.vkCmdEndRenderPass(command_buffer);

        if (vk.vkEndCommandBuffer(command_buffer) != vk.VK_SUCCESS) {
            return error.CommandBufferRecordingFailed;
        }

        // Submit the command buffer
        const submit_info = vk.VkSubmitInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.image_available_semaphores[self.current_frame],
            .pWaitDstStageMask = &[_]vk.VkPipelineStageFlags{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer,
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &self.render_finished_semaphores[self.current_frame],
            .pNext = null,
        };

        if (vk.vkQueueSubmit(self.queue, 1, &submit_info, self.in_flight_fences[self.current_frame]) != vk.VK_SUCCESS) {
            return error.QueueSubmitFailed;
        }

        // Present the image
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

        _ = vk.vkQueuePresentKHR(self.queue, &present_info);

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }
}; 