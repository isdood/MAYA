// tests/vulkan_init_test.zig
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Import Vulkan bindings and modules
const vk = @import("vulkan");
const Context = @import("vulkan/context").VulkanContext;

test "vulkan initialization" {
    // Initialize Vulkan context
    var context = try Context.init();
    defer context.deinit();

    // Verify context was initialized correctly
    try testing.expect(context.instance != null);
    try testing.expect(context.physical_device != null);
    try testing.expect(context.device != null);
    try testing.expect(context.compute_queue != null);
    try testing.expect(context.command_pool != null);
    try testing.expect(context.pipeline_cache != null);

    // Print some device information if needed
    if (context.physical_device) |physical_device| {
        var properties: vk.VkPhysicalDeviceProperties = undefined;
        vk.vkGetPhysicalDeviceProperties(physical_device, &properties);
        std.debug.print("Testing on device: {s}\n", .{properties.deviceName});
    }
}
