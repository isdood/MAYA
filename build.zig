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

    // Create quantum types module
    const quantum_types_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/quantum_types.zig" },
        .imports = &.{},
    });

    // Get the standard library module
    const std_mod = b.dependency("std", .{}).module("std");

    // 🧠 Neural Module with Pattern Recognition
    const neural_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/mod.zig" },
        .imports = &.{
            .{ .name = "starweave", .module = starweave_mod },
            .{ .name = "glimmer", .module = glimmer_mod },
            .{ .name = "quantum_types", .module = quantum_types_mod },
            .{ .name = "std", .module = std_mod },
        },
    });
    
    // Pattern recognition is part of the neural module
    const pattern_recognition_mod = neural_mod;
    
    // Create test modules
    _ = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/crystal_computing.zig" },
        .imports = &.{
            .{ .name = "quantum_types", .module = quantum_types_mod },
        },
    });
    
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

    // 🧪 Test Configuration
    const test_step = b.step("test", "Run all tests");
    
    // Main tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add module imports for main tests
    main_tests.root_module.addImport("starweave", starweave_mod);
    main_tests.root_module.addImport("glimmer", glimmer_mod);
    main_tests.root_module.addImport("neural", neural_mod);
    main_tests.root_module.addImport("colors", colors_mod);
    main_tests.root_module.addImport("pattern_recognition", pattern_recognition_mod);

    // Integration tests
    const integration_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "test_integration.zig" },
        .target = target,
        .optimize = optimize,
    });
    integration_tests.root_module.addImport("neural", neural_mod);
    integration_tests.root_module.addImport("quantum_types", quantum_types_mod);
    integration_tests.root_module.addImport("colors", colors_mod);
    integration_tests.root_module.addImport("pattern_recognition", pattern_recognition_mod);

    const run_integration_tests = b.addRunArtifact(integration_tests);
    const test_integration_step = b.step("test:integration", "Run integration tests");
    test_integration_step.dependOn(&run_integration_tests.step);

    // Pattern Evolution Benchmark
    const pattern_evolution_bench_exe = b.addExecutable(.{
        .name = "pattern_evolution_benchmark",
        .root_source_file = .{ .cwd_relative = "benchmarks/pattern_evolution_benchmark.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_evolution_bench_exe.root_module.addImport("neural", neural_mod);
    b.installArtifact(pattern_evolution_bench_exe);
    
    const run_bench = b.addRunArtifact(pattern_evolution_bench_exe);
    const bench_step = b.step("bench:pattern-evolution", "Run pattern evolution benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Pattern Visualization Example
    const pattern_viz_exe = b.addExecutable(.{
        .name = "pattern_visualization",
        .root_source_file = .{ .cwd_relative = "examples/pattern_visualization.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_viz_exe.root_module.addImport("neural", neural_mod);
    pattern_viz_exe.root_module.addImport("visualization", b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/visualization/pattern_visualizer.zig" },
    }));
    b.installArtifact(pattern_viz_exe);
    
    const run_pattern_viz = b.addRunArtifact(pattern_viz_exe);
    const pattern_viz_step = b.step("viz:pattern", "Run pattern visualization example");
    pattern_viz_step.dependOn(&run_pattern_viz.step);

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
