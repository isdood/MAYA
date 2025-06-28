// examples/memory_management_direct.zig
const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
});

// Global allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Base types
const VkBool32 = u32;
const VkDeviceSize = u64;
const VkFlags = u32;
const VkSampleMask = u32;

// Constants
const VK_API_VERSION_1_0 = 0x00400000;
const VK_STRUCTURE_TYPE_APPLICATION_INFO = 0;
const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;
const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2;
const VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3;
const VK_SUCCESS = 0;
const VK_INCOMPLETE = 5;

// Enums
const VkResult = enum(c_int) {
    VK_SUCCESS = 0,
    VK_NOT_READY = 1,
    VK_TIMEOUT = 2,
    VK_EVENT_SET = 3,
    VK_EVENT_RESET = 4,
    VK_INCOMPLETE = 5,
    VK_ERROR_OUT_OF_HOST_MEMORY = -1,
    VK_ERROR_OUT_OF_DEVICE_MEMORY = -2,
    VK_ERROR_INITIALIZATION_FAILED = -3,
    VK_ERROR_DEVICE_LOST = -4,
    VK_ERROR_MEMORY_MAP_FAILED = -5,
    VK_ERROR_LAYER_NOT_PRESENT = -6,
    VK_ERROR_EXTENSION_NOT_PRESENT = -7,
    VK_ERROR_FEATURE_NOT_PRESENT = -8,
    VK_ERROR_INCOMPATIBLE_DRIVER = -9,
    VK_ERROR_TOO_MANY_OBJECTS = -10,
    VK_ERROR_FORMAT_NOT_SUPPORTED = -11,
    _,
};

const VkStructureType = enum(c_int) {
    VK_STRUCTURE_TYPE_APPLICATION_INFO = 0,
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1,
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2,
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3,
    _,
};

// Handles
const VkInstance = *opaque {};
const VkPhysicalDevice = *opaque {};
const VkDevice = *opaque {};
const VkQueue = *opaque {};
const VkDeviceMemory = *opaque {};

// Structs
const VkApplicationInfo = extern struct {
    sType: VkStructureType,
    pNext: ?*const anyopaque,
    pApplicationName: [*:0]const u8,
    applicationVersion: u32,
    pEngineName: [*:0]const u8,
    engineVersion: u32,
    apiVersion: u32,
};

const VkInstanceCreateInfo = extern struct {
    sType: VkStructureType,
    pNext: ?*const anyopaque,
    flags: VkFlags,
    pApplicationInfo: ?*const VkApplicationInfo,
    enabledLayerCount: u32,
    ppEnabledLayerNames: ?[*]const [*:0]const u8,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8,
};

const VkDeviceQueueCreateInfo = extern struct {
    sType: VkStructureType,
    pNext: ?*const anyopaque,
    flags: VkFlags,
    queueFamilyIndex: u32,
    queueCount: u32,
    pQueuePriorities: [*]const f32,
};

const VkPhysicalDeviceFeatures = extern struct {
    _dummy: u32 = 0,
};

const VkDeviceCreateInfo = extern struct {
    sType: VkStructureType,
    pNext: ?*const anyopaque,
    flags: VkFlags,
    queueCreateInfoCount: u32,
    pQueueCreateInfos: *const VkDeviceQueueCreateInfo,
    enabledLayerCount: u32,
    ppEnabledLayerNames: ?[*]const [*:0]const u8,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8,
    pEnabledFeatures: ?*const VkPhysicalDeviceFeatures,
};

const VkAllocationCallbacks = extern struct {
    pUserData: ?*anyopaque,
    pfnAllocation: ?*const fn (?*anyopaque, usize, usize, u32) callconv(.C) ?*anyopaque,
    pfnReallocation: ?*const fn (?*anyopaque, ?*anyopaque, usize, usize, u32) callconv(.C) ?*anyopaque,
    pfnFree: ?*const fn (?*anyopaque, ?*anyopaque) callconv(.C) void,
    pfnInternalAllocation: ?*const fn (?*anyopaque, usize, u32, u32) callconv(.C) void,
    pfnInternalFree: ?*const fn (?*anyopaque, usize, u32, u32) callconv(.C) void,
};

const VkPhysicalDeviceProperties = extern struct {
    apiVersion: u32,
    driverVersion: u32,
    vendorID: u32,
    deviceID: u32,
    deviceType: u32,
    deviceName: [256]u8,
    pipelineCacheUUID: [16]u8,
    limits: VkPhysicalDeviceLimits,
    sparseProperties: VkPhysicalDeviceSparseProperties,
};

const VkPhysicalDeviceLimits = extern struct {
    maxImageDimension1D: u32,
    maxImageDimension2D: u32,
    maxImageDimension3D: u32,
    // ... other fields can be added as needed
};

const VkPhysicalDeviceSparseProperties = extern struct {
    residencyStandard2DBlockShape: VkBool32,
    residencyStandard2DMultisampleBlockShape: VkBool32,
    residencyStandard3DBlockShape: VkBool32,
    residencyAlignedMipSize: VkBool32,
    residencyNonResidentStrict: VkBool32,
};

const VkQueueFamilyProperties = extern struct {
    queueFlags: VkQueueFlags,
    queueCount: u32,
    timestampValidBits: u32,
    minImageTransferGranularity: VkExtent3D,
};

const VkQueueFlags = packed struct(u32) {
    GRAPHICS_BIT: bool = false,
    COMPUTE_BIT: bool = false,
    TRANSFER_BIT: bool = false,
    SPARSE_BINDING_BIT: bool = false,
    _reserved_bits_4_31: u28 = 0,
};

const VkExtent3D = extern struct {
    width: u32,
    height: u32,
    depth: u32,
};

// Global Vulkan library handle
var g_vulkan_lib: ?*anyopaque = null;

// Global function pointers
var g_vkCreateInstance: ?*const fn (*const VkInstanceCreateInfo, ?*const VkAllocationCallbacks, *VkInstance) callconv(.C) VkResult = null;
var g_vkEnumeratePhysicalDevices: ?*const fn (VkInstance, *u32, ?[*]VkPhysicalDevice) callconv(.C) VkResult = null;
var g_vkGetPhysicalDeviceProperties: ?*const fn (VkPhysicalDevice, *VkPhysicalDeviceProperties) callconv(.C) void = null;
var g_vkGetPhysicalDeviceQueueFamilyProperties: ?*const fn (VkPhysicalDevice, *u32, ?[*]VkQueueFamilyProperties) callconv(.C) void = null;
var g_vkGetPhysicalDeviceFeatures: ?*const fn (VkPhysicalDevice, *VkPhysicalDeviceFeatures) callconv(.C) void = null;
var g_vkCreateDevice: ?*const fn (VkPhysicalDevice, *const VkDeviceCreateInfo, ?*const VkAllocationCallbacks, *VkDevice) callconv(.C) VkResult = null;
var g_vkGetDeviceQueue: ?*const fn (VkDevice, u32, u32, *VkQueue) callconv(.C) void = null;
var g_vkDestroyInstance: ?*const fn (VkInstance, ?*const VkAllocationCallbacks) callconv(.C) void = null;
var g_vkDestroyDevice: ?*const fn (VkDevice, ?*const VkAllocationCallbacks) callconv(.C) void = null;

// Helper function to load Vulkan functions
fn loadVulkanFunction(comptime T: type, name: [*:0]const u8) !T {
    const sym = c.dlsym(g_vulkan_lib, name);
    if (sym == null) {
        std.debug.print("Failed to load function: {s}\n", .{name});
        return error.FunctionNotFound;
    }
    return @as(T, @ptrFromInt(@intFromPtr(sym)));
}

// Main function
pub fn main() !void {
    std.debug.print("Starting memory management example with direct Vulkan loading...\n", .{});
    
    // Load Vulkan library
    g_vulkan_lib = c.dlopen("libvulkan.so.1", c.RTLD_LAZY | c.RTLD_LOCAL);
    if (g_vulkan_lib == null) {
        std.debug.print("Failed to load Vulkan library: {s}\n", .{c.dlerror()});
        return error.VulkanLibraryNotFound;
    }
    defer _ = c.dlclose(g_vulkan_lib);
    
    // Load Vulkan functions
    g_vkCreateInstance = try loadVulkanFunction(@TypeOf(g_vkCreateInstance), "vkCreateInstance");
    g_vkEnumeratePhysicalDevices = try loadVulkanFunction(@TypeOf(g_vkEnumeratePhysicalDevices), "vkEnumeratePhysicalDevices");
    g_vkGetPhysicalDeviceProperties = try loadVulkanFunction(@TypeOf(g_vkGetPhysicalDeviceProperties), "vkGetPhysicalDeviceProperties");
    g_vkGetPhysicalDeviceQueueFamilyProperties = try loadVulkanFunction(@TypeOf(g_vkGetPhysicalDeviceQueueFamilyProperties), "vkGetPhysicalDeviceQueueFamilyProperties");
    g_vkGetPhysicalDeviceFeatures = try loadVulkanFunction(@TypeOf(g_vkGetPhysicalDeviceFeatures), "vkGetPhysicalDeviceFeatures");
    g_vkCreateDevice = try loadVulkanFunction(@TypeOf(g_vkCreateDevice), "vkCreateDevice");
    g_vkGetDeviceQueue = try loadVulkanFunction(@TypeOf(g_vkGetDeviceQueue), "vkGetDeviceQueue");
    g_vkDestroyDevice = try loadVulkanFunction(@TypeOf(g_vkDestroyDevice), "vkDestroyDevice");
    g_vkDestroyInstance = try loadVulkanFunction(@TypeOf(g_vkDestroyInstance), "vkDestroyInstance");
    
    // Create Vulkan instance
    const app_info = VkApplicationInfo{
        .sType = .VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Memory Management Example",
        .applicationVersion = VK_API_VERSION_1_0,
        .pEngineName = "No Engine",
        .engineVersion = VK_API_VERSION_1_0,
        .apiVersion = VK_API_VERSION_1_0,
    };
    
    const create_info = VkInstanceCreateInfo{
        .sType = .VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    };
    
    var instance: VkInstance = undefined;
    const result = g_vkCreateInstance.?(&create_info, null, &instance);
    if (result != .VK_SUCCESS) {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
        return error.VulkanInstanceCreationFailed;
    }
    defer g_vkDestroyInstance.?(instance, null);
    
    // Enumerate physical devices
    var device_count: u32 = 0;
    _ = g_vkEnumeratePhysicalDevices.?(instance, &device_count, null);
    if (device_count == 0) {
        std.debug.print("No Vulkan devices found\n", .{});
        return error.NoVulkanDevicesFound;
    }
    
    const devices = try allocator.alloc(VkPhysicalDevice, device_count);
    defer allocator.free(devices);
    _ = g_vkEnumeratePhysicalDevices.?(instance, &device_count, devices.ptr);
    
    // Use the first physical device
    const physical_device = devices[0];
    
    // Get queue family properties
    var queue_family_count: u32 = 0;
    g_vkGetPhysicalDeviceQueueFamilyProperties.?(physical_device, &queue_family_count, null);
    if (queue_family_count == 0) {
        std.debug.print("No queue families found\n", .{});
        return error.NoQueueFamiliesFound;
    }
    
    // Create a logical device
    const queue_priority = [_]f32{1.0};
    const queue_create_info = VkDeviceQueueCreateInfo{
        .sType = .VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = 0, // Use the first queue family
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };
    
    const device_create_info = VkDeviceCreateInfo{
        .sType = .VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
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
    
    var device: VkDevice = undefined;
    const device_result = g_vkCreateDevice.?(physical_device, &device_create_info, null, &device);
    if (device_result != .VK_SUCCESS) {
        std.debug.print("Failed to create logical device: {}\n", .{device_result});
        return error.DeviceCreationFailed;
    }
    defer g_vkDestroyDevice.?(device, null);
    
    // Get the device queue
    var queue: VkQueue = undefined;
    g_vkGetDeviceQueue.?(device, 0, 0, &queue);
    
    std.debug.print("Successfully initialized Vulkan!\n", .{});
}
