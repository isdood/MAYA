const std = @import("std");
const c = @import("vk");

const Allocator = std.mem.Allocator;

const VulkanError = error{
    InitializationFailed,
    NoSuitableDevice,
    NoComputeQueue,
    OutOfMemory,
    ShaderCompilationFailed,
    InvalidOperation,
};

// Import the debug callback from vk.zig
extern fn debugCallback(
    message_severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    message_types: c.VkDebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(.C) c.VkBool32;

// Load instance-level function pointers
fn loadInstanceFunctions(instance: c.VkInstance) void {
    // This function would load any required instance-level function pointers
    // that aren't automatically loaded by the Vulkan bindings
    _ = instance;
}

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
        std.debug.print("Creating Vulkan context...\n", .{});
        
        // Initialize with explicit null values for Vulkan handles
        var self = VulkanContext{
            .allocator = allocator,
            .instance = null,
            .physical_device = null,
            .device = null,
            .queue = null,
            .queue_family_index = 0,
            .command_pool = null,
            .pipeline_cache = null,
            .debug_messenger = null,
        };

        // Initialize Vulkan
        std.debug.print("Initializing Vulkan...\n", .{});
        try self.initVulkan();
        std.debug.print("Vulkan initialization complete\n", .{});
        
        // Pick physical device
        std.debug.print("Picking physical device...\n", .{});
        try self.pickPhysicalDevice();
        std.debug.print("Physical device selected\n", .{});
        
        // Create logical device
        std.debug.print("Creating logical device...\n", .{});
        try self.createLogicalDevice();
        std.debug.print("Logical device created\n", .{});
        
        // Create command pool
        std.debug.print("Creating command pool...\n", .{});
        try self.createCommandPool();
        std.debug.print("Command pool created\n", .{});
        
        std.debug.print("Vulkan context created successfully!\n", .{});
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
            const destroy_func = c.vkGetInstanceProcAddr(self.instance, "vkDestroyDebugUtilsMessengerEXT");
            if (destroy_func) |func_ptr| {
                const destroy_fn: c.PFN_vkDestroyDebugUtilsMessengerEXT = @ptrCast(func_ptr);
                destroy_fn(self.instance, self.debug_messenger, null);
            }
            
            c.vkDestroyInstance(self.instance, null);
        }
    }
    
    fn initVulkan(self: *VulkanContext) VulkanError!void {
        std.debug.print("[DEBUG] Initializing Vulkan instance...\n", .{});
        
        // Ensure the instance is null before creating it
        self.instance = null;
        
        // Check if Vulkan is available by getting the API version
        std.debug.print("[DEBUG] Checking Vulkan availability...\n", .{});
        var instance_version: u32 = 0;
        std.debug.print("[DEBUG] Before vkEnumerateInstanceVersion call\n", .{});
        
        // Call the Vulkan function through the C ABI
        const version_result = @as(c.PFN_vkEnumerateInstanceVersion, @ptrCast(c.vkGetInstanceProcAddr(null, "vkEnumerateInstanceVersion")))(&instance_version);
        std.debug.print("[DEBUG] After vkEnumerateInstanceVersion call, result: {}\n", .{version_result});
        
        if (version_result != c.VK_SUCCESS) {
            std.debug.print("[ERROR] Vulkan is not available on this system: {}\n", .{version_result});
            return VulkanError.InitializationFailed;
        }
        
        // Log the Vulkan API version
        const major = c.VK_API_VERSION_MAJOR(instance_version);
        const minor = c.VK_API_VERSION_MINOR(instance_version);
        const patch = c.VK_API_VERSION_PATCH(instance_version);
        std.debug.print("[DEBUG] Vulkan API version: {}.{}.{}\n", .{major, minor, patch});
        std.debug.print("[DEBUG] Vulkan is available\n", .{});
        
        // Print Vulkan API version
        std.debug.print("[DEBUG] Vulkan API version: {}.{}.{}\n", .{
            c.VK_API_VERSION_MAJOR(instance_version),
            c.VK_API_VERSION_MINOR(instance_version),
            c.VK_API_VERSION_PATCH(instance_version)
        });
        std.debug.print("Vulkan API version: {}.{}.{}\n", .{
            c.VK_API_VERSION_MAJOR(instance_version),
            c.VK_API_VERSION_MINOR(instance_version),
            c.VK_API_VERSION_PATCH(instance_version)
        });
        
        // Get available instance extensions
        std.debug.print("[DEBUG] Enumerating instance extensions...\n", .{});
        var extension_count: u32 = 0;
        
        std.debug.print("[DEBUG] Calling vkEnumerateInstanceExtensionProperties (first call)...\n", .{});
        var enum_result = c.enumerateInstanceExtensionProperties(null, &extension_count, null);
        std.debug.print("[DEBUG] vkEnumerateInstanceExtensionProperties result: {}, count: {}\n", .{enum_result, extension_count});
        
        if (enum_result != c.VK_SUCCESS and enum_result != c.VK_INCOMPLETE) {
            std.debug.print("[ERROR] Failed to get instance extension count: {}\n", .{enum_result});
            return VulkanError.InitializationFailed;
        }
        
        std.debug.print("Found {} instance extensions\n", .{extension_count});
        
        const extensions = if (extension_count > 0) blk: {
            const exts = try self.allocator.alloc(c.VkExtensionProperties, extension_count);
            enum_result = c.vkEnumerateInstanceExtensionProperties(null, &extension_count, exts.ptr);
            if (enum_result != c.VK_SUCCESS) {
                self.allocator.free(exts);
                std.debug.print("Failed to get instance extensions: {}\n", .{enum_result});
                return VulkanError.InitializationFailed;
            }
            break :blk exts;
        } else &[_]c.VkExtensionProperties{};
        defer if (extension_count > 0) self.allocator.free(extensions);
        
        std.debug.print("Available instance extensions ({}):\n", .{extension_count});
        for (extensions) |ext| {
            const ext_name = @as([*:0]const u8, @ptrCast(&ext.extensionName));
            std.debug.print("  {s} (v{})\n", .{std.mem.span(ext_name), ext.specVersion});
        }
        
        const app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pNext = null,
            .pApplicationName = "MAYA Vulkan Compute",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_MAKE_VERSION(1, 2, 0), // Use explicit version
        };
        
        std.debug.print("Creating Vulkan instance...\n", .{});
        
        // Define required extensions
        std.debug.print("[DEBUG] Checking required extensions...\n", .{});
        const required_extensions = [_][*:0]const u8{
            c.VK_KHR_SURFACE_EXTENSION_NAME,
            c.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
            c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME, // For debug logging
        };
        
        // Print required extensions
        std.debug.print("[DEBUG] Required extensions ({}):\n", .{required_extensions.len});
        for (required_extensions) |ext| {
            std.debug.print("  {s}\n", .{std.mem.span(ext)});
        }
        
        // Check if all required extensions are available
        for (required_extensions) |ext| {
            var found = false;
            for (extensions) |available| {
                const ext_name = @as([*:0]const u8, @ptrCast(&available.extensionName));
                if (std.mem.eql(u8, std.mem.span(ext), std.mem.span(ext_name))) {
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                std.debug.print("Required extension not found: {s}\n", .{ext});
                return VulkanError.InitializationFailed;
            }
        }
        
        std.debug.print("Found {} Vulkan instance extensions\n", .{extension_count});
        
        // Request common validation layers if available
        const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
        
        // Check if validation layers are available
        var layer_count: u32 = 0;
        _ = c.vkEnumerateInstanceLayerProperties(&layer_count, null);
        const available_layers = try self.allocator.alloc(c.VkLayerProperties, layer_count);
        defer self.allocator.free(available_layers);
        _ = c.vkEnumerateInstanceLayerProperties(&layer_count, available_layers.ptr);
        
        var enable_validation = false;
        
        if (layer_count > 0) {
            std.debug.print("Available Vulkan layers:\n", .{});
            for (available_layers) |layer| {
                // Print the raw layer name as a C string
                const layer_name = @as([*:0]const u8, @ptrCast(&layer.layerName));
                const name = std.mem.span(layer_name);
                std.debug.print("  {s}\n", .{name});
                
                // Check for validation layer
                if (std.mem.eql(u8, std.mem.span(layer_name), "VK_LAYER_KHRONOS_validation")) {
                    enable_validation = true;
                }
            }
        }
        
        std.debug.print("Enabling Vulkan extensions:\n", .{});
        for (required_extensions) |ext| {
            std.debug.print("  {s}\n", .{ext});
        }
        
        var create_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @as(u32, @intCast(required_extensions.len)),
            .ppEnabledExtensionNames = &required_extensions[0],
        };
        
        // Enable validation layers if available
        var debug_create_info: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
        if (enable_validation) {
            std.debug.print("Enabling validation layers\n", .{});
            
            const validation_features = [_]c.VkValidationFeatureEnableEXT{
                c.VK_VALIDATION_FEATURE_ENABLE_DEBUG_PRINTF_EXT,
                c.VK_VALIDATION_FEATURE_ENABLE_BEST_PRACTICES_EXT,
            };
            
            var create_info_next = c.VkValidationFeaturesEXT{
                .sType = c.VK_STRUCTURE_TYPE_VALIDATION_FEATURES_EXT,
                .pNext = null,
                .enabledValidationFeatureCount = validation_features.len,
                .pEnabledValidationFeatures = &validation_features[0],
                .disabledValidationFeatureCount = 0,
                .pDisabledValidationFeatures = null,
            };
            
            debug_create_info = c.VkDebugUtilsMessengerCreateInfoEXT{
                .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
                .pNext = &create_info_next,
                .flags = 0,
                .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                                 c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT |
                                 c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                                 c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
                .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                              c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                              c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
                .pfnUserCallback = debugCallback,
                .pUserData = null,
            };
            
            create_info.enabledLayerCount = validation_layers.len;
            create_info.ppEnabledLayerNames = &validation_layers[0];
            debug_create_info.pNext = create_info.pNext;
            create_info.pNext = &debug_create_info;
        }
        
        std.debug.print("[DEBUG] Creating Vulkan instance...\n", .{});
        var instance: c.VkInstance = undefined;
        const create_result = c.createInstance(&create_info, null, &instance);
        if (create_result != c.VK_SUCCESS) {
            std.debug.print("[ERROR] Failed to create Vulkan instance: {}\n", .{create_result});
            return VulkanError.InitializationFailed;
        }
        
        self.instance = instance;
        std.debug.print("Vulkan instance created successfully!\n", .{});
        
        // Setup debug messenger if validation is enabled
        if (enable_validation) {
            const debug_utils = c.loadDebugUtils(self.instance);
            var debug_messenger: c.VkDebugUtilsMessengerEXT = undefined;
            const messenger_result = debug_utils.createDebugUtilsMessengerEXT(
                &debug_create_info,
                null,
                &debug_messenger
            );
            if (messenger_result == c.VK_SUCCESS) {
                self.debug_messenger = debug_messenger;
                std.debug.print("Debug messenger created successfully\n", .{});
            } else {
                std.debug.print("Failed to create debug messenger: {}\n", .{messenger_result});
                // Don't fail if we can't create the debug messenger
            }
        }
    }
    
    fn pickPhysicalDevice(self: *VulkanContext) VulkanError!void {
        std.debug.print("Picking physical device...\n", .{});
        
        var device_count: u32 = 0;
        _ = c.vkEnumeratePhysicalDevices(self.instance, &device_count, null);
        
        if (device_count == 0) {
            std.debug.print("No Vulkan devices found!\n", .{});
            return VulkanError.NoSuitableDevice;
        }
        
        std.debug.print("Found {} Vulkan device(s)\n", .{device_count});
        
        const devices = try self.allocator.alloc(c.VkPhysicalDevice, device_count);
        defer self.allocator.free(devices);
        _ = c.vkEnumeratePhysicalDevices(self.instance, &device_count, devices.ptr);
        
        // Just pick the first device for now
        if (device_count == 0) {
            std.debug.print("No suitable Vulkan device found!\n", .{});
            return VulkanError.NoSuitableDevice;
        }
        
        self.physical_device = devices[0];
        
        // Print device properties
        var properties: c.VkPhysicalDeviceProperties = undefined;
        c.vkGetPhysicalDeviceProperties(self.physical_device, &properties);
        
        std.debug.print("Selected device: {s}\n", .{properties.deviceName});
        std.debug.print("  API version: {}.{}.{}\n", .{
            c.VK_VERSION_MAJOR(properties.apiVersion),
            c.VK_VERSION_MINOR(properties.apiVersion),
            c.VK_VERSION_PATCH(properties.apiVersion)
        });
        std.debug.print("  Driver version: {}.{}.{}\n", .{
            c.VK_VERSION_MAJOR(properties.driverVersion),
            c.VK_VERSION_MINOR(properties.driverVersion),
            c.VK_VERSION_PATCH(properties.driverVersion)
        });
        
        // Find queue family with compute support
        var queue_family_count: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, null);
        
        if (queue_family_count == 0) {
            std.debug.print("No queue families found on device\n", .{});
            return VulkanError.NoComputeQueue;
        }
        
        const queue_family_properties = try self.allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
        defer self.allocator.free(queue_family_properties);
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.physical_device, &queue_family_count, queue_family_properties.ptr);
        
        // Find a queue family that supports compute
        self.queue_family_index = std.math.maxInt(u32);
        for (queue_family_properties, 0..) |props, i| {
            if ((props.queueFlags & c.VK_QUEUE_COMPUTE_BIT) != 0) {
                self.queue_family_index = @as(u32, @intCast(i));
                std.debug.print("Found compute queue family at index {}\n", .{i});
                break;
            }
        }
        
        if (self.queue_family_index == std.math.maxInt(u32)) {
            std.debug.print("No compute queue family found on device\n", .{});
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
            .size = @as(u64, @intCast(size)),
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
        
        var memory_type_index: u32 = std.math.maxInt(u32);
        for (memory_properties.memoryTypes[0..@as(usize, memory_properties.memoryTypeCount)], 0..) |memory_type, i| {
            if (i < 32 and (requirements.memoryTypeBits & (@as(u32, 1) << @as(u5, @intCast(i)))) != 0 and
                (memory_type.propertyFlags & properties) == properties) {
                memory_type_index = @as(u32, @intCast(i));
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
};
