const std = @import("std");

pub fn build(b: *std.Build) !void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    
    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for build options
    const build_options_module = b.createModule(.{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "build_options.zig",
        }},
    });

    // Create a module for the neural network
    const neural_module = b.createModule(.{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/neural/neural.zig",
        }},
        .dependencies = &.{
            .{ .name = "build_options", .module = build_options_module },
        },
    });

    // Add include paths for the neural module
    neural_module.addIncludePath(.{ .cwd_relative = "src/neural" });

    // Create test-patterns executable
    const test_patterns_exe = b.addExecutable(.{
        .name = "test-patterns",
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/test_patterns.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add modules to the test-patterns executable
    test_patterns_exe.root_module.addImport("neural", neural_module);
    test_patterns_exe.root_module.addImport("build_options", build_options_module);
    
    // Add include paths
    test_patterns_exe.addIncludePath(.{ .cwd_relative = "src" });
    test_patterns_exe.addIncludePath(.{ .cwd_relative = "src/neural" });
    test_patterns_exe.addSystemIncludePath(.{ .cwd_relative = "src/neural" });
    
    // Link against libc if needed
    test_patterns_exe.linkLibC();
    
    // Install the test-patterns executable
    b.installArtifact(test_patterns_exe);
    
    // Create run step for test-patterns
    const run_test_patterns_cmd = b.addRunArtifact(test_patterns_exe);
    run_test_patterns_cmd.step.dependOn(b.getInstallStep());
    
    // Create pattern recognition test executable
    const pattern_recognition_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/pattern_recognition_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add modules to the pattern recognition test
    pattern_recognition_test.root_module.addImport("neural", neural_module);
    pattern_recognition_test.root_module.addImport("build_options", build_options_module);
    
    // Add include paths
    pattern_recognition_test.addIncludePath(.{ .cwd_relative = "src" });
    pattern_recognition_test.addSystemIncludePath(.{ .cwd_relative = "src/neural" });
    
    // Create a test step for pattern recognition
    const test_step = b.step("test-pattern-recognition", "Run pattern recognition tests");
    test_step.dependOn(&pattern_recognition_test.step);
    
    // Add pattern recognition tests to the main test step
    const test_all = b.step("test", "Run all tests");
    test_all.dependOn(test_step);
    test_all.dependOn(&test_patterns_exe.step);
    
    // Create run step for pattern recognition tests
    const run_pattern_recognition_test = b.addRunArtifact(pattern_recognition_test);
    run_pattern_recognition_test.step.dependOn(b.getInstallStep());

    // Add a test step for test patterns
    const test_patterns_step = b.step("test_patterns", "Run the test patterns");
    test_patterns_step.dependOn(&run_test_patterns_cmd.step);
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_test_patterns_cmd.addArgs(args);
    }
    
    // Create a run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_test_patterns_cmd.step);
    
    // Create a test-patterns step (alias for run)
    const run_test_patterns_step = b.step("test-patterns", "Run the test patterns application");
    run_test_patterns_step.dependOn(&run_test_patterns_cmd.step);
    
    // Create hypercube library
    const hypercube_lib = b.addStaticLibrary(.{
        .name = "hypercube",
        .root_source_file = .{ .cwd_relative = "src/core/hypercube/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add hypercube library to install step
    b.installArtifact(hypercube_lib);
    
    // Create hypercube executable
    const hypercube_exe = b.addExecutable(.{
        .name = "hypercube",
        .root_source_file = .{ .cwd_relative = "src/core/hypercube/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Install hypercube executable
    b.installArtifact(hypercube_exe);
    
    // Create run step for hypercube
    const run_hypercube_cmd = b.addRunArtifact(hypercube_exe);
    run_hypercube_cmd.step.dependOn(b.getInstallStep());
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_hypercube_cmd.addArgs(args);
    }
    
    // Create hypercube test step
    const hypercube_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/core/hypercube/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Create a test step for hypercube
    const hypercube_test_step = b.step("test-hypercube", "Run HYPERCUBE tests");
    hypercube_test_step.dependOn(&hypercube_test.step);
    
    // Add hypercube tests to the main test step
    test_all.dependOn(hypercube_test_step);
    
    // Create hypercube run step
    const hypercube_run_step = b.step("hypercube", "Run HYPERCUBE example");
    hypercube_run_step.dependOn(&run_hypercube_cmd.step);
    
    // Add hypercube to the main run step
    run_step.dependOn(&run_hypercube_cmd.step);
}
