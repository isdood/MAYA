const std = @import("std");
const VulkanContext = @import("context.zig").VulkanContext;

pub fn main() !void {
    // Initialize the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Starting Vulkan Context Test ===\n", .{});
    
    // Initialize Vulkan context
    std.debug.print("Initializing Vulkan context...\n", .{});
    var vulkan_context = try VulkanContext.init(allocator);
    defer vulkan_context.deinit();
    
    std.debug.print("\n=== Vulkan Context Test Passed Successfully! ===\n", .{});
}
