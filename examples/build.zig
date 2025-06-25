const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "temporal_processing",
        .root_source_file = .{ .cwd_relative = "temporal_processing.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add all source files
    const src_dir = "../src/neural/";
    const src_files = [_][]const u8{
        src_dir ++ "tensor4d.zig",
        src_dir ++ "attention.zig",
        src_dir ++ "quantum_tunneling.zig",
        src_dir ++ "temporal.zig",
        src_dir ++ "hypercube_bridge.zig",
    };
    
    for (src_files) |src_file| {
        exe.addCSourceFile(.{
            .file = .{ .cwd_relative = src_file },
            .flags = &[_][]const u8{},
        });
    }

    // Install the executable
    b.installArtifact(exe);

    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Add run step
    const run_step = b.step("run", "Run the temporal processing example");
    run_step.dependOn(&run_cmd.step);
}
