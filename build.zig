const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create modules first
    const glimmer_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/glimmer/colors.zig" },
    });
    b.addModule("glimmer", glimmer_module);

    const neural_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/bridge.zig" },
    });
    b.addModule("neural", neural_module);

    const starweave_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/starweave/protocol.zig" },
    });
    b.addModule("starweave", starweave_module);

    // Create library
    const lib = b.addStaticLibrary(.{
        .name = "maya",
        .root_source_file = .{ .cwd_relative = "src/core/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Install the library
    b.installArtifact(lib);

    // Create main executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .cwd_relative = "src/core/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Add tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/core/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
} 