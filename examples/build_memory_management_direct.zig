const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const exe = b.addExecutable(.{
        .name = "memory_management_direct",
        .root_source_file = .{ .cwd_relative = "memory_management_direct.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link against the Vulkan loader and dl
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("dl");
    
    // Install the executable
    b.installArtifact(exe);
    
    // Add a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
