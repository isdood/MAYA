@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 08:50:30",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./run_memory_vis.zig",
    "type": "zig",
    "hash": "71e54f2afa32885308187456fe4a7c27f6ad52b9"
  }
}
@pattern_meta@

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create modules
    const starweave_mod = b.createModule({
        .source_file = .{ .path = "src/starweave/protocol.zig" },
    });

    const glimmer_mod = b.createModule({
        .source_file = .{ .path = "src/glimmer/mod.zig" },
        .dependencies = &.{
            .{ .name = "starweave", .module = starweave_mod },
        },
    });

    // Create executable
    const exe = b.addExecutable({
        .name = "memory_visualization",
        .root_source_file = .{ .path = "examples/memory_visualization.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add module dependencies
    exe.root_module.addImport("glimmer", glimmer_mod);
    exe.root_module.addImport("starweave", starweave_mod);

    // Install the executable
    b.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create a run step
    const run_step = b.step("run", "Run the memory visualization");
    run_step.dependOn(&run_cmd.step);
}
