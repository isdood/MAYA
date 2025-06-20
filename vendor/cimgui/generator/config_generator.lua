@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 16:11:37",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./vendor/cimgui/generator/config_generator.lua",
    "type": "lua",
    "hash": "f8e1cbb0aa1d470204f2deac83bf012c6536db98"
  }
}
@pattern_meta@

return {
	vulkan = {(os.getenv("VULKAN_SDK") or "vulkan_SDK_not_found").."/Include"}, --{[[C:\VulkanSDK\1.3.216.0\Include]]}
} 