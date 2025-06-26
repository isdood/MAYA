// Common Vulkan types and imports
const std = @import("std");
const c = @cImport({
    @cDefine("VK_USE_PLATFORM_XCB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});

// Re-export all Vulkan types and functions
pub usingnamespace c;

// Debug callback type
export fn debugCallback(
    message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_types: c.VkDebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(.C) c.VkBool32 {
    _ = message_types;
    _ = p_user_data;
    
    const severity = if ((message_severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) != 0) "ERROR"
                   else if ((message_severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) != 0) "WARNING"
                   else if ((message_severity & c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT) != 0) "INFO"
                   else "VERBOSE";
    
    if (p_callback_data) |data| {
        std.debug.print("[vulkan {}] {s}\n", .{severity, data.pMessage});
    }
    
    return c.VK_FALSE;
}

// Function pointer types
pub const PFN_vkCreateDebugUtilsMessengerEXT = ?fn (
    c.VkInstance,
    *const c.VkDebugUtilsMessengerCreateInfoEXT,
    ?*const c.VkAllocationCallbacks,
    *c.VkDebugUtilsMessengerEXT,
) callconv(.C) c.VkResult;

pub const PFN_vkDestroyDebugUtilsMessengerEXT = ?fn (
    c.VkInstance,
    c.VkDebugUtilsMessengerEXT,
    ?*const c.VkAllocationCallbacks,
) callconv(.C) void;

// Wrapper for vkGetInstanceProcAddr that handles the pointer casting
export fn vkGetInstanceProcAddr(instance: c.VkInstance, pName: [*:0]const u8) ?*const fn () callconv(.C) void {
    return c.vkGetInstanceProcAddr(instance, pName);
}

// Helper to load debug utils function pointers
pub fn loadDebugUtilsFunctions(instance: c.VkInstance) struct {
    createDebugUtilsMessengerEXT: PFN_vkCreateDebugUtilsMessengerEXT,
    destroyDebugUtilsMessengerEXT: PFN_vkDestroyDebugUtilsMessengerEXT,
} {
    const create_fn = c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT");
    const destroy_fn = c.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT");
    
    if (create_fn == null or destroy_fn == null) {
        @panic("Failed to load debug utils functions");
    }
    
    return .{
        .createDebugUtilsMessengerEXT = @ptrCast(create_fn),
        .destroyDebugUtilsMessengerEXT = @ptrCast(destroy_fn),
    };
}

// Common Vulkan error handling
pub const VulkanError = error {
    InitializationFailed,
    NoSuitableDevice,
    NoComputeQueue,
    DeviceCreationFailed,
    CommandPoolCreationFailed,
    InvalidOperation,
};
