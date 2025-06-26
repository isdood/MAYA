const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

const VulkanError = error{
    InitializationFailed,
    NoSuitableDevice,
    NoComputeQueue,
    OutOfMemory,
    ShaderCompilationFailed,
    InvalidOperation,
};

pub const VulkanContext = struct {
    allocator: Allocator,
    instance: c.VkInstance,
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    queue: c.VkQueue,
    queue_family_index: u32,
    command_pool: c.VkCommandPool,
    pipeline_cache: c.VkPipelineCache,
    debug_messenger: c.VkDebugUtilsMessengerEXT,

    pub fn init(allocator: Allocator) VulkanError!VulkanContext {
        var self: VulkanContext = undefined;
        self.allocator = allocator;

        // Initialize Vulkan instance
        try self.initVulkan();
        
        // Pick physical device
        try self.pickPhysicalDevice();
        
        // Create logical device
        try self.createLogicalDevice();
        
        // Create command pool
        try self.createCommandPool();
        
        return self;
    }
    
    pub fn deinit(self: *VulkanContext) void {
        if (self.device != null) {
            if (self.command_pool != null) {
                c.vkDestroyCommandPool(self.device, self.command_pool, null);
            }
            if (self.pipeline_cache != null) {
                c.vkDestroyPipelineCache(self.device, self.pipeline_cache, null);
            }
            c.vkDestroyDevice(self.device, null);
        }
        
        if (self.instance != null) {
            const destroyDebugUtilsMessengerEXT = @ptrCast(
                c.PFN_vkDestroyDebugUtilsMessengerEXT,
                c.vkGetInstanceProcAddr(self.instance, "vkDestroyDebugUtilsMessengerEXT")
            );
            
            if (destroyDebugUtilsMessengerEXT) |func| {
                func(self.instance, self.debug_messenger, null);
            }
            
            c.vkDestroyInstance(self.instance, null);
        }
    }
    
    fn initVulkan(self: *VulkanContext) VulkanError!void {
        const app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "MAYA Vulkan Compute",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_2,
        };
        
        const enabled_extensions = [_][*:0]const u8{"VK_KHR_get_physical_device_properties2"};
        
        const create_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @intCast(u32, enabled_extensions.len),
            .ppEnabledExtensionNames = &enabled_extensions[0],
        };
        
        if (c.vkCreateInstance(&create_info, null, &self.instance) != c.VK_SUCCESS) {
            return VulkanError.InitializationFailed;
        }
    }
    
    fn pickPhysicalDevice(self: *VulkanContext) VulkanError!void {
        var device_count: u32 = 0;
        _ = c.vkEnumeratePhysicalDevices(self.instance, &device_count, null);
        
        if (device_count == 0) {
            return VulkanError.NoSuitableDevice;
        }
        
        // Just pick the first device for now
        _ = c.vkEnumeratePhysicalDevices(self.instance, &device_count, &self.physical_device);
        
        if (self.physical_device == null) {
            return VulkanError.NoSuitableDevice;
        }
        
        // Find queue family with compute support
        var queue_family_count: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, null);
        
        const queue_families = try self.allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
        defer self.allocator.free(queue_families);
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, queue_families.ptr);
        
        self.queue_family_index = std.math.maxInt(u32);
        for (queue_families) |queue_family, i| {
            if ((queue_family.queueFlags & c.VK_QUEUE_COMPUTE_BIT) != 0) {
                self.queue_family_index = @intCast(u32, i);
                break;
            }
        }
        
        if (self.queue_family_index == std.math.maxInt(u32)) {
            return VulkanError.NoComputeQueue;
        }
    }
    
    fn createLogicalDevice(self: *VulkanContext) VulkanError!void {
        const queue_priority: f32 = 1.0;
        const queue_create_info = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = self.queue_family_index,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };
        
        const device_features = std.mem.zeroes(c.VkPhysicalDeviceFeatures);
        
        const create_info = c.VkDeviceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
            .pEnabledFeatures = &device_features,
        };
        
        if (c.vkCreateDevice(self.physical_device, &create_info, null, &self.device) != c.VK_SUCCESS) {
            return VulkanError.InitializationFailed;
        }
        
        // Get the queue
        c.vkGetDeviceQueue(self.device, self.queue_family_index, 0, &self.queue);
    }
    
    fn createCommandPool(self: *VulkanContext) VulkanError!void {
        const create_info = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = self.queue_family_index,
        };
        
        if (c.vkCreateCommandPool(self.device, &create_info, null, &self.command_pool) != c.VK_SUCCESS) {
            return VulkanError.InitializationFailed;
        }
    }
    
    pub fn createBuffer(self: *const VulkanContext, size: usize, usage: c.VkBufferUsageFlags) VulkanError!c.VkBuffer {
        const buffer_info = c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = @intCast(u64, size),
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 1,
            .pQueueFamilyIndices = &self.queue_family_index,
        };
        
        var buffer: c.VkBuffer = undefined;
        if (c.vkCreateBuffer(self.device, &buffer_info, null, &buffer) != c.VK_SUCCESS) {
            return VulkanError.OutOfMemory;
        }
        
        return buffer;
    }
    
    pub fn allocateMemory(self: *const VulkanContext, requirements: c.VkMemoryRequirements, properties: c.VkMemoryPropertyFlags) VulkanError!c.VkDeviceMemory {
        var memory_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &memory_properties);
        
        var memory_type_index = std.math.maxInt(u32);
        for (memory_properties.memoryTypes[0..memory_properties.memoryTypeCount]) |memory_type, i| {
            if ((requirements.memoryTypeBits & (@as(u32, 1) << @intCast(u5, i))) != 0 and
                (memory_type.propertyFlags & properties) == properties) {
                memory_type_index = @intCast(u32, i);
                break;
            }
        }
        
        if (memory_type_index == std.math.maxInt(u32)) {
            return VulkanError.OutOfMemory;
        }
        
        const allocate_info = c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = requirements.size,
            .memoryTypeIndex = memory_type_index,
        };
        
        var memory: c.VkDeviceMemory = undefined;
        if (c.vkAllocateMemory(self.device, &allocate_info, null, &memory) != c.VK_SUCCESS) {
            return VulkanError.OutOfMemory;
        }
        
        return memory;
    }
}
