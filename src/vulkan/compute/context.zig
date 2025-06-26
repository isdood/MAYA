// src/vulkan/compute/context.zig
const std = @import("std");
const c = @import("vk");

const Allocator = std.mem.Allocator;

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
    instance: ?c.VkInstance,
    physical_device: ?c.VkPhysicalDevice,
    device: ?c.VkDevice,
    compute_queue: ?c.VkQueue,
    command_pool: ?c.VkCommandPool,
    pipeline_cache: ?c.VkPipelineCache,
    debug_messenger: ?c.VkDebugUtilsMessengerEXT,

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
        const version_result = c.vkEnumerateInstanceVersion(&instance_version);
        if (version_result != c.VK_SUCCESS) {
            std.debug.print("Failed to get Vulkan version: {}\n", .{version_result});
            return error.InitializationFailed;
        }

        const major = c.VK_API_VERSION_MAJOR(instance_version);
        const minor = c.VK_API_VERSION_MINOR(instance_version);
        const patch = c.VK_API_VERSION_PATCH(instance_version);
        std.debug.print("Vulkan {}.{}.{} detected\n", .{ major, minor, patch });

        // Create Vulkan instance
        const app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "MAYA",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "MAYA Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_0,
        };

        const create_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
        };

        var instance: c.VkInstance = undefined;
        const create_result = c.vkCreateInstance(&create_info, null, &instance);
        if (create_result != c.VK_SUCCESS) {
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
                    c.vkDestroyPipelineCache(device, pipeline_cache, null);
                }
                
                if (self.command_pool) |command_pool| {
                    c.vkDestroyCommandPool(device, command_pool, null);
                }
                
                c.vkDestroyDevice(device, null);
            }
            
            // Clean up debug messenger if it exists
            if (self.debug_messenger) |debug_messenger| {
                const debug_utils = c.loadDebugUtils(self.instance);
                debug_utils.destroyDebugUtilsMessengerEXT(debug_messenger, null);
            }
            
            // Finally destroy the instance
            c.vkDestroyInstance(instance, null);
            self.instance = null;
            std.debug.print("Vulkan instance destroyed\n", .{});
        }
    }
};
