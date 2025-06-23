const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable("test-patterns", null);
    exe.addCSourceFile("src/quantum_cache/test_patterns.zig", &[0][]const u8{});
    exe.setTarget(target);
    exe.setBuildMode(mode);
    
    // Add include paths
    exe.addIncludePath("src");
    
    // Link against libc if needed
    exe.linkLibC();
    
    // Install the executable
    b.installArtifact(exe);
    
    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    // Create a run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
