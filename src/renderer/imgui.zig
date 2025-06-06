const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const c = @cImport({
    @cInclude("imgui.h");
    @cInclude("imgui_impl_glfw.h");
    @cInclude("imgui_impl_vulkan.h");
});
const glfw = @import("glfw");
const Window = @import("window.zig").Window;
const VulkanRenderer = @import("vulkan.zig").VulkanRenderer;

pub const ImGuiRenderer = struct {
    const Self = @This();

    // ImGui state
    descriptor_pool: vk.VkDescriptorPool,
    render_pass: vk.VkRenderPass,
    pipeline: vk.VkPipeline,
    pipeline_layout: vk.VkPipelineLayout,
    font_sampler: vk.VkSampler,
    font_image: vk.VkImage,
    font_image_view: vk.VkImageView,
    font_memory: vk.VkDeviceMemory,
    font_descriptor_set: vk.VkDescriptorSet,
    vertex_buffer: vk.VkBuffer,
    vertex_buffer_memory: vk.VkDeviceMemory,
    index_buffer: vk.VkBuffer,
    index_buffer_memory: vk.VkDeviceMemory,
    vertex_count: u32,
    index_count: u32,
    allocator: std.mem.Allocator,
    logger: std.log.Logger,

    // Initialize ImGui with Vulkan
    pub fn init(renderer: *VulkanRenderer, window: *Window) !*Self {
        var self = try renderer.allocator.create(Self);
        self.* = Self{
            .descriptor_pool = undefined,
            .render_pass = undefined,
            .pipeline = undefined,
            .pipeline_layout = undefined,
            .font_sampler = undefined,
            .font_image = undefined,
            .font_image_view = undefined,
            .font_memory = undefined,
            .font_descriptor_set = undefined,
            .vertex_buffer = undefined,
            .vertex_buffer_memory = undefined,
            .index_buffer = undefined,
            .index_buffer_memory = undefined,
            .vertex_count = 0,
            .index_count = 0,
            .allocator = renderer.allocator,
            .logger = std.log.scoped(.imgui),
        };

        // Initialize ImGui context
        _ = c.igCreateContext(null);
        _ = c.igStyleColorsDark(null);

        // Initialize ImGui for GLFW
        if (c.ImGui_ImplGlfw_InitForVulkan(window.handle, true) == 0) {
            return error.ImGuiGlfwInitFailed;
        }

        // Initialize ImGui for Vulkan
        var init_info = c.ImGui_ImplVulkan_InitInfo{
            .Instance = renderer.instance,
            .PhysicalDevice = renderer.physical_device,
            .Device = renderer.device,
            .QueueFamily = 0, // TODO: Get from renderer
            .Queue = renderer.queue,
            .PipelineCache = null,
            .DescriptorPool = undefined,
            .Subpass = 0,
            .MinImageCount = 2,
            .ImageCount = 2,
            .MSAASamples = vk.VK_SAMPLE_COUNT_1_BIT,
            .Allocator = null,
            .CheckVkResultFn = null,
        };

        // Create descriptor pool for ImGui
        const pool_sizes = [_]vk.VkDescriptorPoolSize{
            .{
                .type = vk.VK_DESCRIPTOR_TYPE_SAMPLER,
                .descriptorCount = 1000,
            },
            .{
                .type = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = 1000,
            },
            .{
                .type = vk.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
                .descriptorCount = 1000,
            },
            .{
                .type = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                .descriptorCount = 1000,
            },
            .{
                .type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1000,
            },
            .{
                .type = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .descriptorCount = 1000,
            },
        };

        const pool_info = vk.VkDescriptorPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
            .flags = vk.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
            .maxSets = 1000,
            .poolSizeCount = pool_sizes.len,
            .pPoolSizes = &pool_sizes,
            .pNext = null,
        };

        if (vk.vkCreateDescriptorPool(renderer.device, &pool_info, null, &self.descriptor_pool) != vk.VK_SUCCESS) {
            return error.DescriptorPoolCreationFailed;
        }

        init_info.DescriptorPool = self.descriptor_pool;

        // Create render pass for ImGui
        const color_attachment = vk.VkAttachmentDescription{
            .format = vk.VK_FORMAT_B8G8R8A8_UNORM,
            .samples = vk.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = vk.VK_ATTACHMENT_LOAD_OP_LOAD,
            .storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE,
            .stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
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
            .pDepthStencilAttachment = null,
            .inputAttachmentCount = 0,
            .pInputAttachments = null,
            .preserveAttachmentCount = 0,
            .pPreserveAttachments = null,
            .pResolveAttachments = null,
            .flags = 0,
        };

        const dependency = vk.VkSubpassDependency{
            .srcSubpass = vk.VK_SUBPASS_EXTERNAL,
            .dstSubpass = 0,
            .srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .srcAccessMask = 0,
            .dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            .dependencyFlags = 0,
        };

        const render_pass_info = vk.VkRenderPassCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = &color_attachment,
            .subpassCount = 1,
            .pSubpasses = &subpass,
            .dependencyCount = 1,
            .pDependencies = &dependency,
            .pNext = null,
            .flags = 0,
        };

        if (vk.vkCreateRenderPass(renderer.device, &render_pass_info, null, &self.render_pass) != vk.VK_SUCCESS) {
            return error.RenderPassCreationFailed;
        }

        // Initialize ImGui Vulkan implementation
        if (c.ImGui_ImplVulkan_Init(&init_info, self.render_pass) == 0) {
            return error.ImGuiVulkanInitFailed;
        }

        // Upload fonts
        var cmd_buffer: vk.VkCommandBuffer = undefined;
        const cmd_alloc_info = vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = renderer.command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
            .pNext = null,
        };

        if (vk.vkAllocateCommandBuffers(renderer.device, &cmd_alloc_info, &cmd_buffer) != vk.VK_SUCCESS) {
            return error.CommandBufferAllocationFailed;
        }

        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pNext = null,
            .pInheritanceInfo = null,
        };

        if (vk.vkBeginCommandBuffer(cmd_buffer, &begin_info) != vk.VK_SUCCESS) {
            return error.CommandBufferBeginFailed;
        }

        _ = c.ImGui_ImplVulkan_CreateFontsTexture(cmd_buffer);

        if (vk.vkEndCommandBuffer(cmd_buffer) != vk.VK_SUCCESS) {
            return error.CommandBufferEndFailed;
        }

        const submit_info = vk.VkSubmitInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .commandBufferCount = 1,
            .pCommandBuffers = &cmd_buffer,
            .pNext = null,
            .waitSemaphoreCount = 0,
            .pWaitSemaphores = null,
            .pWaitDstStageMask = null,
            .signalSemaphoreCount = 0,
            .pSignalSemaphores = null,
        };

        if (vk.vkQueueSubmit(renderer.queue, 1, &submit_info, null) != vk.VK_SUCCESS) {
            return error.QueueSubmitFailed;
        }

        if (vk.vkDeviceWaitIdle(renderer.device) != vk.VK_SUCCESS) {
            return error.DeviceWaitIdleFailed;
        }

        _ = c.ImGui_ImplVulkan_DestroyFontUploadObjects();

        self.logger.info("ImGui initialized successfully", .{});
        return self;
    }

    // Begin ImGui frame
    pub fn beginFrame(self: *Self) void {
        _ = c.ImGui_ImplVulkan_NewFrame();
        _ = c.ImGui_ImplGlfw_NewFrame();
        c.igNewFrame();
    }

    // End ImGui frame and render
    pub fn endFrame(self: *Self, command_buffer: vk.VkCommandBuffer) void {
        c.igRender();
        const draw_data = c.igGetDrawData();
        _ = c.ImGui_ImplVulkan_RenderDrawData(draw_data, command_buffer);
    }

    // Cleanup ImGui resources
    pub fn deinit(self: *Self, device: vk.VkDevice) void {
        _ = c.ImGui_ImplVulkan_Shutdown();
        _ = c.ImGui_ImplGlfw_Shutdown();
        c.igDestroyContext(null);

        vk.vkDestroyDescriptorPool(device, self.descriptor_pool, null);
        vk.vkDestroyRenderPass(device, self.render_pass, null);
        vk.vkDestroyPipeline(device, self.pipeline, null);
        vk.vkDestroyPipelineLayout(device, self.pipeline_layout, null);
        vk.vkDestroySampler(device, self.font_sampler, null);
        vk.vkDestroyImageView(device, self.font_image_view, null);
        vk.vkDestroyImage(device, self.font_image, null);
        vk.vkFreeMemory(device, self.font_memory, null);
        vk.vkDestroyBuffer(device, self.vertex_buffer, null);
        vk.vkFreeMemory(device, self.vertex_buffer_memory, null);
        vk.vkDestroyBuffer(device, self.index_buffer, null);
        vk.vkFreeMemory(device, self.index_buffer_memory, null);

        self.allocator.destroy(self);
    }
}; 