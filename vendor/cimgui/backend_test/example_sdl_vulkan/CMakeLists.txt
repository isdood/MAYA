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
    "path": "./vendor/cimgui/backend_test/example_sdl_vulkan/CMakeLists.txt",
    "type": "txt",
    "hash": "7a9dadfaa60fd3274847604d53eb1fdaa67a8cf0"
  }
}
@pattern_meta@

Project(cimgui_sdl_vk)
cmake_minimum_required(VERSION 2.8)
if(WIN32) # to make mingw work as all the others
set(CMAKE_SHARED_LIBRARY_PREFIX "")
endif(WIN32)
# general settings


if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/../../imgui/backends)
	set(BACKENDS_FOLDER "../../imgui/backends/")
else()
	set(BACKENDS_FOLDER "../../imgui/examples/")
endif()

if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/../../imgui/imgui_tables.cpp)
	set(TABLES_SOURCE "../../imgui/imgui_tables.cpp")
else()
	set(TABLES_SOURCE "")
endif()

include_directories(../../imgui ../../imgui/backends)


include_directories(../../)
set(IMGUI_SOURCES ../../cimgui.cpp
../../cimgui_impl.cpp
../../imgui/imgui.cpp
../../imgui/imgui_draw.cpp
../../imgui/imgui_demo.cpp
../../imgui/imgui_widgets.cpp
${TABLES_SOURCE}
)

set(IMGUI_SOURCES_sdl)
set(IMGUI_LIBRARIES )


#optional adding freetype
option(IMGUI_FREETYPE "add Freetype2" OFF)

if(IMGUI_FREETYPE)
	FIND_PACKAGE(freetype REQUIRED PATHS ${FREETYPE_PATH})
	list(APPEND IMGUI_LIBRARIES freetype)
	list(APPEND IMGUI_SOURCES ../../imgui/misc/freetype/imgui_freetype.cpp)
	add_definitions("-DCIMGUI_FREETYPE=1")
endif(IMGUI_FREETYPE)

# vulkan
find_package(Vulkan REQUIRED FATAL_ERROR)
list(APPEND IMGUI_LIBRARIES Vulkan::Vulkan)
list(APPEND IMGUI_SOURCES ${BACKENDS_FOLDER}imgui_impl_vulkan.cpp)
include_directories(${Vulkan_INCLUDE_DIRS})

#sdl2
list(APPEND IMGUI_SOURCES ${BACKENDS_FOLDER}imgui_impl_sdl2.cpp)
include(FetchContent)
Set(FETCHCONTENT_QUIET FALSE)

FetchContent_Declare(
        SDL2
        GIT_REPOSITORY https://github.com/libsdl-org/SDL.git
        GIT_TAG release-2.30.12
        #GIT_SHALLOW TRUE
        GIT_PROGRESS TRUE
)
FetchContent_GetProperties(SDL2)
if (NOT sdl2_POPULATED)
	set(FETCHCONTENT_QUIET NO)
    FetchContent_Populate(SDL2)
	set(SDL_TEST OFF CACHE BOOL "" FORCE)
	set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
	add_subdirectory(${sdl2_SOURCE_DIR} ${sdl2_BINARY_DIR})
endif()
include_directories(${SDL2_SOURCE_DIR}/include)


#if dynamic SDL2 then install
# install(TARGETS SDL2 RUNTIME DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
					# LIBRARY DESTINATION ${CMAKE_CURRENT_BINARY_DIR}
# )

add_library(cimgui_sdl STATIC ${IMGUI_SOURCES})
target_compile_definitions(cimgui_sdl PUBLIC "-DIMGUI_USER_CONFIG=\"../cimconfig.h\"")
target_compile_definitions(cimgui_sdl PUBLIC "-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1")
target_compile_definitions(cimgui_sdl PUBLIC -DCIMGUI_USE_VULKAN -DCIMGUI_USE_SDL2)
if (WIN32)
    target_compile_definitions(cimgui_sdl PUBLIC "-DIMGUI_IMPL_API=extern \"C\" __declspec\(dllexport\)")
else(WIN32)
    target_compile_definitions(cimgui_sdl PUBLIC "-DIMGUI_IMPL_API=extern \"C\" ")
endif(WIN32)
#target_link_libraries(cimgui_sdl ${IMGUI_LIBRARIES} SDL2-static)

#using library
add_executable(test_sdl main.c)
target_compile_definitions(test_sdl PUBLIC -DCIMGUI_USE_VULKAN -DCIMGUI_USE_SDL2)
if (MINGW)
target_link_options(test_sdl PRIVATE "-mconsole")
endif()
target_link_libraries(test_sdl SDL2-static cimgui_sdl ${IMGUI_LIBRARIES})

