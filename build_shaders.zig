const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a step to copy shaders
    const shaders_step = b.step("shaders", "Copy shader files to build directory");
    
    const shader_files = [_][]const u8{
        "shaders/4d_tensor_operations_float.comp.spv",
        "shaders/4d_tensor_operations_int.comp.spv",
        "shaders/4d_tensor_operations_uint.comp.spv",
    };
    
    for (shader_files) |shader| {
        const shader_install = b.addInstallFile(
            .{ .path = shader },
            "zig-out/" ++ shader,
        );
        shaders_step.dependOn(&shader_install.step);
    }
    
    // Add a default step
    const default_step = b.step("default", "Default build step");
    default_step.dependOn(shaders_step);
}
