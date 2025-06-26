#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <math.h>
#include <stdint.h>

// Golden ratio constant for Fibonacci spiral
#define GOLDEN_RATIO 1.618033988749895f

// 4D vector structure matching our Zig implementation
typedef struct {
    float x, y, z, w;
} Vec4;

// Spiral convolution kernel
__global__ void spiral_convolution_4d(
    const float* __restrict__ input,
    float* __restrict__ output,
    const int width,
    const int height,
    const int depth,
    const int time_steps,
    const int channels,
    const Vec4 scale,
    const Vec4 rotation,
    const Vec4 translation,
    const bool use_gravity_well,
    const Vec4 well_center,
    const float well_mass,
    const float well_radius,
    const bool use_spiral,
    const int spiral_turns,
    const float spiral_phase
) {
    // Calculate 4D coordinates from thread and block indices
    const int x = blockIdx.x * blockDim.x + threadIdx.x;
    const int y = blockIdx.y * blockDim.y + threadIdx.y;
    const int z = blockIdx.z * blockDim.z + threadIdx.z;
    const int t = blockIdx.w * blockDim.w + threadIdx.w;
    
    // Check bounds
    if (x >= width || y >= height || z >= depth || t >= time_steps) {
        return;
    }
    
    // Convert to normalized coordinates [-1, 1]
    Vec4 pos;
    pos.x = 2.0f * (x / (float)(width - 1)) - 1.0f;
    pos.y = 2.0f * (y / (float)(height - 1)) - 1.0f;
    pos.z = 2.0f * (z / (float)(depth - 1)) - 1.0f;
    pos.w = 2.0f * (t / (float)(time_steps - 1)) - 1.0f;
    
    // Apply gravity well if enabled
    if (use_gravity_well) {
        // Calculate vector to center
        Vec4 to_center = {
            well_center.x - pos.x,
            well_center.y - pos.y,
            well_center.z - pos.z,
            well_center.w - pos.w
        };
        
        // Calculate distance squared
        float dist_sq = to_center.x * to_center.x +
                       to_center.y * to_center.y +
                       to_center.z * to_center.z +
                       to_center.w * to_center.w;
        float dist = sqrtf(dist_sq);
        
        if (dist <= well_radius && dist > 0.0001f) {
            // Apply inverse square law force
            float strength = well_mass / (dist_sq + 0.01f);
            
            // Normalize and scale
            float inv_dist = 1.0f / dist;
            to_center.x *= inv_dist;
            to_center.y *= inv_dist;
            to_center.z *= inv_dist;
            to_center.w *= inv_dist;
            
            // Apply force
            float force_scale = strength * (1.0f - dist / well_radius);
            pos.x += to_center.x * force_scale;
            pos.y += to_center.y * force_scale;
            pos.z += to_center.z * force_scale;
            pos.w += to_center.w * force_scale;
        }
    }
    
    // Apply spiral processing if enabled
    if (use_spiral) {
        // Calculate spiral coordinates
        float t_spiral = (t * depth * height * width + z * height * width + y * width + x) / 
                        (float)(time_steps * depth * height * width);
        
        float angle = 2.0f * M_PI * t_spiral * spiral_turns + spiral_phase;
        float r = t_spiral;
        
        // Add spiral offset
        pos.x += r * sinf(angle) * 0.1f;
        pos.y += r * cosf(angle) * 0.1f;
        pos.z += r * sinf(angle * GOLDEN_RATIO) * 0.1f;
        pos.w += r * cosf(angle * GOLDEN_RATIO) * 0.1f;
    }
    
    // Apply scaling
    pos.x *= scale.x;
    pos.y *= scale.y;
    pos.z *= scale.z;
    pos.w *= scale.w;
    
    // Apply rotation (simplified - should use quaternions for 3D rotations)
    // TODO: Implement proper 4D rotations
    
    // Apply translation
    pos.x += translation.x;
    pos.y += translation.y;
    pos.z += translation.z;
    pos.w += translation.w;
    
    // Convert back to source coordinates
    int src_x = (int)((pos.x * 0.5f + 0.5f) * (width - 1) + 0.5f);
    int src_y = (int)((pos.y * 0.5f + 0.5f) * (height - 1) + 0.5f);
    int src_z = (int)((pos.z * 0.5f + 0.5f) * (depth - 1) + 0.5f);
    int src_t = (int)((pos.w * 0.5f + 0.5f) * (time_steps - 1) + 0.5f);
    
    // Clamp coordinates
    src_x = max(0, min(width - 1, src_x));
    src_y = max(0, min(height - 1, src_y));
    src_z = max(0, min(depth - 1, src_z));
    src_t = max(0, min(time_steps - 1, src_t));
    
    // Copy data from source to destination
    const int src_idx = ((src_t * depth + src_z) * height + src_y) * width + src_x;
    const int dst_idx = ((t * depth + z) * height + y) * width + x;
    
    for (int c = 0; c < channels; c++) {
        output[dst_idx * channels + c] = input[src_idx * channels + c];
    }
}

// Helper functions for CUDA
__device__ int max(int a, int b) { return (a > b) ? a : b; }
__device__ int min(int a, int b) { return (a < b) ? a : b; }

// C++ wrapper function
extern "C" void launch_spiral_convolution_4d(
    const float* input,
    float* output,
    int width,
    int height,
    int depth,
    int time_steps,
    int channels,
    const Vec4& scale,
    const Vec4& rotation,
    const Vec4& translation,
    bool use_gravity_well,
    const Vec4& well_center,
    float well_mass,
    float well_radius,
    bool use_spiral,
    int spiral_turns,
    float spiral_phase,
    cudaStream_t stream = 0
) {
    // Set up block and grid dimensions
    const int block_size = 8;
    dim3 block(block_size, block_size, 1);
    dim3 grid(
        (width + block_size - 1) / block_size,
        (height + block_size - 1) / block_size,
        (depth * time_steps + block_size - 1) / block_size
    );
    
    // Launch kernel
    spiral_convolution_4d<<<grid, block, 0, stream>>>(
        input, output, width, height, depth, time_steps, channels,
        scale, rotation, translation, use_gravity_well, well_center,
        well_mass, well_radius, use_spiral, spiral_turns, spiral_phase
    );
}

// Helper function to get the last CUDA error
const char* get_last_cuda_error() {
    cudaError_t error = cudaGetLastError();
    return cudaGetErrorString(error);
}
