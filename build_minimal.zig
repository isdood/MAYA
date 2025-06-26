const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable("vulkan_test", null);
    exe.addCSourceFile("src/vulkan/test_minimal.zig", &[0][]const u8{});
    exe.setTarget(target);
    exe.setBuildMode(optimize);
    
    // Link against the Vulkan loader
    exe.linkSystemLibrary("vulkan");
    
    // Add include paths
    exe.addIncludePath("/usr/include");
    exe.addIncludePath("/usr/include/vulkan");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("test-vulkan", "Run the minimal Vulkan test");
    run_step.dependOn(&run_cmd.step);
}
