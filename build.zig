//! 🌌 STARWEAVE Universe Integration
//! ✨ Version: 2025.6.18
//! 🎨 Pattern: 1.0.0
//! ⚡ Seed: 
//! 📅 Woven: 2025-06-18 21:15:30
//! 👤 Weaver: isdood

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 🎨 STARWEAVE Module Definitions
    const starweave_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/starweave/protocol.zig" },
    });

    const glimmer_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/glimmer/patterns.zig" },
        .imports = &.{
            .{ .name = "starweave", .module = starweave_mod },
        },
    });

    const neural_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/bridge.zig" },
        .imports = &.{
            .{ .name = "starweave", .module = starweave_mod },
            .{ .name = "glimmer", .module = glimmer_mod },
        },
    });

    const colors_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/glimmer/colors.zig" },
        .imports = &.{
            .{ .name = "glimmer", .module = glimmer_mod },
        },
    });

    // 🌟 Main MAYA Executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 🌌 Add STARWEAVE modules
    exe.root_module.addImport("starweave", starweave_mod);
    exe.root_module.addImport("glimmer", glimmer_mod);
    exe.root_module.addImport("neural", neural_mod);
    exe.root_module.addImport("colors", colors_mod);

    // 🎨 System Library Integration
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("freetype");
    exe.linkSystemLibrary("harfbuzz");
    exe.linkLibC();

    // 🌐 WASM Configuration
    const wasm = b.addExecutable(.{
        .name = "maya-wasm",
        .root_source_file = .{ .cwd_relative = "src/wasm.zig" },
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = optimize,
    });

    wasm.root_module.addImport("starweave", starweave_mod);
    wasm.root_module.addImport("glimmer", glimmer_mod);

    // 🧪 Quantum Test Configuration
    const test_step = b.step("test", "🧪 Run MAYA quantum tests");
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/test/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    main_tests.root_module.addImport("starweave", starweave_mod);
    main_tests.root_module.addImport("glimmer", glimmer_mod);
    main_tests.root_module.addImport("neural", neural_mod);
    main_tests.root_module.addImport("colors", colors_mod);

    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);

    // ⚡ Install Steps
    b.installArtifact(exe);
    b.installArtifact(wasm);

    // 🎨 GLIMMER Visual Tests
    const visual_step = b.step("visual", "🎨 Run GLIMMER pattern tests");
    const visual_cmd = b.addSystemCommand(&.{
        "./scripts/test_glimmer_patterns.sh",
    });
    visual_step.dependOn(&visual_cmd.step);
}
