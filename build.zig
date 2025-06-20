//! MAYA Build Configuration
//! Contains build definitions for the MAYA neural processing system

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
    
    // Individual neural modules
    const pattern_recognition_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/pattern_recognition/mod.zig" },
        .imports = &.{
            .{ .name = "std", .module = std_mod },
        },
    });
    
    const pattern_synthesis_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/pattern_synthesis/mod.zig" },
        .imports = &.{
            .{ .name = "std", .module = std_mod },
        },
    });
    
    const pattern_processor_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/neural/pattern_processor/mod.zig" },
        .imports = &.{
            .{ .name = "std", .module = std_mod },
            .{ .name = "pattern_synthesis", .module = pattern_synthesis_mod },
        },
    });
    
    // Update neural module imports
    neural_mod.imports = &.{
        .{ .name = "starweave", .module = starweave_mod },
        .{ .name = "glimmer", .module = glimmer_mod },
        .{ .name = "quantum_types", .module = quantum_types_mod },
        .{ .name = "std", .module = std_mod },
        .{ .name = "pattern_recognition", .module = pattern_recognition_mod },
        .{ .name = "pattern_synthesis", .module = pattern_synthesis_mod },
        .{ .name = "pattern_processor", .module = pattern_processor_mod },
    };
    
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
    
    // Pattern Synthesis Example
    const pattern_synthesis_exe = b.addExecutable(.{
        .name = "pattern_synthesis",
        .root_source_file = .{ .cwd_relative = "examples/pattern_synthesis.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_synthesis_exe.root_module.addImport("neural", neural_mod);
    b.installArtifact(pattern_synthesis_exe);
    
    const run_pattern_synthesis = b.addRunArtifact(pattern_synthesis_exe);
    const pattern_synthesis_step = b.step("pattern-synthesis", "Run the pattern synthesis example");
    pattern_synthesis_step.dependOn(&run_pattern_synthesis.step);
    
    // Pattern Processor Example
    const pattern_processor_exe = b.addExecutable(.{
        .name = "pattern_processor",
        .root_source_file = .{ .cwd_relative = "examples/pattern_processor.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_processor_exe.root_module.addImport("neural", neural_mod);
    b.installArtifact(pattern_processor_exe);
    
    const run_pattern_processor = b.addRunArtifact(pattern_processor_exe);
    const pattern_processor_step = b.step("pattern-processor", "Run the pattern processor example");
    pattern_processor_step.dependOn(&run_pattern_processor.step);
    
    // Neural Module Tests
    const neural_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/neural/test.zig" },
        .target = target,
        .optimize = optimize,
    });
    neural_tests.root_module.addImport("neural", neural_mod);
    
    const run_neural_tests = b.addRunArtifact(neural_tests);
    const test_step = b.step("test-neural", "Run neural module tests");
    test_step.dependOn(&run_neural_tests.step);

    // Pattern visualization example
    const pattern_visualization_exe = b.addExecutable(.{
        .name = "pattern_visualization",
        .root_source_file = .{ .cwd_relative = "examples/pattern_visualization.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_visualization_exe.root_module.addImport("neural", neural_mod);
    pattern_visualization_exe.root_module.addImport("visualization", b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/visualization/pattern_visualizer.zig" },
    }));

    const run_pattern_visualization = b.addRunArtifact(pattern_visualization_exe);
    const pattern_visualization_step = b.step("run:pattern-visualization", "Run pattern visualization example");
    pattern_visualization_step.dependOn(&run_pattern_visualization.step);

    // Simple pattern evolution example
    const simple_pattern_evolution_exe = b.addExecutable(.{
        .name = "simple_pattern_evolution",
        .root_source_file = .{ .cwd_relative = "examples/simple_pattern_evolution.zig" },
        .target = target,
        .optimize = optimize,
    });
    simple_pattern_evolution_exe.root_module.addImport("neural", neural_mod);
    simple_pattern_evolution_exe.root_module.addImport("quantum_types", quantum_types_mod);

    const run_simple_pattern_evolution = b.addRunArtifact(simple_pattern_evolution_exe);
    const simple_pattern_evolution_step = b.step("run:simple-pattern-evolution", "Run simple pattern evolution example");
    simple_pattern_evolution_step.dependOn(&run_simple_pattern_evolution.step);

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

    // Real-time Evolution Example
    const realtime_evolution_exe = b.addExecutable(.{
        .name = "realtime_evolution",
        .root_source_file = .{ .cwd_relative = "examples/realtime_evolution.zig" },
        .target = target,
        .optimize = optimize,
    });
    realtime_evolution_exe.root_module.addImport("neural", neural_mod);
    b.installArtifact(realtime_evolution_exe);
    
    const run_realtime_evolution = b.addRunArtifact(realtime_evolution_exe);
    const realtime_evolution_step = b.step("realtime-evolution", "Run the real-time pattern evolution example");
    realtime_evolution_step.dependOn(&run_realtime_evolution.step);

    // 🧪 Test Configuration
    const test_step = b.step("test", "Run all tests");
    
    // Main tests
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/test.zig" },
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

    // Pattern evolution tests
    const pattern_evolution_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "test/pattern_evolution_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    pattern_evolution_tests.root_module.addImport("neural", neural_mod);
    pattern_evolution_tests.root_module.addImport("quantum_types", quantum_types_mod);

    const run_pattern_evolution_tests = b.addRunArtifact(pattern_evolution_tests);
    const test_pattern_evolution_step = b.step("test:pattern-evolution", "Run pattern evolution tests");
    test_pattern_evolution_step.dependOn(&run_pattern_evolution_tests.step);
    
    // Make the main test step depend on all test steps
    test_step.dependOn(test_pattern_evolution_step);

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
