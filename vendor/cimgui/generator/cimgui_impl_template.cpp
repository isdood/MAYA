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
    "path": "./vendor/cimgui/generator/cimgui_impl_template.cpp",
    "type": "cpp",
    "hash": "8c8aab9377688b20c42273440012b9fbae4eee94"
  }
}
@pattern_meta@

#include "./imgui/imgui.h"
#ifdef IMGUI_ENABLE_FREETYPE
#include "./imgui/misc/freetype/imgui_freetype.h"
#endif
#include "./imgui/imgui_internal.h"
#include "cimgui.h"

GENERATED_PLACEHOLDER

#include "cimgui_impl.h"

#ifdef CIMGUI_USE_VULKAN

CIMGUI_API ImGui_ImplVulkanH_Window* ImGui_ImplVulkanH_Window_ImGui_ImplVulkanH_Window()
{
	return IM_NEW(ImGui_ImplVulkanH_Window)();
}
CIMGUI_API void ImGui_ImplVulkanH_Window_Construct(ImGui_ImplVulkanH_Window* self)
{
	IM_PLACEMENT_NEW(self) ImGui_ImplVulkanH_Window();
}

#endif
