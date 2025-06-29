const std = @import("std");
const VulkanContext = @import("vulkan_context").VulkanContext;

pub fn main() !void {
    // Initialize the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Starting Vulkan Test ===\n", .{});
    
    // Create and initialize Vulkan context
    var vulkan = try VulkanContext.init(allocator);
    defer vulkan.deinit();
    
    std.debug.print("\n=== Vulkan Test Completed Successfully ===\n", .{});
}
