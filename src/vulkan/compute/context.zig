// src/vulkan/compute/context.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

// Import the vk module that was provided by the build system
const vk = @import("vk");

pub const VulkanError = error {
    InitializationFailed,
    NoPhysicalDevicesFound,
    NoSuitableDevice,
    DeviceCreationFailed,
    QueueCreationFailed,
    CommandPoolCreationFailed,
    PipelineCacheCreationFailed,
    DebugUtilsMessengerCreationFailed,
};

pub const VulkanContext = struct {
    instance: ?vk.VkInstance,
    physical_device: ?vk.VkPhysicalDevice,
    device: ?vk.VkDevice,
    compute_queue: ?vk.VkQueue,
    command_pool: ?vk.VkCommandPool,
    pipeline_cache: ?vk.VkPipelineCache,
    debug_messenger: ?vk.VkDebugUtilsMessengerEXT,

    pub fn init() !VulkanContext {
        var self = VulkanContext{
            .instance = null,
            .physical_device = null,
            .device = null,
            .compute_queue = null,
            .command_pool = null,
            .pipeline_cache = null,
            .debug_messenger = null,
        };
        try self.initVulkan();
        return self;
    }

    fn initVulkan(self: *VulkanContext) !void {
        std.debug.print("Initializing Vulkan...\n", .{});

        // Check Vulkan version
        var instance_version: u32 = 0;
        const version_result = vk.vkEnumerateInstanceVersion(&instance_version);
        if (version_result != vk.VK_SUCCESS) {
            std.debug.print("Failed to get Vulkan version: {}\n", .{version_result});
            return error.InitializationFailed;
        }

        const major = vk.VK_API_VERSION_MAJOR(instance_version);
        const minor = vk.VK_API_VERSION_MINOR(instance_version);
        const patch = vk.VK_API_VERSION_PATCH(instance_version);
        std.debug.print("Vulkan {}.{}.{} detected\n", .{ major, minor, patch });

        // Create Vulkan instance
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "MAYA",
            .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "MAYA Engine",
            .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
        };

        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
        };

        var instance: vk.VkInstance = undefined;
        const create_result = vk.vkCreateInstance(&create_info, null, &instance);
        if (create_result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create Vulkan instance: {}\n", .{create_result});
            return error.InitializationFailed;
        }

        self.instance = instance;
        std.debug.print("Vulkan instance created successfully\n", .{});
    }
    
    pub fn deinit(self: *VulkanContext) void {
        if (self.instance) |instance| {
            // Clean up device resources first
            if (self.device) |device| {
                if (self.pipeline_cache) |pipeline_cache| {
                    vk.vkDestroyPipelineCache(device, pipeline_cache, null);
                }
                
                if (self.command_pool) |command_pool| {
                    vk.vkDestroyCommandPool(device, command_pool, null);
                }
                
                vk.vkDestroyDevice(device, null);
            }
            
            // Clean up debug messenger if it exists
            if (self.debug_messenger) |debug_messenger| {
                if (vk.vkDestroyDebugUtilsMessengerEXT) |destroyDebugUtilsMessengerEXT| {
                    destroyDebugUtilsMessengerEXT(instance, debug_messenger, null);
                }
            }
            
            // Finally destroy the instance
            vk.vkDestroyInstance(instance, null);
            self.instance = null;
            std.debug.print("Vulkan instance destroyed\n", .{});
        }
    }
};
