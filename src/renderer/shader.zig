
const std = @import("std");
const vk_types = @import("vulkan_types.zig");
const vk = vk_types.vk;
const fs = std.fs;
const log = std.log;

pub const ShaderError = error{
    FileNotFound,
    FileReadError,
    InvalidShaderCode,
    ShaderModuleCreationFailed,
    ShaderCompilationFailed,
};

pub const ShaderModule = struct {
    device: vk_types.VkDevice,
    handle: vk.VkShaderModule,
    path: []const u8,
    last_modified: i64,
    stage: vk.VkShaderStageFlagBits,
    allocator: std.mem.Allocator,

    pub fn init(device: vk_types.VkDevice, code: []const u8, path: []const u8, stage: vk.VkShaderStageFlagBits, allocator: std.mem.Allocator) !ShaderModule {
        const create_info = vk.VkShaderModuleCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = code.len,
            .pCode = @ptrCast(@alignCast(code.ptr)),
            .pNext = null,
            .flags = 0,
        };

        var shader_module: vk.VkShaderModule = undefined;
        if (vk.vkCreateShaderModule(device, &create_info, null, &shader_module) != vk.VK_SUCCESS) {
            return ShaderError.ShaderModuleCreationFailed;
        }

        const file = try fs.cwd().openFile(path, .{});
        defer file.close();
        const stat = try file.stat();

        return ShaderModule{
            .device = device,
            .handle = shader_module,
            .path = try allocator.dupe(u8, path),
            .last_modified = stat.mtime,
            .stage = stage,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ShaderModule) void {
        vk.vkDestroyShaderModule(self.device, self.handle, null);
        self.allocator.free(self.path);
    }

    pub fn loadFromFile(device: vk_types.VkDevice, path: []const u8, stage: vk.VkShaderStageFlagBits, allocator: std.mem.Allocator) !ShaderModule {
        const file = try fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        const bytes_read = try file.readAll(buffer);
        if (bytes_read != file_size) {
            return ShaderError.FileReadError;
        }

        return ShaderModule.init(device, buffer, path, stage, allocator);
    }

    pub fn checkForUpdates(self: *ShaderModule) !bool {
        const file = try fs.cwd().openFile(self.path, .{});
        defer file.close();
        const stat = try file.stat();

        if (stat.mtime > self.last_modified) {
            // File has been modified, reload shader
            const file_size = try file.getEndPos();
            const buffer = try self.allocator.alloc(u8, file_size);
            defer self.allocator.free(buffer);

            const bytes_read = try file.readAll(buffer);
            if (bytes_read != file_size) {
                return ShaderError.FileReadError;
            }

            // Create new shader module
            const create_info = vk.VkShaderModuleCreateInfo{
                .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = buffer.len,
                .pCode = @ptrCast(@alignCast(buffer.ptr)),
                .pNext = null,
                .flags = 0,
            };

            var new_shader_module: vk.VkShaderModule = undefined;
            if (vk.vkCreateShaderModule(self.device, &create_info, null, &new_shader_module) != vk.VK_SUCCESS) {
                return ShaderError.ShaderModuleCreationFailed;
            }

            // Clean up old shader module
            vk.vkDestroyShaderModule(self.device, self.handle, null);
            self.handle = new_shader_module;
            self.last_modified = stat.mtime;

            return true;
        }

        return false;
    }
};

pub const ShaderManager = struct {
    shaders: std.ArrayList(ShaderModule),
    device: vk_types.VkDevice,
    allocator: std.mem.Allocator,

    pub fn init(device: vk_types.VkDevice, allocator: std.mem.Allocator) !ShaderManager {
        return ShaderManager{
            .shaders = std.ArrayList(ShaderModule).init(allocator),
            .device = device,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ShaderManager) void {
        for (self.shaders.items) |*shader| {
            shader.deinit();
        }
        self.shaders.deinit();
    }

    pub fn loadShader(self: *ShaderManager, path: []const u8, stage: vk.VkShaderStageFlagBits) !void {
        const shader = try ShaderModule.loadFromFile(self.device, path, stage, self.allocator);
        try self.shaders.append(shader);
    }

    pub fn checkForUpdates(self: *ShaderManager) !void {
        for (self.shaders.items) |*shader| {
            _ = try shader.checkForUpdates();
        }
    }
}; 
