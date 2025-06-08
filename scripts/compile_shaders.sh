#!/bin/bash

# Create output directory if it doesn't exist
mkdir -p shaders/spv

# Compile vertex shader
glslc shaders/triangle.vert -o shaders/spv/triangle.vert.spv

# Compile fragment shader
glslc shaders/triangle.frag -o shaders/spv/triangle.frag.spv 