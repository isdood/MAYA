@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-06 13:15:59",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./shaders/triangle.frag",
    "type": "frag",
    "hash": "cf6c137b3afb64a1d46276774e61f3de77a145c2"
  }
}
@pattern_meta@

#version 450

layout(location = 0) in vec3 fragColor;
layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(fragColor, 1.0);
} 