const std = @import("std");
const gpu = @import("gpu");

pub fn main() !void {
    std.debug.print("GPU runner initialized. ROCm support: {}\n", .{gpu.has_rocm_support});
    
    if (gpu.has_rocm_support) {
        std.debug.print("ROCm is available!\n", .{});
        // Initialize ROCm and run your GPU code here
    } else {
        std.debug.print("ROCm is not available. Falling back to CPU.\n", .{});
    }
}
