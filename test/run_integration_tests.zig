
const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "integration_tests",
        .root_source_file = .{ .cwd_relative = "test/integration/neural_quantum_visual_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add the neural module
    const neural_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/mod.zig" },
    });
    exe.root_module.addImport("neural", neural_mod);

    const run_cmd = b.addRunArtifact(exe);
    
    const test_step = b.step("test", "Run integration tests");
    test_step.dependOn(&run_cmd.step);
}
