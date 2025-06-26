const std = @import("std");
const c = @cImport({
    @cInclude("dlfcn.h");
});

// Simple Vulkan test that just loads the library and gets the version
pub fn main() !void {
    std.debug.print("=== Simple Vulkan Test ===\n", .{});
    
    // Load the Vulkan library
    const libvulkan = c.dlopen("libvulkan.so.1", c.RTLD_LAZY | c.RTLD_LOCAL);
    if (libvulkan == null) {
        std.debug.print("Failed to load libvulkan.so.1: {s}\n", .{c.dlerror()});
        return error.FailedToLoadVulkan;
    }
    defer _ = c.dlclose(libvulkan);
    
    std.debug.print("1. Successfully loaded libvulkan.so.1\n", .{});
    
    // Get vkGetInstanceProcAddr
    const vkGetInstanceProcAddr = @as(
        ?*const fn (?*anyopaque, [*:0]const u8) callconv(.C) ?*anyopaque,
        @ptrCast(c.dlsym(libvulkan, "vkGetInstanceProcAddr"))
    );
    
    if (vkGetInstanceProcAddr == null) {
        std.debug.print("Failed to get vkGetInstanceProcAddr: {s}\n", .{c.dlerror()});
        return error.FailedToGetProcAddr;
    }
    
    std.debug.print("2. Got vkGetInstanceProcAddr\n", .{});
    
    // Get vkEnumerateInstanceVersion
    if (vkGetInstanceProcAddr) |getProcAddr| {
        const vkEnumerateInstanceVersion = @as(
            ?*const fn (*u32) callconv(.C) u32,
            @ptrCast(getProcAddr(null, "vkEnumerateInstanceVersion"))
        );
        
        if (vkEnumerateInstanceVersion) |func| {
            var api_version: u32 = 0;
            const result = func(&api_version);
            
            if (result == 0) { // VK_SUCCESS
                const major = (api_version >> 22) & 0x7F;
                const minor = (api_version >> 12) & 0x3FF;
                const patch = api_version & 0xFFF;
                std.debug.print("3. Vulkan API version: {}.{}.{}\n", .{major, minor, patch});
            } else {
                std.debug.print("3. Failed to get Vulkan version: {}\n", .{result});
            }
        } else {
            std.debug.print("3. vkEnumerateInstanceVersion not available, assuming Vulkan 1.0\n", .{});
        }
    }
    
    std.debug.print("Test completed successfully.\n", .{});
}
