const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const ShaderModule = struct {
    device: vk.VkDevice,
    handle: vk.VkShaderModule,

    pub fn init(device: vk.VkDevice, code: []const u8) !ShaderModule {
        const create_info = vk.VkShaderModuleCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = code.len,
            .pCode = @ptrCast(@alignCast(code.ptr)),
            .pNext = null,
            .flags = 0,
        };

        var shader_module: vk.VkShaderModule = undefined;
        if (vk.vkCreateShaderModule(device, &create_info, null, &shader_module) != vk.VK_SUCCESS) {
            return error.ShaderModuleCreationFailed;
        }

        return ShaderModule{
            .device = device,
            .handle = shader_module,
        };
    }

    pub fn deinit(self: *ShaderModule) void {
        vk.vkDestroyShaderModule(self.device, self.handle, null);
    }

    pub fn loadFromFile(device: vk.VkDevice, path: []const u8) !ShaderModule {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try std.heap.page_allocator.alloc(u8, file_size);
        defer std.heap.page_allocator.free(buffer);

        const bytes_read = try file.readAll(buffer);
        if (bytes_read != file_size) {
            return error.FileReadIncomplete;
        }

        return ShaderModule.init(device, buffer);
    }
}; 