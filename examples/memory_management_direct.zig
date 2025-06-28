// examples/memory_management_direct.zig
const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
});

// Minimal Vulkan types needed for our example
const VkResult = enum(c_int) {
    VK_SUCCESS = 0,
    VK_NOT_READY = 1,
    VK_ERROR_OUT_OF_HOST_MEMORY = -1,
    VK_ERROR_OUT_OF_DEVICE_MEMORY = -2,
    VK_ERROR_INITIALIZATION_FAILED = -3,
    VK_ERROR_EXTENSION_NOT_PRESENT = -7,
    VK_ERROR_LAYER_NOT_PRESENT = -8,
    VK_ERROR_INCOMPATIBLE_DRIVER = -9,
    _,
};

const VkStructureType = enum(c_int) {
    VK_STRUCTURE_TYPE_APPLICATION_INFO = 0,
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1,
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2,
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3,
    _,
};

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

fn VK_MAKE_API_VERSION(variant: u32, major: u32, minor: u32, patch: u32) u32 {
    return (@as(u32, variant) << 29) |
           (@as(u32, major) << 22) |
           (@as(u32, minor) << 12) |
           patch;
}

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
    VK_ERROR_FRAGMENTED_POOL = -12,
    VK_ERROR_UNKNOWN = -13,
};

const VkPhysicalDeviceType = enum(c_int) {
    VK_PHYSICAL_DEVICE_TYPE_OTHER = 0,
    VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = 1,
    VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = 2,
    VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = 3,
    VK_PHYSICAL_DEVICE_TYPE_CPU = 4,
    _,
};

const VkQueueFlagBits = enum(c_int) {
    VK_QUEUE_GRAPHICS_BIT = 0x00000001,
    VK_QUEUE_COMPUTE_BIT = 0x00000002,
    VK_QUEUE_TRANSFER_BIT = 0x00000004,
    VK_QUEUE_SPARSE_BINDING_BIT = 0x00000008,
    _,
};

const VkMemoryPropertyFlagBits = enum(c_int) {
    VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0x00000001,
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0x00000002,
    VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x00000004,
    VK_MEMORY_PROPERTY_HOST_CACHED_BIT = 0x00000008,
    VK_MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT = 0x00000010,
    _,
};

// Handles
type VkInstance = *opaque {};
type VkPhysicalDevice = *opaque {};
type VkDevice = *opaque {};
type VkQueue = *opaque {};
type VkDeviceMemory = *opaque {};

// Structures
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

const VkPhysicalDeviceProperties = extern struct {
    apiVersion: u32,
    driverVersion: u32,
    vendorID: u32,
    deviceID: u32,
    deviceType: VkPhysicalDeviceType,
    deviceName: [256]u8,
    pipelineCacheUUID: [16]u8,
    limits: VkPhysicalDeviceLimits,
    sparseProperties: VkPhysicalDeviceSparseProperties,
};

const VkPhysicalDeviceLimits = extern struct {
    // Many fields omitted for brevity
    maxImageDimension1D: u32,
    maxImageDimension2D: u32,
    maxImageDimension3D: u32,
    // ... other fields ...
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

const VkExtent3D = extern struct {
    width: u32,
    height: u32,
    depth: u32,
};

const VkDeviceQueueCreateInfo = extern struct {
    sType: VkStructureType,
    pNext: ?*const anyopaque,
    flags: VkDeviceQueueCreateFlags,
    queueFamilyIndex: u32,
    queueCount: u32,
    pQueuePriorities: [*]const f32,
};

const VkDeviceCreateInfo = extern struct {
    sType: VkStructureType,
    pNext: ?*const anyopaque,
    flags: VkDeviceCreateFlags,
    queueCreateInfoCount: u32,
    pQueueCreateInfos: ?[*]const VkDeviceQueueCreateInfo,
    enabledLayerCount: u32,
    ppEnabledLayerNames: ?[*]const [*:0]const u8,
    enabledExtensionCount: u32,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8,
    pEnabledFeatures: ?*const VkPhysicalDeviceFeatures,
};

const VkPhysicalDeviceFeatures = extern struct {
    // Many fields omitted for brevity
    robustBufferAccess: VkBool32,
    // ... other fields ...
};

const VkDeviceQueueCreateFlags = VkFlags;
const VkDeviceCreateFlags = VkFlags;
const VkQueueFlags = VkFlags;

// Function pointer types
const PFN_vkCreateInstance = *const fn(
    pCreateInfo: *const VkInstanceCreateInfo,
    pAllocator: ?*const anyopaque,
    pInstance: *VkInstance
) callconv(.C) VkResult;

const PFN_vkDestroyInstance = *const fn(
    instance: VkInstance,
    pAllocator: ?*const anyopaque
) callconv(.C) void;

const PFN_vkEnumeratePhysicalDevices = *const fn(
    instance: VkInstance,
    pPhysicalDeviceCount: *u32,
    pPhysicalDevices: ?[*]VkPhysicalDevice
) callconv(.C) VkResult;

const PFN_vkGetPhysicalDeviceProperties = *const fn(
    physicalDevice: VkPhysicalDevice,
    pProperties: *VkPhysicalDeviceProperties
) callconv(.C) void;

const PFN_vkGetPhysicalDeviceQueueFamilyProperties = *const fn(
    physicalDevice: VkPhysicalDevice,
    pQueueFamilyPropertyCount: *u32,
    pQueueFamilyProperties: ?[*]VkQueueFamilyProperties
) callconv(.C) void;

const PFN_vkCreateDevice = *const fn(
    physicalDevice: VkPhysicalDevice,
    pCreateInfo: *const VkDeviceCreateInfo,
    pAllocator: ?*const anyopaque,
    pDevice: *VkDevice
) callconv(.C) VkResult;

const PFN_vkDestroyDevice = *const fn(
    device: VkDevice,
    pAllocator: ?*const anyopaque
) callconv(.C) void;

const PFN_vkGetDeviceQueue = *const fn(
    device: VkDevice,
    queueFamilyIndex: u32,
    queueIndex: u32,
    pQueue: *VkQueue
) callconv(.C) void;

// Global function pointers
var g_vkCreateInstance: ?PFN_vkCreateInstance = null;
var g_vkDestroyInstance: ?PFN_vkDestroyInstance = null;
var g_vkEnumeratePhysicalDevices: ?PFN_vkEnumeratePhysicalDevices = null;
var g_vkGetPhysicalDeviceProperties: ?PFN_vkGetPhysicalDeviceProperties = null;
var g_vkGetPhysicalDeviceQueueFamilyProperties: ?PFN_vkGetPhysicalDeviceQueueFamilyProperties = null;
var g_vkCreateDevice: ?PFN_vkCreateDevice = null;
var g_vkDestroyDevice: ?PFN_vkDestroyDevice = null;
var g_vkGetDeviceQueue: ?PFN_vkGetDeviceQueue = null;

// Helper function to load a Vulkan function
fn loadVulkanFunction(comptime T: type, name: [:0]const u8) !T {
    const lib = c.dlopen("libvulkan.so.1", c.RTLD_LAZY | c.RTLD_LOCAL);
    if (lib == null) {
        std.debug.print("Failed to load libvulkan.so.1: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    }
    
    if (c.dlsym(lib, @ptrCast(name))) |ptr| {
        return @ptrCast(ptr);
    } else {
        std.debug.print("Failed to get {s}: {s}\n", .{name, c.dlerror()});
        return error.FailedToGetFunction;
    }
}

// Load Vulkan library and get function pointers
fn loadVulkan() !void {
    std.debug.print("Loading Vulkan library...\n", .{});
    
    const lib = c.dlopen("libvulkan.so.1", c.RTLD_LAZY | c.RTLD_LOCAL);
    if (lib == null) {
        std.debug.print("Failed to load libvulkan.so.1: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    }
    
    // Helper to load functions
    const loadFn = struct {
        fn load(comptime T: type, name: []const u8, out: *?T) !void {
            const name_z = try std.cstr.addNullByte(allocator, name);
            defer allocator.free(name_z);
            
            if (c.dlsym(lib, @ptrCast(name_z))) |ptr| {
                out.* = @ptrCast(ptr);
                return;
            }
            std.debug.print("Warning: Failed to get {s}: {s}\n", .{name, c.dlerror()});
            return error.FailedToGetFunction;
        }
    }.load;
    
    // Load instance-level functions
    try loadFn(PFN_vkCreateInstance, "vkCreateInstance", &g_vkCreateInstance);
    try loadFn(PFN_vkEnumeratePhysicalDevices, "vkEnumeratePhysicalDevices", &g_vkEnumeratePhysicalDevices);
    try loadFn(PFN_vkGetPhysicalDeviceProperties, "vkGetPhysicalDeviceProperties", &g_vkGetPhysicalDeviceProperties);
    try loadFn(PFN_vkGetPhysicalDeviceQueueFamilyProperties, "vkGetPhysicalDeviceQueueFamilyProperties", &g_vkGetPhysicalDeviceQueueFamilyProperties);
    try loadFn(PFN_vkCreateDevice, "vkCreateDevice", &g_vkCreateDevice);
    try loadFn(PFN_vkGetDeviceQueue, "vkGetDeviceQueue", &g_vkGetDeviceQueue);
    try loadFn(PFN_vkDestroyDevice, "vkDestroyDevice", &g_vkDestroyDevice);
    try loadFn(PFN_vkDestroyInstance, "vkDestroyInstance", &g_vkDestroyInstance);
    
    // Verify all functions loaded
    if (g_vkCreateInstance == null or g_vkDestroyInstance == null or
        g_vkEnumeratePhysicalDevices == null or g_vkGetPhysicalDeviceProperties == null or
        g_vkGetPhysicalDeviceQueueFamilyProperties == null or g_vkCreateDevice == null or
        g_vkGetDeviceQueue == null or g_vkDestroyDevice == null) {
        return error.FailedToLoadVulkanFunctions;
    }
}

// Helper function to print device properties
fn printDeviceProperties(device: VkPhysicalDevice) void {
    var props: VkPhysicalDeviceProperties = undefined;
    g_vkGetPhysicalDeviceProperties.?(device, &props);
    
    const device_type = switch (props.deviceType) {
        .VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => "Integrated GPU",
        .VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => "Discrete GPU",
        .VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => "Virtual GPU",
        .VK_PHYSICAL_DEVICE_TYPE_CPU => "CPU",
        else => "Other",
    };
    
    std.debug.print("Device: {s}\n", .{std.mem.sliceTo(&props.deviceName, 0)});
    std.debug.print("  Type: {s}\n", .{device_type});
    std.debug.print("  API Version: {}.{}.{}\n", .{
        (props.apiVersion >> 22) & 0x3FF,
        (props.apiVersion >> 12) & 0x3FF,
        props.apiVersion & 0xFFF,
    });
    std.debug.print("  Driver Version: {}.{}.{}\n", .{
        (props.driverVersion >> 22) & 0x3FF,
        (props.driverVersion >> 12) & 0x3FF,
        props.driverVersion & 0xFFF,
    });
}

// Find a suitable queue family with the required capabilities
fn findQueueFamily(physical_device: VkPhysicalDevice, required_flags: VkQueueFlags) ?u32 {
    var queue_family_count: u32 = 0;
    g_vkGetPhysicalDeviceQueueFamilyProperties.?(physical_device, &queue_family_count, null);
    
    var queue_families: [16]VkQueueFamilyProperties = undefined;
    g_vkGetPhysicalDeviceQueueFamilyProperties.?(physical_device, &queue_family_count, &queue_families);
    
    for (0..queue_family_count) |i| {
        if (queue_families[i].queueFlags & @intFromEnum(required_flags) != 0) {
            return @intCast(i);
        }
    }
    
    return null;
}

pub fn main() !void {
    std.debug.print("Starting memory management example with direct Vulkan loading...\n", .{});
    
    // Initialize allocator
    std.debug.print("Initializing allocator...\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        std.debug.print("Deinitializing allocator...\n", .{});
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();
    _ = allocator; // Suppress unused variable warning
    
    // Load Vulkan
    try loadVulkan();
    
    // ===== 1. Create Vulkan Instance =====
    std.debug.print("\n===== Creating Vulkan Instance =====\n", .{});
    
    const app_name = try std.cstr.addNullByte(allocator, "Memory Management Example");
    defer allocator.free(app_name);
    const engine_name = try std.cstr.addNullByte(allocator, "No Engine");
    defer allocator.free(engine_name);
    
    const app_info = VkApplicationInfo{
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = @ptrCast(app_name),
        .applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
        .pEngineName = @ptrCast(engine_name),
        .engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
        .apiVersion = VK_API_VERSION_1_0,
    };
    
    const create_info = VkInstanceCreateInfo{
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = null,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = null,
    };
    
    var instance: VkInstance = undefined;
    const result = g_vkCreateInstance.?(create_info, null, &instance);
    
    if (result != VK_SUCCESS) {
        std.debug.print("Failed to create Vulkan instance: {}\n", .{result});
        return error.InstanceCreationFailed;
    }
    defer {
        std.debug.print("\nDestroying Vulkan instance...\n", .{});
        g_vkDestroyInstance.?(instance, null);
    }
    
    std.debug.print("Successfully created Vulkan instance!\n", .{});
    
    // ===== 2. Enumerate Physical Devices =====
    std.debug.print("\n===== Enumerating Physical Devices =====\n", .{});
    
    var device_count: u32 = 0;
    var enum_result = g_vkEnumeratePhysicalDevices.?(instance, &device_count, null);
    if (enum_result != VK_SUCCESS or device_count == 0) {
        std.debug.print("Failed to enumerate physical devices: {}\n", .{enum_result});
        return error.FailedToEnumeratePhysicalDevices;
    }
    
    std.debug.print("Found {} physical device(s)\n", .{device_count});
    
    var physical_devices: [16]VkPhysicalDevice = undefined;
    _ = g_vkEnumeratePhysicalDevices.?(instance, &device_count, &physical_devices);
    
    // Use the first physical device
    const physical_device = physical_devices[0];
    printDeviceProperties(physical_device);
    
    // ===== 3. Find a suitable queue family =====
    std.debug.print("\n===== Finding Queue Family =====\n", .{});
    
    const queue_family_index = findQueueFamily(physical_device, .VK_QUEUE_COMPUTE_BIT) orelse {
        std.debug.print("Failed to find a compute queue family\n", .{});
        return error.NoSuitableQueueFamily;
    };
    
    std.debug.print("Using queue family index: {}\n", .{queue_family_index});
    
    // ===== 4. Create Logical Device =====
    std.debug.print("\n===== Creating Logical Device =====\n", .{});
    
    const queue_priority: f32 = 1.0;
    const queue_create_info = VkDeviceQueueCreateInfo{
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueFamilyIndex = queue_family_index,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };
    
    const device_features = std.mem.zeroes(VkPhysicalDeviceFeatures);
    
    const device_create_info = VkDeviceCreateInfo{
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
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
    result = g_vkCreateDevice.?(\
        physical_device,
        &device_create_info,
        null,
        &device
    );
    
    if (result != .VK_SUCCESS) {
        std.debug.print("Failed to create logical device: {}\n", .{result});
        return error.FailedToCreateDevice;
    }
    defer {
        std.debug.print("\nDestroying logical device...\n", .{});
        g_vkDestroyDevice.?(device, null);
    }
    
    std.debug.print("Successfully created logical device!\n", .{});
    
    // ===== 5. Get Device Queue =====
    std.debug.print("\n===== Getting Device Queue =====\n", .{});
    
    var queue: VkQueue = undefined;
    g_vkGetDeviceQueue.?(device, queue_family_index, 0, &queue);
    std.debug.print("Successfully obtained device queue!\n", .{});
    
    // ===== 6. Cleanup is handled by defer statements =====
    std.debug.print("\n===== Example completed successfully! =====\n", .{});
}
