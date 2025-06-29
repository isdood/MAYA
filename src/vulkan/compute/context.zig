// src/vulkan/compute/context.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

// Import Vulkan bindings using C import
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

// Alias the C Vulkan types for consistency
const vk = c;

pub const VulkanError = error {
    InitializationFailed,
    NoPhysicalDevicesFound,
    NoSuitableDevice,
    DeviceCreationFailed,
    QueueCreationFailed,
    CommandPoolCreationFailed,
    PipelineCacheCreationFailed,
    ExtensionNotPresent,
};

pub const VulkanContext = struct {
    instance: ?vk.VkInstance = null,
    physical_device: ?vk.VkPhysicalDevice = null,
    device: ?vk.VkDevice = null,
    compute_queue: ?vk.VkQueue = null,
    compute_queue_family_index: ?u32 = null,
    command_pool: ?vk.VkCommandPool = null,
    pipeline_cache: ?vk.VkPipelineCache = null,
    allocator: Allocator,
    
    /// Initialize a new Vulkan context with default settings
    pub fn init(allocator: Allocator) !VulkanContext {
        var self = VulkanContext{
            .allocator = allocator,
        };
        try self.initVulkan();
        return self;
    }
    
    /// Initialize Vulkan instance and device
    pub fn initVulkan(self: *VulkanContext) !void {
        std.debug.print("=== Starting Vulkan Initialization ===\n", .{});
        
        // 1. Create application info
        std.debug.print("1. Creating application info...\n", .{});
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "MAYA",
            .applicationVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
        };
        
        // 2. Create instance
        std.debug.print("2. Creating Vulkan instance...\n", .{});
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
        const result = vk.vkCreateInstance(&create_info, null, @ptrCast(&instance));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
            return VulkanError.InitializationFailed;
        }
        
        self.instance = instance;
        std.debug.print("3. Vulkan instance created successfully!\n", .{});
        
        // 3. Pick physical device
        std.debug.print("4. Picking physical device...\n", .{});
        try self.pickPhysicalDevice();
        
        // 4. Create logical device
        std.debug.print("5. Creating logical device...\n", .{});
        try self.createLogicalDevice();
        
        // 5. Create command pool
        std.debug.print("6. Creating command pool...\n", .{});
        try self.createCommandPool();
        
        std.debug.print("=== Vulkan initialization completed successfully ===\n\n", .{});
    }
    
    /// Pick a suitable physical device
    fn pickPhysicalDevice(self: *VulkanContext) !void {
        const instance = self.instance orelse return VulkanError.InitializationFailed;
        
        var device_count: u32 = 0;
        _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
        
        if (device_count == 0) {
            std.debug.print("No Vulkan devices found!\n", .{});
            return VulkanError.NoPhysicalDevicesFound;
        }
        
        const devices = try self.allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer self.allocator.free(devices);
        _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
        
        // Prefer discrete GPUs, fall back to any available device
        for (devices) |device| {
            var properties: vk.VkPhysicalDeviceProperties = undefined;
            vk.vkGetPhysicalDeviceProperties(device, &properties);
            
            std.debug.print("Found device: {} (Type: {})\n", .{
                std.mem.span(@ptrCast(&properties.deviceName)),
                @tagName(properties.deviceType),
            });
            
            // If we find a discrete GPU, use it
            if (properties.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
                self.physical_device = device;
                std.debug.print("Selected discrete GPU: {s}\n", .{std.mem.span(@ptrCast(&properties.deviceName))});
                return;
            }
        }
        
        // If no discrete GPU found, use the first available device
        if (devices.len > 0) {
            var properties: vk.VkPhysicalDeviceProperties = undefined;
            vk.vkGetPhysicalDeviceProperties(devices[0], &properties);
            self.physical_device = devices[0];
            std.debug.print("Selected device: {s}\n", .{std.mem.span(@ptrCast(&properties.deviceName))});
            return;
        }
        
        return VulkanError.NoSuitableDevice;
    }
    
    /// Create a logical device with a compute queue
    fn createLogicalDevice(self: *VulkanContext) !void {
        const physical_device = self.physical_device orelse return VulkanError.NoSuitableDevice;
        
        // Find a queue family that supports compute
        var queue_family_count: u32 = 0;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
        
        const queue_families = try self.allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer self.allocator.free(queue_families);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);
        
        // Find a queue family that supports compute
        var compute_queue_family_index: ?u32 = null;
        for (queue_families, 0..) |queue_family, i| {
            if ((queue_family.queueFlags & vk.VK_QUEUE_COMPUTE_BIT) != 0) {
                compute_queue_family_index = @intCast(i);
                break;
            }
        }
        
        if (compute_queue_family_index == null) {
            std.debug.print("No compute queue family found!\n", .{});
            return VulkanError.QueueCreationFailed;
        }
        
        self.compute_queue_family_index = compute_queue_family_index;
        
        // Configure queue creation
        const queue_priority = [_]f32{1.0};
        const queue_create_info = vk.VkDeviceQueueCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = compute_queue_family_index.?,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };
        
        // Enable required features
        const device_features = std.mem.zeroes(vk.VkPhysicalDeviceFeatures);
        
        // Create logical device
        const device_create_info = vk.VkDeviceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
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
        
        var device: vk.VkDevice = undefined;
        const result = vk.vkCreateDevice(physical_device, &device_create_info, null, @ptrCast(&device));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create logical device: {}\n", .{result});
            return VulkanError.DeviceCreationFailed;
        }
        
        self.device = device;
        
        // Get the compute queue
        var compute_queue: vk.VkQueue = undefined;
        vk.vkGetDeviceQueue(device, compute_queue_family_index.?, 0, @ptrCast(&compute_queue));
        self.compute_queue = compute_queue;
        
        std.debug.print("Logical device and compute queue created successfully\n", .{});
    }
    
    /// Create a command pool for command buffer allocation
    fn createCommandPool(self: *VulkanContext) !void {
        const device = self.device orelse return VulkanError.DeviceCreationFailed;
        const queue_family_index = self.compute_queue_family_index orelse return VulkanError.QueueCreationFailed;
        
        const pool_info = vk.VkCommandPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = queue_family_index,
        };
        
        var command_pool: vk.VkCommandPool = undefined;
        const result = vk.vkCreateCommandPool(device, &pool_info, null, @ptrCast(&command_pool));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create command pool: {}\n", .{result});
            return VulkanError.CommandPoolCreationFailed;
        }
        
        self.command_pool = command_pool;
        std.debug.print("Command pool created successfully\n", .{});
    }
    
    /// Clean up Vulkan resources
    pub fn deinit(self: *VulkanContext) void {
        const device = self.device;
        const instance = self.instance;
        
        // Destroy command pool if it exists
        if (self.command_pool) |command_pool| {
            if (device) |d| {
                vk.vkDestroyCommandPool(d, command_pool, null);
                self.command_pool = null;
            }
        }
        
        // Destroy logical device if it exists
        if (device) |d| {
            vk.vkDestroyDevice(d, null);
            self.device = null;
        }
        
        // Destroy instance if it exists
        if (instance) |i| {
            vk.vkDestroyInstance(i, null);
            self.instance = null;
        }
        
        std.debug.print("Vulkan resources cleaned up\n", .{});
    }
};

                std.debug.print("  - Your GPU driver may not support the requested Vulkan version\n", .{});
                std.debug.print("  - Try updating your graphics drivers\n", .{});
            },
            else => {
                std.debug.print("Unknown error ({})\n", .{result});
            },
        }
    }
    
    /// Initialize the Vulkan context
    pub fn initVulkan(self: *VulkanContext) !void {
        std.debug.print("=== Starting Vulkan Initialization ===\n", .{});
        
        // 1. Create application info
        std.debug.print("1. Creating application info...\n", .{});
        const app_info = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "MAYA",
            .applicationVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
            .pEngineName = "MAYA Engine",
            .engineVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
        };
        
        // 2. No extensions for now
        const required_extensions = [_][*:0]const u8{};
        
        // 3. Create instance with minimal configuration
        std.debug.print("2. Creating Vulkan instance...\n", .{});
        const create_info = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @as(u32, required_extensions.len),
            .ppEnabledExtensionNames = if (required_extensions.len > 0) &required_extensions[0] else null,
        };
        
        // 4. Create Vulkan instance
        var instance: vk.VkInstance = undefined;
        const result = vk.vkCreateInstance(&create_info, null, @ptrCast(&instance));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create Vulkan instance: {s}\n", .{
                switch (result) {
                    vk.VK_ERROR_OUT_OF_HOST_MEMORY => "VK_ERROR_OUT_OF_HOST_MEMORY",
                    vk.VK_ERROR_OUT_OF_DEVICE_MEMORY => "VK_ERROR_OUT_OF_DEVICE_MEMORY",
                    vk.VK_ERROR_INITIALIZATION_FAILED => "VK_ERROR_INITIALIZATION_FAILED",
                    vk.VK_ERROR_LAYER_NOT_PRESENT => "VK_ERROR_LAYER_NOT_PRESENT",
                    vk.VK_ERROR_EXTENSION_NOT_PRESENT => "VK_ERROR_EXTENSION_NOT_PRESENT",
                    vk.VK_ERROR_INCOMPATIBLE_DRIVER => "VK_ERROR_INCOMPATIBLE_DRIVER",
                    else => "Unknown error",
                }
            });
            return VulkanError.InitializationFailed;
        }
        
        self.instance = instance;
        std.debug.print("3. Vulkan instance created successfully!\n", .{});
        
        // 5. Pick a physical device
        std.debug.print("4. Picking physical device...\n", .{});
        try self.pickPhysicalDevice();
        
        // 6. Create logical device
        std.debug.print("5. Creating logical device...\n", .{});
        try self.createLogicalDevice();
        
        // 7. Create command pool
        std.debug.print("6. Creating command pool...\n", .{});
        try self.createCommandPool();
        
        std.debug.print("=== Vulkan initialization completed successfully ===\n\n", .{});
    }
    
    /// Pick a suitable physical device
    fn pickPhysicalDevice(self: *VulkanContext) !void {
        const instance = self.instance orelse return VulkanError.InitializationFailed;
        
        // Get number of physical devices
        var device_count: u32 = 0;
        _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
        
        if (device_count == 0) {
            std.debug.print("No Vulkan devices found!\n", .{});
            return VulkanError.NoPhysicalDevicesFound;
        }
        
        // Get all physical devices
        const devices = try self.allocator.alloc(vk.VkPhysicalDevice, device_count);
        defer self.allocator.free(devices);
        _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
        
        // For now, just pick the first discrete GPU if available
        for (devices) |device| {
            var properties: vk.VkPhysicalDeviceProperties = undefined;
            vk.vkGetPhysicalDeviceProperties(device, &properties);
            
            // Prefer discrete GPUs
            if (properties.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
                self.physical_device = device;
                std.debug.print("Selected discrete GPU: {s}\n", .{properties.deviceName});
                return;
            }
        }
        
        // If no discrete GPU, pick the first available device
        if (device_count > 0) {
            self.physical_device = devices[0];
            var properties: vk.VkPhysicalDeviceProperties = undefined;
            vk.vkGetPhysicalDeviceProperties(self.physical_device.?, &properties);
            std.debug.print("Selected device: {s}\n", .{properties.deviceName});
        } else {
            return VulkanError.NoSuitableDevice;
        }
    }
    
    /// Create a logical device with a compute queue
    fn createLogicalDevice(self: *VulkanContext) !void {
        const physical_device = self.physical_device orelse return VulkanError.NoSuitableDevice;
        
        // Find a queue family that supports compute
        var queue_family_count: u32 = 0;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);
        
        const queue_families = try self.allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
        defer self.allocator.free(queue_families);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);
        
        // Find a queue family that supports compute
        var compute_queue_family_index: ?u32 = null;
        for (queue_families, 0..) |queue_family, i| {
            if ((queue_family.queueFlags & vk.VK_QUEUE_COMPUTE_BIT) != 0) {
                compute_queue_family_index = @intCast(i);
                break;
            }
        }
        
        if (compute_queue_family_index == null) {
            std.debug.print("No compute queue family found!\n", .{});
            return VulkanError.QueueCreationFailed;
        }
        
        self.compute_queue_family_index = compute_queue_family_index;
        
        // Prepare queue creation info
        const queue_priority = [_]f32{1.0};
        const queue_create_info = vk.VkDeviceQueueCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = compute_queue_family_index.?,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };
        
        // Create device with just the compute queue
        const device_create_info = vk.VkDeviceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = 0,
            .ppEnabledExtensionNames = null,
            .pEnabledFeatures = null,
        };
        
        var device: vk.VkDevice = undefined;
        const result = vk.vkCreateDevice(physical_device, &device_create_info, null, @ptrCast(&device));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create logical device: {}\n", .{result});
            return VulkanError.DeviceCreationFailed;
        }
        
        self.device = device;
        
        // Get the compute queue
        var compute_queue: vk.VkQueue = undefined;
        vk.vkGetDeviceQueue(device, compute_queue_family_index.?, 0, @ptrCast(&compute_queue));
        self.compute_queue = compute_queue;
    }
    
    /// Create a command pool for command buffer allocation
    fn createCommandPool(self: *VulkanContext) !void {
        const device = self.device orelse return VulkanError.DeviceCreationFailed;
        const queue_family_index = self.compute_queue_family_index orelse return VulkanError.QueueCreationFailed;
        
        const pool_info = vk.VkCommandPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = queue_family_index,
        };
        
        var command_pool: vk.VkCommandPool = undefined;
        const result = vk.vkCreateCommandPool(device, &pool_info, null, @ptrCast(&command_pool));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create command pool: {}\n", .{result});
            return VulkanError.CommandPoolCreationFailed;
        }
        
        self.command_pool = command_pool;
    }
    
    /// Create a pipeline cache for improved pipeline creation performance
    fn createPipelineCache(self: *VulkanContext) !void {
        const device = self.device orelse return VulkanError.DeviceCreationFailed;
        
        const cache_info = vk.VkPipelineCacheCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .initialDataSize = 0,
            .pInitialData = null,
        };
        
        var pipeline_cache: vk.VkPipelineCache = undefined;
        const result = vk.vkCreatePipelineCache(device, &cache_info, null, @ptrCast(&pipeline_cache));
        
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Failed to create pipeline cache: {}\n", .{result});
            return VulkanError.PipelineCacheCreationFailed;
        }
        
        self.pipeline_cache = pipeline_cache;
    }
    
    /// Clean up Vulkan resources
    pub fn deinit(self: *VulkanContext) void {
        const device = self.device;
        const instance = self.instance;
        
        // Destroy device resources
        if (device) |dev| {
            // Destroy command pool if it exists
            if (self.command_pool) |command_pool| {
                vk.vkDestroyCommandPool(dev, command_pool, null);
                self.command_pool = null;
            }
            
            // Destroy pipeline cache if it exists
            if (self.pipeline_cache) |pipeline_cache| {
                vk.vkDestroyPipelineCache(dev, pipeline_cache, null);
                self.pipeline_cache = null;
                const debug_utils = vk.loadDebugUtilsFunctions(instance);
                debug_utils.destroyDebugUtilsMessengerEXT(instance, debug_messenger, null);
            }
            
            // Finally destroy the instance
            vk.vkDestroyInstance(instance, null);
            self.instance = null;
            std.debug.print("Vulkan instance destroyed\n", .{});
        }
    }
};
