@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-08 11:38:36",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/renderer/vulkan_types.zig",
    "type": "zig",
    "hash": "60f583e044d318139532093a91397fd136a4db3b"
  }
}
@pattern_meta@

pub const vk = @cImport({
    @cDefine("VK_USE_PLATFORM_XCB_KHR", "1");
    @cInclude("vulkan/vulkan.h");
});

pub const VkDevice = ?*vk.VkDevice_T; 