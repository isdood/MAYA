#!/bin/bash

# Create output directory if it doesn't exist
mkdir -p shaders/spv

# Compile pattern matching shader
glslangValidator -V shaders/pattern_matching.comp -o shaders/spv/pattern_matching.comp.spv

# Make the script executable
chmod +x compile_shaders.sh
