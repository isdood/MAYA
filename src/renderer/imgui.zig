
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
const Window = opaque {};
const VulkanRenderer = @import("vulkan.zig").VulkanRenderer;

pub const ImGuiStyle = struct {
    colors: struct {
        text: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
        text_disabled: [4]f32 = .{ 0.5, 0.5, 0.5, 1.0 },
        window_bg: [4]f32 = .{ 0.06, 0.06, 0.06, 0.94 },
        child_bg: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
        popup_bg: [4]f32 = .{ 0.08, 0.08, 0.08, 0.94 },
        border: [4]f32 = .{ 0.43, 0.43, 0.50, 0.50 },
        border_shadow: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
        frame_bg: [4]f32 = .{ 0.16, 0.29, 0.48, 0.54 },
        frame_bg_hovered: [4]f32 = .{ 0.26, 0.59, 0.98, 0.40 },
        frame_bg_active: [4]f32 = .{ 0.26, 0.59, 0.98, 0.67 },
        title_bg: [4]f32 = .{ 0.04, 0.04, 0.04, 1.00 },
        title_bg_active: [4]f32 = .{ 0.16, 0.29, 0.48, 1.00 },
        title_bg_collapsed: [4]f32 = .{ 0.0, 0.0, 0.0, 0.51 },
        menu_bar_bg: [4]f32 = .{ 0.14, 0.14, 0.14, 1.00 },
        scrollbar_bg: [4]f32 = .{ 0.02, 0.02, 0.02, 0.53 },
        scrollbar_grab: [4]f32 = .{ 0.31, 0.31, 0.31, 1.00 },
        scrollbar_grab_hovered: [4]f32 = .{ 0.41, 0.41, 0.41, 1.00 },
        scrollbar_grab_active: [4]f32 = .{ 0.51, 0.51, 0.51, 1.00 },
        check_mark: [4]f32 = .{ 0.26, 0.59, 0.98, 1.00 },
        slider_grab: [4]f32 = .{ 0.24, 0.52, 0.88, 1.00 },
        slider_grab_active: [4]f32 = .{ 0.26, 0.59, 0.98, 1.00 },
        button: [4]f32 = .{ 0.26, 0.59, 0.98, 0.40 },
        button_hovered: [4]f32 = .{ 0.26, 0.59, 0.98, 0.67 },
        button_active: [4]f32 = .{ 0.06, 0.53, 0.98, 1.00 },
        header: [4]f32 = .{ 0.26, 0.59, 0.98, 0.31 },
        header_hovered: [4]f32 = .{ 0.26, 0.59, 0.98, 0.80 },
        header_active: [4]f32 = .{ 0.26, 0.59, 0.98, 1.00 },
        separator: [4]f32 = .{ 0.43, 0.43, 0.50, 0.50 },
        separator_hovered: [4]f32 = .{ 0.41, 0.42, 0.44, 1.00 },
        separator_active: [4]f32 = .{ 0.26, 0.59, 0.98, 1.00 },
        resize_grip: [4]f32 = .{ 0.26, 0.59, 0.98, 0.20 },
        resize_grip_hovered: [4]f32 = .{ 0.26, 0.59, 0.98, 0.67 },
        resize_grip_active: [4]f32 = .{ 0.26, 0.59, 0.98, 1.00 },
        tab: [4]f32 = .{ 0.18, 0.35, 0.58, 0.86 },
        tab_hovered: [4]f32 = .{ 0.26, 0.59, 0.98, 0.80 },
        tab_active: [4]f32 = .{ 0.20, 0.41, 0.68, 1.00 },
        tab_unfocused: [4]f32 = .{ 0.07, 0.10, 0.15, 0.97 },
        tab_unfocused_active: [4]f32 = .{ 0.14, 0.26, 0.42, 1.00 },
        plot_lines: [4]f32 = .{ 0.61, 0.61, 0.61, 1.00 },
        plot_lines_hovered: [4]f32 = .{ 1.00, 0.43, 0.35, 1.00 },
        plot_histogram: [4]f32 = .{ 0.90, 0.70, 0.00, 1.00 },
        plot_histogram_hovered: [4]f32 = .{ 1.00, 0.60, 0.00, 1.00 },
        text_selected_bg: [4]f32 = .{ 0.26, 0.59, 0.98, 0.35 },
        drag_drop_target: [4]f32 = .{ 1.00, 1.00, 0.00, 0.90 },
        nav_highlight: [4]f32 = .{ 0.26, 0.59, 0.98, 1.00 },
        nav_windowing_highlight: [4]f32 = .{ 1.00, 1.00, 1.00, 0.70 },
        nav_windowing_dim_bg: [4]f32 = .{ 0.80, 0.80, 0.80, 0.20 },
        modal_window_dim_bg: [4]f32 = .{ 0.80, 0.80, 0.80, 0.35 },
    },
    spacing: f32 = 8.0,
    window_padding: [2]f32 = .{ 8.0, 8.0 },
    window_rounding: f32 = 0.0,
    window_border_size: f32 = 1.0,
    window_min_size: [2]f32 = .{ 32.0, 32.0 },
    window_title_align: [2]f32 = .{ 0.0, 0.5 },
    child_rounding: f32 = 0.0,
    child_border_size: f32 = 1.0,
    popup_rounding: f32 = 0.0,
    popup_border_size: f32 = 1.0,
    frame_padding: [2]f32 = .{ 4.0, 3.0 },
    frame_rounding: f32 = 0.0,
    frame_border_size: f32 = 0.0,
    item_spacing: [2]f32 = .{ 8.0, 4.0 },
    item_inner_spacing: [2]f32 = .{ 4.0, 4.0 },
    indent_spacing: f32 = 21.0,
    columns_min_spacing: f32 = 6.0,
    scrollbar_size: f32 = 14.0,
    scrollbar_rounding: f32 = 9.0,
    grab_min_size: f32 = 10.0,
    grab_rounding: f32 = 0.0,
    tab_rounding: f32 = 4.0,
    tab_border_size: f32 = 0.0,
    button_text_align: [2]f32 = .{ 0.5, 0.5 },
    selectable_text_align: [2]f32 = .{ 0.0, 0.0 },
    display_window_padding: [2]f32 = .{ 19.0, 19.0 },
    display_safe_area_padding: [2]f32 = .{ 3.0, 3.0 },
    mouse_cursor_scale: f32 = 1.0,
    anti_aliased_lines: bool = true,
    anti_aliased_fill: bool = true,
    curve_tessellation_tol: f32 = 1.25,
    circle_segment_max_error: f32 = 1.60,
};

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

    style: ImGuiStyle,
    widgets: std.ArrayList(Widget),

    // Initialize ImGui with Vulkan
    pub fn init(renderer: *VulkanRenderer, window: *Window, allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
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
            .allocator = allocator,
            .logger = std.log.scoped(.imgui),
            .style = ImGuiStyle{},
            .widgets = std.ArrayList(Widget).init(allocator),
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

        // Apply custom style
        self.applyStyle();

        self.logger.info("ImGui initialized successfully", .{});
        return self;
    }

    // Begin ImGui frame
    pub fn beginFrame(_self: *Self) void {
        _ = c.ImGui_ImplVulkan_NewFrame();
        _ = c.ImGui_ImplGlfw_NewFrame();
        c.igNewFrame();
    }

    // End ImGui frame and render
    pub fn endFrame(_self: *Self, _command_buffer: vk.VkCommandBuffer) void {
        c.igRender();
        const draw_data = c.igGetDrawData();
        _ = c.ImGui_ImplVulkan_RenderDrawData(draw_data, _command_buffer);
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

        self.widgets.deinit();
        self.allocator.destroy(self);
    }

    fn applyStyle(self: *Self) void {
        const style = c.igGetStyle();
        
        // Apply colors
        for (self.style.colors, 0..) |color, i| {
            style.*.Colors[i] = c.ImVec4{ .x = color[0], .y = color[1], .z = color[2], .w = color[3] };
        }

        // Apply other style properties
        style.*.Spacing = self.style.spacing;
        style.*.WindowPadding = c.ImVec2{ .x = self.style.window_padding[0], .y = self.style.window_padding[1] };
        style.*.WindowRounding = self.style.window_rounding;
        style.*.WindowBorderSize = self.style.window_border_size;
        style.*.WindowMinSize = c.ImVec2{ .x = self.style.window_min_size[0], .y = self.style.window_min_size[1] };
        style.*.WindowTitleAlign = c.ImVec2{ .x = self.style.window_title_align[0], .y = self.style.window_title_align[1] };
        // ... apply other style properties ...
    }

    pub fn addWidget(self: *Self, widget: Widget) !void {
        try self.widgets.append(widget);
    }

    pub fn render(self: *Self) !void {
        c.igNewFrame();
        c.ImGui_ImplVulkan_NewFrame();
        c.ImGui_ImplGlfw_NewFrame();

        // Render all widgets
        for (self.widgets.items) |*widget| {
            try widget.render();
        }

        c.igRender();
    }
};

pub const Widget = struct {
    const Self = @This();

    id: []const u8,
    position: [2]f32,
    size: [2]f32,
    visible: bool,
    render_fn: *const fn (*Self) anyerror!void,

    pub fn init(id: []const u8, position: [2]f32, size: [2]f32, render_fn: *const fn (*Self) anyerror!void) Self {
        return Self{
            .id = id,
            .position = position,
            .size = size,
            .visible = true,
            .render_fn = render_fn,
        };
    }

    pub fn render(self: *Self) !void {
        if (!self.visible) return;

        c.igSetNextWindowPos(c.ImVec2{ .x = self.position[0], .y = self.position[1] }, c.ImGuiCond_FirstUseEver, c.ImVec2{ .x = 0, .y = 0 });
        c.igSetNextWindowSize(c.ImVec2{ .x = self.size[0], .y = self.size[1] }, c.ImGuiCond_FirstUseEver);

        if (c.igBegin(self.id.ptr, null, c.ImGuiWindowFlags_None)) {
            try self.render_fn(self);
        }
        c.igEnd();
    }
}; 
