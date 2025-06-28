const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Create the Vulkan minimal working example
    const vk_minimal = b.addExecutable(.{
        .name = "vk_minimal_working",
        .root_source_file = .{ .cwd_relative = "vk_minimal_working.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link against Vulkan and dl
    vk_minimal.linkSystemLibrary("vulkan");
    vk_minimal.linkSystemLibrary("dl");
    
    // Add the install step
    b.installArtifact(vk_minimal);
    
    // Create run step
    const run_vk_minimal = b.addRunArtifact(vk_minimal);
    
    // Add run step
    const run_vk_minimal_step = b.step("run", "Run the Vulkan minimal working example");
    run_vk_minimal_step.dependOn(&run_vk_minimal.step);
}
