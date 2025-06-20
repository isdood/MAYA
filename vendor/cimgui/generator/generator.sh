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
    "path": "./vendor/cimgui/generator/generator.sh",
    "type": "sh",
    "hash": "c9356e37de3e17994a570ec4b47039ae0452c3a2"
  }
}
@pattern_meta@

#!/bin/bash

# this script must be executed in this directory
# all the output goes to generator/output folder
# .cpp and .h files:
# cimgui.h and cimgui.cpp with gcc preprocess
# cimgui_nopreprocess.h and cimgui_nopreprocess.cpp generated without preprocess
# cimgui_impl.h with implementation function cdefs
# lua and json files:
# definitions.lua for function definitions
# structs_and_enums.lua with struct and enum information-definitions
# impl_definitions.lua for implementation function definitions

#process  files
# arg[1] compiler name gcc, clang, or cl
# arg[2] options as words in one string: internal for imgui_internal generation, comments for comments generation, nochar to skip char* function version, noimstrv to skip imstrv
# "constructors" adds the _Construct version of constructors
# examples: "" "internal" "comments internal"
# arg[3..n] name of implementations to generate and/or CLFLAGS (e.g. -DIMGUI_USER_CONFIG)
# -DIMGUI_USE_WCHAR32 should not be used as it is generated for both ImWchar
#

# parse command line arguments
# ref: https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL_ARGS=()

TARGETS="internal noimstrv"
CFLAGS="glfw opengl3 opengl2 sdl2 sdl3"

help() {
        cat <<EOF
Usage of generator.sh:
   -t --target    specify which imgui features should be generated
                  (default: $TARGETS)
   -c --cflags    specify additional gcc flags
                  (default: $CFLAGS
   -h --help      show this message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--cflags)
      CFLAGS="$2"
      shift # past argument
      shift # past value
      ;;
    -t|--target)
      TARGETS="$2"
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      help
      exit 0
      ;;
    -*|--*)
      echo "Unknown option $1"
      help
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]];
# then
#   suffix='.exe'
# fi

echo "CFLAGS: " $CFLAGS
echo "TARGETS: " $TARGETS

luajit$suffix ./generator.lua gcc "$TARGETS" $CFLAGS
