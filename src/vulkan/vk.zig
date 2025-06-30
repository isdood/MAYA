// Common Vulkan types and imports
const std = @import("std");

/// Helper function to check Vulkan result codes and return appropriate errors
pub fn checkSuccess(result: c.VkResult, error_enum: anyerror) !void {
    if (result != c.VK_SUCCESS) {
        std.log.err("Vulkan error: {}", .{result});
        return error_enum;
    }
}

// Import Vulkan with proper platform defines
const c = @cImport({
    @cDefine("VK_USE_PLATFORM_XLIB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});

// Re-export all Vulkan types and functions
pub usingnamespace c;

// Export the Vulkan functions we need
export fn vkEnumerateInstanceExtensionProperties(
    pLayerName: ?[*:0]const u8,
    pPropertyCount: *u32,
    pProperties: ?[*]c.VkExtensionProperties,
) callconv(.C) c.VkResult {
    return c.vkEnumerateInstanceExtensionProperties(pLayerName, pPropertyCount, pProperties);
}

export fn vkEnumerateInstanceLayerProperties(
    pPropertyCount: *u32,
    pProperties: ?[*]c.VkLayerProperties,
) callconv(.C) c.VkResult {
    return c.vkEnumerateInstanceLayerProperties(pPropertyCount, pProperties);
}

export fn vkEnumerateInstanceVersion(
    pApiVersion: *u32,
) callconv(.C) c.VkResult {
    return c.vkEnumerateInstanceVersion(pApiVersion);
}

export fn vkCreateInstance(
    pCreateInfo: *const c.VkInstanceCreateInfo,
    pAllocator: ?*const c.VkAllocationCallbacks,
    pInstance: *c.VkInstance,
) callconv(.C) c.VkResult {
    return c.vkCreateInstance(pCreateInfo, pAllocator, pInstance);
}

export fn vkGetInstanceProcAddr(
    instance: c.VkInstance,
    pName: [*:0]const u8,
) callconv(.C) ?*const anyopaque {
    return c.vkGetInstanceProcAddr(instance, pName);
}

// Debug utilities instance functions
pub const DebugUtils = struct {
    instance: c.VkInstance,
    
    // Function to create debug utils messenger
    pub fn createDebugUtilsMessengerEXT(
        self: @This(),
        pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT,
        pAllocator: ?*const c.VkAllocationCallbacks,
        pMessenger: *c.VkDebugUtilsMessengerEXT,
    ) c.VkResult {
        // Get the function pointer
        const func_ptr = c.vkGetInstanceProcAddr(self.instance, "vkCreateDebugUtilsMessengerEXT");
        if (func_ptr == null) return c.VK_ERROR_EXTENSION_NOT_PRESENT;
        
        // Define the function type
        const PFN_vkCreateDebugUtilsMessengerEXT = *const fn(
            c.VkInstance,
            *const c.VkDebugUtilsMessengerCreateInfoEXT,
            ?*const c.VkAllocationCallbacks,
            *c.VkDebugUtilsMessengerEXT,
        ) callconv(.C) c.VkResult;
        
        // Cast and call the function
        const func: PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(func_ptr);
        return func(
            self.instance,
            pCreateInfo,
            pAllocator,
            pMessenger
        );
    }

    // Function to destroy debug utils messenger
    pub fn destroyDebugUtilsMessengerEXT(
        self: @This(),
        messenger: c.VkDebugUtilsMessengerEXT,
        pAllocator: ?*const c.VkAllocationCallbacks,
    ) void {
        // Get the function pointer
        const func_ptr = c.vkGetInstanceProcAddr(self.instance, "vkDestroyDebugUtilsMessengerEXT");
        if (func_ptr) |ptr| {
            // Define the function type
            const PFN_vkDestroyDebugUtilsMessengerEXT = *const fn(
                c.VkInstance,
                c.VkDebugUtilsMessengerEXT,
                ?*const c.VkAllocationCallbacks,
            ) callconv(.C) void;
            
            // Cast and call the function
            const func: PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(ptr);
            func(
                self.instance,
                messenger,
                pAllocator
            );
        }
    }
};

// Function to load instance-level debug functions
pub fn loadDebugUtils(instance: c.VkInstance) DebugUtils {
    return DebugUtils{ .instance = instance };
}

// Debug callback function type
pub const PFN_vkDebugUtilsMessengerCallbackEXT = fn(
    messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageTypes: c.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: *const c.VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: ?*anyopaque,
) callconv(.C) c.VkBool32;

// Debug callback implementation
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
        std.debug.print("[vulkan {s}] {s}\n", .{severity, data.pMessage});
    }
    
    return c.VK_FALSE;
}

// Function pointer types for debug utils
extern fn vkCreateDebugUtilsMessengerEXT(
    instance: c.VkInstance,
    pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT,
    pAllocator: ?*const c.VkAllocationCallbacks,
    pMessenger: *c.VkDebugUtilsMessengerEXT,
) callconv(.C) c.VkResult;

extern fn vkDestroyDebugUtilsMessengerEXT(
    instance: c.VkInstance,
    messenger: c.VkDebugUtilsMessengerEXT,
    pAllocator: ?*const c.VkAllocationCallbacks,
) callconv(.C) void;

// Helper to load debug utils function pointers
pub const DebugUtilsFunctions = struct {
    createDebugUtilsMessengerEXT: *const fn(
        c.VkInstance,
        *const c.VkDebugUtilsMessengerCreateInfoEXT,
        ?*const c.VkAllocationCallbacks,
        *c.VkDebugUtilsMessengerEXT,
    ) callconv(.C) c.VkResult,
    
    destroyDebugUtilsMessengerEXT: *const fn(
        c.VkInstance,
        c.VkDebugUtilsMessengerEXT,
        ?*const c.VkAllocationCallbacks,
    ) callconv(.C) void,
};

pub fn loadDebugUtilsFunctions(instance: c.VkInstance) DebugUtilsFunctions {
    return .{
        .createDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT") orelse @panic("Failed to load vkCreateDebugUtilsMessengerEXT")),
        .destroyDebugUtilsMessengerEXT = @ptrCast(c.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT") orelse @panic("Failed to load vkDestroyDebugUtilsMessengerEXT")),
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
