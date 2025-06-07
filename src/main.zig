const std = @import("std");
const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const colors = @import("glimmer/colors.zig").GlimmerColors;
const renderer = @import("renderer/vulkan.zig");

const Window = struct {
    handle: ?*glfw.GLFWwindow,
    width: u32,
    height: u32,
    title: []const u8,
    color_scheme: colors.ColorScheme,
    vulkan_renderer: ?renderer.VulkanRenderer,

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
        };

        // Initialize Vulkan renderer
        window.vulkan_renderer = try renderer.VulkanRenderer.init(handle);

        return window;
    }

    pub fn deinit(self: *Window) void {
        if (self.vulkan_renderer) |*vulkan_renderer| {
            vulkan_renderer.deinit();
        }
        if (self.handle) |handle| {
            glfw.glfwDestroyWindow(handle);
        }
        glfw.glfwTerminate();
    }

    pub fn shouldClose(self: *Window) bool {
        return glfw.glfwWindowShouldClose(self.handle) != 0;
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
        if (self.vulkan_renderer) |*vulkan_renderer| {
            try vulkan_renderer.drawFrame();
        }
    }
};

pub fn main() !void {
    // Initialize window
    var window = try Window.init(1280, 720, "MAYA");
    defer window.deinit();

    // Main loop
    while (!window.shouldClose()) {
        Window.pollEvents();
        try window.drawFrame();
    }
} 