// src/vulkan/debug.zig
const std = @import("std");
const vk = @import("vk");

// Internal debug callback function
fn debugCallback(
    message_severity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_type: vk.VkDebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(.C) vk.VkBool32 {
    _ = message_type;
    _ = p_user_data;
    
    const message = if (p_callback_data) |data| 
        std.mem.span(@as([*:0]const u8, @ptrCast(data.pMessage))) 
    else 
        "<no message>";
    
    if (message_severity & vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT != 0) {
        std.debug.print("VULKAN VALIDATION ERROR: {s}\n", .{message});
    } else if (message_severity & vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT != 0) {
        std.debug.print("VULKAN VALIDATION WARNING: {s}\n", .{message});
    } else if (message_severity & vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT != 0) {
        std.debug.print("VULKAN VALIDATION INFO: {s}\n", .{message});
    } else if (message_severity & vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT != 0) {
        std.debug.print("VULKAN VALIDATION VERBOSE: {s}\n", .{message});
    }
    
    return vk.VK_FALSE;
}

// Public function to get the debug callback function pointer
pub fn getDebugCallback() *const fn (
    vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
    vk.VkDebugUtilsMessageTypeFlagsEXT,
    ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
    ?*anyopaque,
) callconv(.C) vk.VkBool32 {
    return debugCallback;
}
