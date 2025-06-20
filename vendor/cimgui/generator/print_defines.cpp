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
    "path": "./vendor/cimgui/generator/print_defines.cpp",
    "type": "cpp",
    "hash": "c57d25e438bac974e9f17ca0a597c1c1897b08d4"
  }
}
@pattern_meta@

#include "imgui.h"

#define CIMGUI_STRINGIZE_(x) #x
#define CIMGUI_STRINGIZE(x) CIMGUI_STRINGIZE_(x)
#define CIMGUI_DEFSTRING(x) "#define " #x " " CIMGUI_STRINGIZE(x)

#ifdef IMGUI_VERSION
#pragma message(CIMGUI_DEFSTRING(IMGUI_VERSION))
#endif

#ifdef IMGUI_VERSION_NUM
#pragma message(CIMGUI_DEFSTRING(IMGUI_VERSION_NUM))
#endif

#ifdef IMGUI_HAS_DOCK
#pragma message(CIMGUI_DEFSTRING(IMGUI_HAS_DOCK))
#endif

#ifdef IMGUI_HAS_IMSTR
#pragma message(CIMGUI_DEFSTRING(IMGUI_HAS_IMSTR))
#endif

#ifdef FLT_MIN
#pragma message(CIMGUI_DEFSTRING(FLT_MIN))
#endif

#ifdef FLT_MAX
#pragma message(CIMGUI_DEFSTRING(FLT_MAX))
#endif

#ifdef ImDrawCallback_ResetRenderState
#pragma message(CIMGUI_DEFSTRING(ImDrawCallback_ResetRenderState))
#endif

#ifdef IMGUI_HAS_TEXTURES
#pragma message(CIMGUI_DEFSTRING(IMGUI_HAS_TEXTURES))
#endif