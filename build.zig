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
        .imports = &.{
            .{ .name = "neural", .module = neural_module },
            .{ .name = "glimmer", .module = glimmer_module },
        },
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
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies to executable
    exe.root_module.addImport("glimmer", glimmer_module);
    exe.root_module.addImport("neural", neural_module);
    exe.root_module.addImport("starweave", starweave_module);

    exe.addModule("glimmer-colors", b.addModule("glimmer-colors", .{
        .source_file = .{ .cwd_relative = "src/glimmer/colors.zig" },
    }));
    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("freetype");
    exe.linkSystemLibrary("harfbuzz");

    // Add include paths
    exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
    exe.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    exe.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });

    // Add compile definitions
    exe.defineCMacro("VK_USE_PLATFORM_XLIB_KHR", "1");
    exe.defineCMacro("GLFW_INCLUDE_VULKAN", "1");

    b.installArtifact(exe);

    // Create run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create run step
    const run_step = b.step("run", "Run the MAYA GUI");
    run_step.dependOn(&run_cmd.step);

    // Create test step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    unit_tests.addModule("glimmer-colors", b.addModule("glimmer-colors", .{
        .source_file = .{ .cwd_relative = "src/glimmer/colors.zig" },
    }));

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}