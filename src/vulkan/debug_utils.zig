const std = @import("std");
const vk = @import("vk.zig");

// Debug callback for Vulkan validation messages
export fn vkDebugCallback(
    messageSeverity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageType: vk.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: ?*anyopaque,
) callconv(.C) vk.VkBool32 {
    _ = messageType;
    _ = pUserData;
    
    // Skip verbose/info messages
    if (messageSeverity <= vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT) {
        return vk.VK_FALSE;
    }
    
    if (pCallbackData) |data| {
        const message = std.mem.span(data.pMessage);
        std.debug.print("Vulkan Validation: {s}\n", .{message});
    }
    
    return vk.VK_FALSE;
}

// Initialize debug messenger
export fn setupDebugMessenger(instance: vk.VkInstance) !void {
    const createInfo = vk.VkDebugUtilsMessengerCreateInfoEXT{
        .sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .pNext = null,
        .flags = 0,
        .messageSeverity = 
            vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = 
            vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = vkDebugCallback,
        .pUserData = null,
    };
    
    var messenger: vk.VkDebugUtilsMessengerEXT = undefined;
    const result = vk.vkCreateDebugUtilsMessengerEXT(instance, &createInfo, null, &messenger);
    if (result != vk.VK_SUCCESS) {
        std.debug.print("Failed to set up debug messenger: {}\n", .{result});
        return error.DebugMessengerSetupFailed;
    }
}
