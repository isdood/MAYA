const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Create the Vulkan test executable
    const vk_test = b.addExecutable(.{
        .name = "vk_test",
        .root_source_file = .{ .cwd_relative = "vk_final.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link against Vulkan and dl
    vk_test.linkSystemLibrary("vulkan");
    vk_test.linkSystemLibrary("dl");
    
    // Add the install step
    b.installArtifact(vk_test);
    
    // Create run step
    const run_vk_test = b.addRunArtifact(vk_test);
    
    // Add run step
    const run_vk_test_step = b.step("run", "Run the Vulkan test");
    run_vk_test_step.dependOn(&run_vk_test.step);
}
