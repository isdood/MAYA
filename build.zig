const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add include paths
    exe.addIncludePath(.{ .path = "src" });

    // Create and add modules
    const starweave_mod = b.createModule(.{
        .source_file = .{ .path = "src/starweave/protocol.zig" },
    });
    const glimmer_mod = b.createModule(.{
        .source_file = .{ .path = "src/glimmer/mod.zig" },
    });
    const neural_mod = b.createModule(.{
        .source_file = .{ .path = "src/neural/mod.zig" },
    });
    const colors_mod = b.createModule(.{
        .source_file = .{ .path = "src/glimmer/colors.zig" },
    });

    // Add modules to the executable
    exe.addModule("starweave", starweave_mod);
    exe.addModule("glimmer", glimmer_mod);
    exe.addModule("neural", neural_mod);
    exe.addModule("colors", colors_mod);

    // Install the executable
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    
    // Main tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "test/neural_bridge_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add modules to tests
    main_tests.addModule("neural", neural_mod);
    
    // Add include paths
    main_tests.addIncludePath(.{ .path = "src" });
    
    // Create test run step
    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);
    
    // Add neural bridge unit tests
    const neural_bridge_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/neural/neural_bridge.zig" },
        .target = target,
        .optimize = optimize,
    });
    neural_bridge_tests.addModule("neural", neural_mod);
    neural_bridge_tests.addIncludePath(.{ .path = "src" });
    const run_neural_bridge_tests = b.addRunArtifact(neural_bridge_tests);
    test_step.dependOn(&run_neural_bridge_tests.step);
}