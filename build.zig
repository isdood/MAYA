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

    // Main GLIMMER module with visualization support
    const glimmer_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/glimmer/mod.zig" },
        .imports = &.{
            .{ .name = "starweave", .module = starweave_mod },
        },
    });

    // Memory Visualization Example
    const memory_vis_exe = b.addExecutable(.{
        .name = "memory_visualization",
        .root_source_file = .{ .cwd_relative = "examples/memory_visualization.zig" },
        .target = target,
        .optimize = optimize,
    });
    memory_vis_exe.root_module.addImport("glimmer", glimmer_mod);
    b.installArtifact(memory_vis_exe);
    
    const run_memory_vis = b.addRunArtifact(memory_vis_exe);
    const memory_vis_step = b.step("memory-vis", "Run the memory visualization example");
    memory_vis_step.dependOn(&run_memory_vis.step);

    // Pattern Recognition Example
    const pattern_recognition_exe = b.addExecutable(.{
        .name = "pattern_recognition",
        .root_source_file = .{ .cwd_relative = "examples/pattern_recognition.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_recognition_exe.root_module.addImport("neural", neural_mod);
    b.installArtifact(pattern_recognition_exe);
    
    const run_pattern_recognition = b.addRunArtifact(pattern_recognition_exe);
    const pattern_recognition_step = b.step("pattern-recognition", "Run the pattern recognition example");
    pattern_recognition_step.dependOn(&run_pattern_recognition.step);

    // TODO: Add other neural modules as they're implemented
    // const quantum_processor_mod = ...
    // const visual_processor_mod = ...
    // const neural_processor_mod = ...

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
    exe.root_module.addImport("pattern_recognition", pattern_recognition_mod);
    exe.root_module.addImport("quantum_processor", quantum_processor_mod);
    exe.root_module.addImport("visual_processor", visual_processor_mod);
    exe.root_module.addImport("neural_processor", neural_processor_mod);

    // 🎨 System Library Integration
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("freetype");
    exe.linkSystemLibrary("harfbuzz");
    exe.linkLibC();

    // 🌐 WASM Configuration
    const maya_wasm = b.addExecutable(.{
        .name = "maya-wasm",
        .root_source_file = .{ .cwd_relative = "src/wasm.zig" },
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = optimize,
    });

    maya_wasm.root_module.addImport("starweave", starweave_mod);
    maya_wasm.root_module.addImport("glimmer", glimmer_mod);
    maya_wasm.root_module.addImport("pattern_recognition", pattern_recognition_mod);
    maya_wasm.root_module.addImport("quantum_processor", quantum_processor_mod);
    maya_wasm.root_module.addImport("visual_processor", visual_processor_mod);
    maya_wasm.root_module.addImport("neural_processor", neural_processor_mod);

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
    main_tests.root_module.addImport("pattern_recognition", pattern_recognition_mod);
    main_tests.root_module.addImport("quantum_processor", quantum_processor_mod);
    main_tests.root_module.addImport("visual_processor", visual_processor_mod);
    main_tests.root_module.addImport("neural_processor", neural_processor_mod);

    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);

    // ⚡ Install Steps
    b.installArtifact(exe);
    b.installArtifact(maya_wasm);

    // 🎨 GLIMMER Visual Tests
    const visual_step = b.step("visual", "🎨 Run GLIMMER pattern tests");
    const visual_cmd = b.addSystemCommand(&.{
        "./scripts/test_glimmer_patterns.sh",
    });
    visual_step.dependOn(&visual_cmd.step);
}
