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
    "path": "./vendor/cimgui/test/CMakeLists.txt",
    "type": "txt",
    "hash": "944480ec8d30c923f2a32a7fc22673d347fa0400"
  }
}
@pattern_meta@

file(GLOB CIMGUI_TEST_SOURCES
    main.c
)

add_executable(cimgui_test ${CIMGUI_TEST_SOURCES})

set_target_properties(cimgui_test PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set_property(TARGET cimgui_test PROPERTY C_STANDARD 99)

target_compile_definitions(cimgui_test PRIVATE CIMGUI_DEFINE_ENUMS_AND_STRUCTS=1)
target_link_libraries(cimgui_test PRIVATE cimgui)
