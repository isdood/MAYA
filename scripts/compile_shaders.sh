@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-08 11:59:16",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./scripts/compile_shaders.sh",
    "type": "sh",
    "hash": "f95bb71f4333f6487d5cdcae0a9c0127c67d9869"
  }
}
@pattern_meta@

#!/bin/bash

# Create output directory if it doesn't exist
mkdir -p shaders/spv

# Compile vertex shader
glslc shaders/triangle.vert -o shaders/spv/triangle.vert.spv

# Compile fragment shader
glslc shaders/triangle.frag -o shaders/spv/triangle.frag.spv 