const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "test-patterns",
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "" } },
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile(.{
        .file = .{ .src_path = .{ .owner = b, .sub_path = "src/quantum_cache/test_patterns.zig" } },
        .flags = &[_][]const u8{},
    });
    
    // Add the neural module
    const neural_mod = b.createModule(.{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/neural/mod.zig" } },
    });
    exe.*.addModule("neural", neural_mod);
    
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
