@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-19 15:40:58",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/glimmer/build.zig",
    "type": "zig",
    "hash": "ac927fc4b12a96cdd42543debd0dfa7e0e864657"
  }
}
@pattern_meta@

const std = @import("std");

// This is a module that can be imported by other Zig code
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // GLIMMER module
    const glimmer = b.addModule("glimmer", .{
        .root_source_file = .{ .path = "mod.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Example executable
    const exe = b.addExecutable(.{
        .name = "memory_visualization",
        .root_source_file = .{ .path = "../../examples/memory_visualization.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add GLIMMER module to the example
    exe.root_module.addImport("glimmer", glimmer);

    // Install the example
    b.installArtifact(exe);

    // Run the example
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the memory visualization example");
    run_step.dependOn(&run_cmd.step);
}
