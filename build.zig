const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create and register modules
    const glimmer_module = b.addModule("glimmer", .{
        .root_source_file = .{ .cwd_relative = "src/glimmer/patterns.zig" },
        .imports = &.{
            .{ .name = "colors", .module = b.addModule("glimmer_colors", .{
                .root_source_file = .{ .cwd_relative = "src/glimmer/colors.zig" },
            })},
        },
    });

    const neural_module = b.addModule("neural", .{
        .root_source_file = .{ .cwd_relative = "src/neural/bridge.zig" },
    });

    const starweave_module = b.addModule("starweave", .{
        .root_source_file = .{ .cwd_relative = "src/starweave/protocol.zig" },
    });

    // Create library
    const lib = b.addStaticLibrary(.{
        .name = "maya",
        .root_source_file = .{ .cwd_relative = "src/core/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies to library
    lib.root_module.addImport("glimmer", glimmer_module);
    lib.root_module.addImport("neural", neural_module);
    lib.root_module.addImport("starweave", starweave_module);

    // Install the library
    b.installArtifact(lib);

    // Create main executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .cwd_relative = "src/core/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies to executable
    exe.root_module.addImport("glimmer", glimmer_module);
    exe.root_module.addImport("neural", neural_module);
    exe.root_module.addImport("starweave", starweave_module);

    b.installArtifact(exe);

    // Add tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/core/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies to tests
    main_tests.root_module.addImport("glimmer", glimmer_module);
    main_tests.root_module.addImport("neural", neural_module);
    main_tests.root_module.addImport("starweave", starweave_module);

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
} 