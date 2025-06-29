const std = @import("std");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub fn main() !void {
    std.debug.print("Vulkan minimal test starting...\n", .{});
    
    // 1. Try to load the Vulkan loader
    std.debug.print("1. Attempting to load Vulkan loader...\n", .{});
    
    // 2. Get the instance extension count
    std.debug.print("2. Getting instance extension count...\n", .{});
    var extension_count: u32 = 0;
    const result = c.vkEnumerateInstanceExtensionProperties(null, &extension_count, null);
    
    std.debug.print("3. vkEnumerateInstanceExtensionProperties returned: {}\n", .{result});
    
    if (result != c.VK_SUCCESS and result != c.VK_INCOMPLETE) {
        std.debug.print("4. Failed to get instance extension count: {}\n", .{result});
        return error.VulkanError;
    }
    
    std.debug.print("4. Found {} instance extensions\n", .{extension_count});
    
    // 3. If we have extensions, try to list them
    if (extension_count > 0) {
        std.debug.print("5. Allocating memory for extension properties...\n", .{});
        const extensions = try std.heap.page_allocator.alloc(c.VkExtensionProperties, extension_count);
        defer std.heap.page_allocator.free(extensions);
        
        std.debug.print("6. Getting extension properties...\n", .{});
        const enum_result = c.vkEnumerateInstanceExtensionProperties(null, &extension_count, extensions.ptr);
        
        if (enum_result != c.VK_SUCCESS) {
            std.debug.print("7. Failed to enumerate instance extensions: {}\n", .{enum_result});
            return error.VulkanError;
        }
        
        std.debug.print("7. Successfully got {} extensions:\n", .{extension_count});
        for (extensions) |ext| {
            const name = std.mem.span(@as([*:0]const u8, @ptrCast(&ext.extensionName)));
            std.debug.print("  - {s} (spec version: {})\n", .{name, ext.specVersion});
        }
    }
    
    std.debug.print("8. Vulkan test completed successfully!\n", .{});
}
