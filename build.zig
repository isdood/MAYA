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
            .sub_path = "src/neural/mod.zig",
        }},
    });

    // Create executable
    const exe = b.addExecutable(.{
        .name = "test-patterns",
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/test_patterns.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add modules to the executable
    exe.root_module.addImport("neural", neural_module);
    exe.root_module.addImport("build_options", build_options_module);
    
    // Add include paths
    exe.addIncludePath(.{ .cwd_relative = "src" });
    exe.addSystemIncludePath(.{ .cwd_relative = "src/neural" });
    
    // Link against libc if needed
    exe.linkLibC();
    
    // Install the executable
    b.installArtifact(exe);
    
    // Create run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    // Create a run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
    
    // Create a test-patterns step (alias for run)
    const test_patterns_step = b.step("test-patterns", "Run the test patterns application");
    test_patterns_step.dependOn(&run_cmd.step);
}
