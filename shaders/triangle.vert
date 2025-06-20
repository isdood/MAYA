@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-07 00:35:52",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./shaders/triangle.vert",
    "type": "vert",
    "hash": "8ff51be513852e1fc6e04a426cacc8a71ae598c0"
  }
}
@pattern_meta@

#version 450

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inColor;

layout(location = 0) out vec3 fragColor;

layout(binding = 0) uniform UniformBufferObject {
    mat4 rotation;
} ubo;

void main() {
    gl_Position = ubo.rotation * vec4(inPosition, 1.0);
    fragColor = inColor;
} 