const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the executable
    const exe = b.addExecutable("test-patterns", null);
    exe.addCSourceFile("src/quantum_cache/test_patterns.zig", &[_][]const u8{});
    exe.setTarget(target);
    exe.setBuildMode(optimize);
    
    // Add the neural module
    const neural_mod = b.createModule(.{
        .source = .{ .path = "src/neural/mod.zig" },
    });
    exe.addModule("neural", neural_mod);
    
    // Install the executable
    b.installArtifact(exe);
    
    // Add a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    // Create run step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    
    // Create test-patterns step for backward compatibility
    const test_patterns_step = b.step("test-patterns", "Run test patterns for QuantumCache");
    test_patterns_step.dependOn(&run_cmd.step);
}
