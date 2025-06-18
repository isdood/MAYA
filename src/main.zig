const std = @import("std");
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});
const vk = @cImport({
    @cDefine("VK_USE_PLATFORM_XCB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});
const colors = @import("glimmer/colors.zig").GlimmerColors;
const renderer = @import("renderer/vulkan.zig");
const ui_renderer = @import("renderer/ui_renderer.zig");
const layout = @import("renderer/layout.zig");
const widgets = @import("renderer/widgets.zig");
const os = std.os;
const linux = os.linux;

var g_window: ?*Window = null;

const Window = struct {
    handle: ?*glfw.GLFWwindow,
    width: u32,
    height: u32,
    title: []const u8,
    color_scheme: colors.ColorScheme,
    vulkan_renderer: ?renderer.VulkanRenderer,
    ui_renderer: ?ui_renderer.UIRenderer,
    should_close: bool,
    framebuffer_resized: bool,

    pub fn init(width: u32, height: u32, title: []const u8) !Window {
        if (glfw.glfwInit() == 0) {
            return error.GLFWInitFailed;
        }

        // Set GLFW window hints for Vulkan
        glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
        glfw.glfwWindowHint(glfw.GLFW_RESIZABLE, glfw.GLFW_TRUE);

        const handle = glfw.glfwCreateWindow(
            @intCast(width),
            @intCast(height),
            title.ptr,
            null,
            null,
        ) orelse {
            glfw.glfwTerminate();
            return error.WindowCreationFailed;
        };

        var window = Window{
            .handle = handle,
            .width = width,
            .height = height,
            .title = title,
            .color_scheme = colors.ColorScheme.dark(),
            .vulkan_renderer = null,
            .ui_renderer = null,
            .should_close = false,
            .framebuffer_resized = false,
        };

        // Set window callbacks
        if (glfw.glfwSetWindowCloseCallback(handle, windowCloseCallback)) |prev_callback| {
            _ = prev_callback; // Ignore previous callback
        }
        if (glfw.glfwSetFramebufferSizeCallback(handle, framebufferResizeCallback)) |prev_callback| {
            _ = prev_callback; // Ignore previous callback
        }

        // Initialize Vulkan renderer
        window.vulkan_renderer = try renderer.VulkanRenderer.init(handle);

        // Initialize UI renderer with default theme
        const default_theme = layout.ResizeHandleTheme.init();
        window.ui_renderer = try ui_renderer.UIRenderer.init(
            window.vulkan_renderer.?,
            default_theme,
        );

        // Create example layout
        const example_layout = try layout.Layout.init(
            "example_layout",
            .{ 0, 0 },
            .{ @floatFromInt(width), @floatFromInt(height) },
        );
        try window.ui_renderer.?.addLayout(example_layout);

        return window;
    }

    pub fn deinit(self: *Window) void {
        if (self.ui_renderer) |*ui_renderer_| {
            ui_renderer_.deinit();
        }
        if (self.vulkan_renderer) |*vulkan_renderer| {
            vulkan_renderer.deinit();
        }
        if (self.handle) |handle| {
            glfw.glfwDestroyWindow(handle);
        }
        glfw.glfwTerminate();
    }

    pub fn shouldClose(self: *Window) bool {
        return self.should_close or glfw.glfwWindowShouldClose(self.handle) != 0;
    }

    pub fn pollEvents() void {
        glfw.glfwPollEvents();
    }

    pub fn getFramebufferSize(self: *Window) struct { width: u32, height: u32 } {
        var width: i32 = undefined;
        var height: i32 = undefined;
        glfw.glfwGetFramebufferSize(self.handle, &width, &height);
        return .{
            .width = @intCast(width),
            .height = @intCast(height),
        };
    }

    pub fn drawFrame(self: *Window) !void {
        if (self.ui_renderer) |*ui_renderer_| {
            try ui_renderer_.render();
        }
    }
};

fn windowCloseCallback(window: ?*glfw.GLFWwindow) callconv(.C) void {
    if (window) |w| {
        const user_ptr = glfw.glfwGetWindowUserPointer(w);
        if (user_ptr) |ptr| {
            const win = @as(*Window, @ptrCast(@alignCast(ptr)));
            win.should_close = true;
        }
    }
}

fn framebufferResizeCallback(window: ?*glfw.GLFWwindow, _width: i32, _height: i32) callconv(.C) void {
    _ = _width; // Silence unused parameter warning
    _ = _height; // Silence unused parameter warning
    if (window) |w| {
        const user_ptr = glfw.glfwGetWindowUserPointer(w);
        if (user_ptr) |ptr| {
            const win = @as(*Window, @ptrCast(@alignCast(ptr)));
            win.framebuffer_resized = true;
        }
    }
}

fn signalHandler(sig: c_int) callconv(.C) void {
    _ = sig; // Silence unused parameter warning
    if (g_window) |window| {
        window.should_close = true;
    }
}

pub fn main() !void {
    // Set up signal handler
    var act = linux.Sigaction{
        .handler = .{ .handler = signalHandler },
        .mask = linux.empty_sigset,
        .flags = 0,
        .restorer = null,
    };
    _ = linux.sigaction(15, &act, null); // 15 is SIGTERM

    // Initialize window
    var window = try Window.init(1280, 720, "MAYA");
    defer window.deinit();

    // Set global window pointer for signal handler
    g_window = &window;

    // Set window user pointer for callbacks
    if (window.handle) |handle| {
        glfw.glfwSetWindowUserPointer(handle, &window);
    }

    // Main loop
    const target_frame_time = 16 * std.time.ns_per_ms; // ~60 FPS
    var last_frame_time = std.time.milliTimestamp();

    while (!window.shouldClose()) {
        const current_time = std.time.milliTimestamp();
        const elapsed = current_time - last_frame_time;

        if (elapsed < target_frame_time) {
            const sleep_time = @as(u64, @intCast(target_frame_time - elapsed));
            std.time.sleep(sleep_time);
        }

        Window.pollEvents();
        try window.drawFrame();

        last_frame_time = current_time;
    }

    // Clear global window pointer
    g_window = null;
} 