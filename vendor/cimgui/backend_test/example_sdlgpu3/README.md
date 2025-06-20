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
    "path": "./vendor/cimgui/backend_test/example_sdlgpu3/README.md",
    "type": "md",
    "hash": "7e95525687aa9a2ebaf6f1d60c8f60408c3bf3f1"
  }
}
@pattern_meta@

# SDLGPU3

This example is a little different from the others, because `cimgui` doesn't come with bindings for the SDLGPU3 backend out of the box. Instead, this example shows how to generate the necessary bindings during cmake's configure time, then add the compiled library as a target for your application to link to.

For the generation phase from cmake you need LuaJIT to be present.

## Building

From the build directory of your choice:

`cmake path_to_example_sdlgpu3`

and after

`make`

