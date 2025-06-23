const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    
    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});
    
    // Create executable
    const exe = b.addExecutable("test-patterns", null);
    exe.addCSourceFile("src/quantum_cache/test_patterns.zig", &[0][]const u8{});
    exe.setTarget(target);
    exe.setBuildMode(optimize);
    
    // Install the executable
    b.installArtifact(exe);
    
    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
