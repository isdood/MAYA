@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 10:39:57",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./test/run_integration_tests.zig",
    "type": "zig",
    "hash": "a4bf4790b0f91c5b7838c6f35b6cec20f6130272"
  }
}
@pattern_meta@

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
