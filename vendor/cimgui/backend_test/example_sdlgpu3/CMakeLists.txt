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
    "path": "./vendor/cimgui/backend_test/example_sdlgpu3/CMakeLists.txt",
    "type": "txt",
    "hash": "063e5aa1f0ba2f234543e53fb90776a4b1593846"
  }
}
@pattern_meta@

cmake_minimum_required(VERSION 3.30)
project(cimgui_sdlgpu3 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)

include(FetchContent)

FetchContent_Declare(
	sdl3
	URL https://github.com/libsdl-org/SDL/releases/download/release-3.2.8/SDL3-3.2.8.tar.gz
)

set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(sdl3)

include(../cmake/GenerateCimguiBindings.cmake)

set(inclulist ${sdl3_SOURCE_DIR}/include)
GenerateCimguiBindings(cimgui_with_backend sdl3 sdlgpu3 inclulist)
target_link_libraries(cimgui_with_backend PRIVATE SDL3::SDL3)

add_executable(${PROJECT_NAME} 
	main.c
)

target_link_libraries(${PROJECT_NAME} PRIVATE SDL3::SDL3 cimgui_with_backend)
target_compile_definitions(
	${PROJECT_NAME}
	PRIVATE 
	CIMGUI_DEFINE_ENUMS_AND_STRUCTS=1
	CIMGUI_USE_SDL3=1
	CIMGUI_USE_SDLGPU3=1
)
