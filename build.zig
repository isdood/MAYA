const std = @import("std");
const Builder = std.build.Builder;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const fs = std.fs;
const path = std.fs.path;

pub fn build(b: *std.Build) !void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    
    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});
    
    // Build shader compiler
    const shader_compiler = b.addExecutable(.{
        .name = "shader_compiler",
        .root_source_file = .{ .cwd_relative = "tools/shader_compiler/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add shader compilation step
    const shader_compile_step = b.step("shaders", "Compile shaders");
    const shader_compile = b.addRunArtifact(shader_compiler);
    shader_compile.addArgs(&.{
        "shaders",
        "src/vulkan/compute/generated",
    });
    shader_compile_step.dependOn(&shader_compile.step);
    
    // Make shader compilation a dependency of the build
    b.getInstallStep().dependOn(shader_compile_step);
    
    // Create the shaders module
    const shaders_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/shaders.zig" },
    });

    // Create the Vulkan module
    const vk_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/vk.zig" },
    });
    
    // Create the context module
    const context_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/context.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
        },
    });
    
    // Create the memory module
    const memory_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/memory.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan/context",
                .module = context_module,
            },
        },
    });
    
    // Create the tensor module
    const tensor_module = b.addModule("vulkan/compute/tensor", .{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/tensor.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan/context",
                .module = context_module,
            },
            .{
                .name = "vulkan/memory",
                .module = memory_module,
            },
        },
    });
    
    // Create the shader utils module
    const shader_utils_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/shader_utils.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
        },
    });

    // Create the tensor_operations module
    const tensor_ops_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/tensor_operations.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan/context",
                .module = context_module,
            },
            .{
                .name = "vulkan/memory",
                .module = memory_module,
            },
            .{
                .name = "shaders",
                .module = shaders_module,
            },
            .{
                .name = "vulkan/compute/tensor",
                .module = tensor_module,
            },
        },
    });
    
    // Create the pattern matching pipeline module
    const pattern_matching_pipeline_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/pattern_matching_pipeline.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan/context",
                .module = context_module,
            },
            .{
                .name = "vulkan/compute/shader_utils",
                .module = shader_utils_module,
            },
        },
    });

    // Create the image module with unique imports
    const image_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/image.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan_context",
                .module = context_module,
            },
            .{
                .name = "vulkan_memory",
                .module = memory_module,
            },
        },
    });

    // Create the pattern matching module
    const pattern_matching_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/pattern_matching.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan_context",
                .module = context_module,
            },
            .{
                .name = "vulkan_memory",
                .module = memory_module,
            },
            .{
                .name = "vulkan_compute_tensor",
                .module = tensor_module,
            },
            .{
                .name = "vulkan_pattern_matching_pipeline",
                .module = pattern_matching_pipeline_module,
            },
            .{
                .name = "vulkan_image",
                .module = image_module,
            },
        },
    });

    // Create the buffer module with a unique name
    const buffer_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/buffer.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan_context",
                .module = context_module,
            },
            .{
                .name = "vulkan_memory",
                .module = memory_module,
            },
        },
    });
    
    // Create the pattern matcher module with unique imports
    const pattern_matcher_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/pattern_matcher.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "vulkan_context",
                .module = context_module,
            },
            .{
                .name = "vulkan_memory",
                .module = memory_module,
            },
            .{
                .name = "shaders",
                .module = shaders_module,
            },
            .{
                .name = "vulkan_compute_tensor",
                .module = tensor_module,
            },
            .{
                .name = "vulkan_image",
                .module = image_module,
            },
            .{
                .name = "vulkan_pattern_matching",
                .module = pattern_matching_module,
            },
            .{
                .name = "vulkan_pattern_matching_pipeline",
                .module = pattern_matching_pipeline_module,
            },
        },
    });


    
    // Create pattern matching test executable
    const pattern_matching_test = b.addExecutable(.{
        .name = "pattern_matching_test",
        .root_source_file = .{ .cwd_relative = "examples/pattern_matching_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link system libraries
    pattern_matching_test.linkLibC();
    pattern_matching_test.linkSystemLibrary("vulkan");
    
    // Add module imports with unique names
    pattern_matching_test.root_module.addImport("vk", vk_module);
    pattern_matching_test.root_module.addImport("vulkan_context", context_module);
    pattern_matching_test.root_module.addImport("vulkan_memory", memory_module);
    pattern_matching_test.root_module.addImport("vulkan_compute_tensor", tensor_module);
    pattern_matching_test.root_module.addImport("vulkan_image", image_module);
    pattern_matching_test.root_module.addImport("vulkan_buffer", buffer_module);
    pattern_matching_test.root_module.addImport("vulkan_pattern_matching", pattern_matching_module);
    pattern_matching_test.root_module.addImport("vulkan_pattern_matcher", pattern_matcher_module);
    pattern_matching_test.root_module.addImport("vulkan_compute_tensor_operations", tensor_ops_module);

    // Add Vulkan test executable
    const vulkan_test = b.addExecutable(.{
        .name = "vulkan_test",
        .root_source_file = .{ .cwd_relative = "examples/vulkan_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link against system libraries
    vulkan_test.linkLibC();
    vulkan_test.linkSystemLibrary("vulkan");
    
    // Add Vulkan module dependencies
    vulkan_test.root_module.addImport("vulkan_context", context_module);
    
    // Install the test executable
    b.installArtifact(vulkan_test);
    
    // Add run step for the test
    const run_vulkan_test = b.addRunArtifact(vulkan_test);
    const run_vulkan_test_step = b.step("run-vulkan-test", "Run the Vulkan context test");
    run_vulkan_test_step.dependOn(&run_vulkan_test.step);
    
    // Add include paths
    pattern_matching_test.addIncludePath(.{ .cwd_relative = "src" });
    pattern_matching_test.addIncludePath(.{ .cwd_relative = "src/vulkan" });
    pattern_matching_test.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    pattern_matching_test.addSystemIncludePath(.{ .cwd_relative = "/usr/include/vulkan" });
    pattern_matching_test.addIncludePath(.{ .cwd_relative = "src/vulkan/compute" });
    pattern_matching_test.addIncludePath(.{ .cwd_relative = "src/vulkan/compute/generated" });
    
    // Link against required libraries
    pattern_matching_test.linkSystemLibrary("vulkan");
    pattern_matching_test.linkLibC();
    
    // Create install step for the test executable
    const install_pattern_matching_test = b.addInstallArtifact(pattern_matching_test, .{});
    
    // Create a run step for the test executable
    const run_pattern_matching_test = b.addRunArtifact(pattern_matching_test);
    
    // Make the run step depend on shader compilation
    run_pattern_matching_test.step.dependOn(shader_compile_step);
    
    // Shader files to be installed
    const shader_files = [_][]const u8{
        "shaders/4d_tensor_operations_float.comp.spv",
        "shaders/4d_tensor_operations_int.comp.spv",
        "shaders/4d_tensor_operations_uint.comp.spv",
        "shaders/spv/pattern_matching.comp.spv",
    };
    
    // Install shader files to the output directory
    for (shader_files) |shader| {
        const shader_install = b.addInstallFile(
            .{ .cwd_relative = shader },
            b.fmt("zig-out/{s}", .{shader}),
        );
        shader_compile_step.dependOn(&shader_install.step);
        pattern_matching_test.step.dependOn(&shader_install.step);
    }
    
    // Create a step to run the pattern matching test
    const run_test_step = b.step("run-pattern-matching-test", "Run the pattern matching test");
    run_test_step.dependOn(&install_pattern_matching_test.step);
    run_test_step.dependOn(&run_pattern_matching_test.step);
    
    // Add the test step
    const test_step = b.step("test-pattern-matching", "Run the pattern matching tests");
    test_step.dependOn(&run_pattern_matching_test.step);
    
    // Create a test step for future use
    const all_tests_step = b.step("test", "Run all tests");
    all_tests_step.dependOn(run_test_step);
    
    // Default run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(run_test_step);
}
