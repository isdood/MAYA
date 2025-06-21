const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the starweave module
    const starweave_mod = b.createModule(.{
        .source_file = .{ .path = "src/starweave/protocol.zig" },
    });

    // Create the quantum processor module
    const quantum_processor_mod = b.createModule(.{
        .source_file = .{ .path = "src/neural/quantum_processor.zig" },
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add the modules
    exe.addModule("starweave", starweave_mod);
    exe.addModule("quantum_processor", quantum_processor_mod);

    // Install the executable
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    test_exe.addModule("starweave", starweave_mod);
    test_exe.addModule("quantum_processor", quantum_processor_mod);

    const test_cmd = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_cmd.step);
}