const std = @import("std");
const vk = @import("vk");

pub const VulkanContext = struct {
    allocator: std.mem.Allocator,
    instance: vk.VkInstance,
    physical_device: ?vk.VkPhysicalDevice,
    device: ?vk.VkDevice,
    graphics_queue: ?vk.VkQueue,
    compute_queue: ?vk.VkQueue,
    present_queue: ?vk.VkQueue,
    debug_messenger: vk.VkDebugUtilsMessengerEXT,
    
    pub fn init(allocator: std.mem.Allocator) !@This() {
        // Initialize Vulkan
        var instance: vk.VkInstance = undefined;
        {
            const app_info = vk.VkApplicationInfo{
                .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .pNext = null,
                .pApplicationName = "Vulkan Memory Management",
                .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
                .pEngineName = "No Engine",
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
            
            const result = vk.vkCreateInstance(&create_info, null, &instance);
            if (result != vk.VK_SUCCESS) {
                return error.FailedToCreateInstance;
            }
        }
        
        // Pick the first physical device
        var physical_device: ?vk.VkPhysicalDevice = null;
        {
            var device_count: u32 = 0;
            _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, null);
            
            if (device_count == 0) {
                return error.NoPhysicalDevicesFound;
            }
            
            var devices = try allocator.alloc(vk.VkPhysicalDevice, device_count);
            defer allocator.free(devices);
            _ = vk.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr);
            
            // Just pick the first device for simplicity
            physical_device = devices[0];
        }
        
        // Create a logical device
        var device: ?vk.VkDevice = null;
        var graphics_queue: ?vk.VkQueue = null;
        var compute_queue: ?vk.VkQueue = null;
        var present_queue: ?vk.VkQueue = null;
        
        if (physical_device) |pd| {
            // Find queue families
            var queue_family_count: u32 = 0;
            vk.vkGetPhysicalDeviceQueueFamilyProperties(pd, &queue_family_count, null);
            
            var queue_families = try allocator.alloc(vk.VkQueueFamilyProperties, queue_family_count);
            defer allocator.free(queue_families);
            vk.vkGetPhysicalDeviceQueueFamilyProperties(pd, &queue_family_count, queue_families.ptr);
            
            var graphics_queue_family: ?u32 = null;
            var compute_queue_family: ?u32 = null;
            var present_queue_family: ?u32 = null;
            
            for (queue_families, 0..) |queue_family, i| {
                if (queue_family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                    graphics_queue_family = @intCast(i);
                }
                if (queue_family.queueFlags & vk.VK_QUEUE_COMPUTE_BIT != 0) {
                    compute_queue_family = @intCast(i);
                }
                if (queue_family.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0) {
                    present_queue_family = @intCast(i);
                    break;
                }
            }
            
            const queue_priorities = [_]f32{1.0};
            var queue_create_infos: [3]vk.VkDeviceQueueCreateInfo = undefined;
            var queue_create_info_count: u32 = 0;
            
            if (graphics_queue_family) |queue_family| {
                queue_create_infos[queue_create_info_count] = .{
                    .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .pNext = null,
                    .flags = 0,
                    .queueFamilyIndex = queue_family,
                    .queueCount = 1,
                    .pQueuePriorities = &queue_priorities,
                };
                queue_create_info_count += 1;
            }
            
            if (compute_queue_family != graphics_queue_family) {
                queue_create_infos[queue_create_info_count] = .{
                    .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .pNext = null,
                    .flags = 0,
                    .queueFamilyIndex = compute_queue_family orelse continue,
                    .queueCount = 1,
                    .pQueuePriorities = &queue_priorities,
                };
                queue_create_info_count += 1;
            }
            
            if (present_queue_family != graphics_queue_family and present_queue_family != compute_queue_family) {
                queue_create_infos[queue_create_info_count] = .{
                    .sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .pNext = null,
                    .flags = 0,
                    .queueFamilyIndex = present_queue_family orelse continue,
                    .queueCount = 1,
                    .pQueuePriorities = &queue_priorities,
                };
                queue_create_info_count += 1;
            }
            
            const device_create_info = vk.VkDeviceCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .pNext = null,
                .flags = 0,
                .queueCreateInfoCount = queue_create_info_count,
                .pQueueCreateInfos = &queue_create_infos,
                .enabledLayerCount = 0,
                .ppEnabledLayerNames = null,
                .enabledExtensionCount = 0,
                .ppEnabledExtensionNames = null,
                .pEnabledFeatures = null,
            };
            
            var dev: vk.VkDevice = undefined;
            const result = vk.vkCreateDevice(pd, &device_create_info, null, &dev);
            if (result == vk.VK_SUCCESS) {
                device = dev;
                
                // Get queues
                if (graphics_queue_family) |queue_family| {
                    var queue: vk.VkQueue = undefined;
                    vk.vkGetDeviceQueue(dev, queue_family, 0, &queue);
                    graphics_queue = queue;
                }
                
                if (compute_queue_family) |queue_family| {
                    var queue: vk.VkQueue = undefined;
                    vk.vkGetDeviceQueue(dev, queue_family, 0, &queue);
                    compute_queue = queue;
                }
                
                if (present_queue_family) |queue_family| {
                    var queue: vk.VkQueue = undefined;
                    vk.vkGetDeviceQueue(dev, queue_family, 0, &queue);
                    present_queue = queue;
                }
            }
        }
        
        return .{
            .allocator = allocator,
            .instance = instance,
            .physical_device = physical_device,
            .device = device,
            .graphics_queue = graphics_queue,
            .compute_queue = compute_queue,
            .present_queue = present_queue,
            .debug_messenger = undefined,
        };
    }
    
    pub fn deinit(self: *@This()) void {
        if (self.device) |device| {
            vk.vkDestroyDevice(device, null);
            self.device = null;
        }
        
        if (self.instance) |instance| {
            vk.vkDestroyInstance(instance, null);
            self.instance = null;
        }
        
        self.physical_device = null;
        self.graphics_queue = null;
        self.compute_queue = null;
        self.present_queue = null;
    }
};
