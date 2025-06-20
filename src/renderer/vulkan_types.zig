
pub const vk = @cImport({
    @cDefine("VK_USE_PLATFORM_XCB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});

pub const VkDevice = ?*vk.VkDevice_T; 
