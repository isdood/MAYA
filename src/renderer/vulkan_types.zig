pub const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const VkDevice = ?*vk.VkDevice_T; 