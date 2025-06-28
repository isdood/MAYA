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

    // Create the shaders module first to avoid conflicts
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
    const tensor_module = b.createModule(.{
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
    
    // Create the test executable
    const test_exe = b.addTest(.{
        .name = "vulkan_init_test",
        .root_source_file = .{ .cwd_relative = "tests/vulkan_init_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add module imports
    test_exe.root_module.addImport("vulkan", vk_module);
    test_exe.root_module.addImport("vulkan/context", context_module);
    
    // Create a shaders step
    const shaders_step = b.step("shaders", "Install shader files");
    
    // Shader files to be installed
    const shader_files = [_][]const u8{
        "shaders/4d_tensor_operations_float.comp.spv",
        "shaders/4d_tensor_operations_int.comp.spv",
        "shaders/4d_tensor_operations_uint.comp.spv",
    };
    
    // Install shader files to the output directory
    for (shader_files) |shader| {
        const shader_install = b.addInstallFile(
            .{ .cwd_relative = shader },
            b.fmt("zig-out/{s}", .{shader}),
        );
        shaders_step.dependOn(&shader_install.step);
        test_exe.step.dependOn(&shader_install.step);
    }
    
    // Add include paths
    test_exe.addIncludePath(.{ .cwd_relative = "src" });
    test_exe.addIncludePath(.{ .cwd_relative = "src/vulkan" });
    test_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    test_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include/vulkan" });
    
    // Add include paths for shaders
    test_exe.addIncludePath(.{ .cwd_relative = "src/vulkan/compute" });
    test_exe.addIncludePath(.{ .cwd_relative = "src/vulkan/compute/generated" });
    
    // Add shaders module
    test_exe.root_module.addImport("shaders", shaders_module);
    
    // Link against required libraries
    test_exe.linkSystemLibrary("vulkan");
    test_exe.linkLibC();
    
    // Create test executables
    const test_vulkan_init = b.addTest(.{
        .name = "vulkan_init_test",
        .root_source_file = .{ .cwd_relative = "tests/vulkan_init_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    const test_tensor_ops = b.addTest(.{
        .name = "tensor_ops_test",
        .root_source_file = .{ .cwd_relative = "tests/tensor_operations_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    const test_tensor_ops_ext = b.addTest(.{
        .name = "tensor_ops_ext_test",
        .root_source_file = .{ .cwd_relative = "tests/tensor_operations_extended_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add include paths and link libraries to tests
    const test_executables = [_]*std.Build.Step.Compile{ test_vulkan_init, test_tensor_ops, test_tensor_ops_ext };
    for (test_executables) |exe| {
        exe.addIncludePath(.{ .cwd_relative = "src" });
        exe.addIncludePath(.{ .cwd_relative = "src/vulkan" });
        exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
        exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include/vulkan" });
        exe.linkSystemLibrary("vulkan");
        exe.linkLibC();
        
        // Add module imports
        exe.root_module.addImport("vulkan", vk_module);
        exe.root_module.addImport("vulkan/context", context_module);
        exe.root_module.addImport("vulkan/compute/tensor_operations", tensor_ops_module);
    }
    
    // Create test steps
    const test_vulkan_init_step = b.step("test-vulkan-init", "Run Vulkan initialization tests");
    test_vulkan_init_step.dependOn(&test_vulkan_init.step);
    
    const test_tensor_ops_step = b.step("test-tensor-ops", "Run basic tensor operations tests");
    test_tensor_ops_step.dependOn(&test_tensor_ops.step);
    
    const test_tensor_ops_ext_step = b.step("test-tensor-ops-ext", "Run extended tensor operations tests");
    test_tensor_ops_ext_step.dependOn(&test_tensor_ops_ext.step);
    
    // Add to the default test step
    const test_all = b.step("test", "Run all tests");
    test_all.dependOn(test_vulkan_init_step);
    test_all.dependOn(test_tensor_ops_step);
    test_all.dependOn(test_tensor_ops_ext_step);
    
    // Create a run step for the test executable
    const run_test_cmd = b.addRunArtifact(test_exe);
    run_test_cmd.step.dependOn(b.getInstallStep());
    
    const run_test_step = b.step("run-test", "Run the Vulkan initialization test");
    run_test_step.dependOn(&run_test_cmd.step);
    
    // Create the test_tensor_ops executable
    const test_tensor_ops_exe = b.addExecutable(.{
        .name = "test_tensor_ops",
        .root_source_file = .{ .cwd_relative = "examples/test_tensor_ops.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add include paths
    test_tensor_ops_exe.addIncludePath(.{ .cwd_relative = "src" });
    test_tensor_ops_exe.addIncludePath(.{ .cwd_relative = "src/vulkan" });
    test_tensor_ops_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    test_tensor_ops_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include/vulkan" });
    
    // Add module imports
    test_tensor_ops_exe.root_module.addImport("vk", vk_module);
    test_tensor_ops_exe.root_module.addImport("vulkan/context", context_module);
    test_tensor_ops_exe.root_module.addImport("vulkan/memory", memory_module);
    test_tensor_ops_exe.root_module.addImport("vulkan/compute/tensor_operations", tensor_ops_module);
    test_tensor_ops_exe.root_module.addImport("vulkan/compute/tensor", tensor_module);
    
    // Add include paths for shaders
    test_tensor_ops_exe.addIncludePath(.{ .cwd_relative = "src/vulkan/compute" });
    test_tensor_ops_exe.addIncludePath(.{ .cwd_relative = "src/vulkan/compute/generated" });
    
    // Reuse the existing shaders module
    test_tensor_ops_exe.root_module.addImport("shaders", shaders_module);
    
    // Link against required libraries
    test_tensor_ops_exe.linkSystemLibrary("vulkan");
    test_tensor_ops_exe.linkLibC();
    
    // Install the executable
    b.installArtifact(test_tensor_ops_exe);
    
    // Create a run step for test_tensor_ops
    const run_tensor_ops_cmd = b.addRunArtifact(test_tensor_ops_exe);
    run_tensor_ops_cmd.step.dependOn(b.getInstallStep());
    
    const run_tensor_ops_step = b.step("run-tensor-ops", "Run the tensor operations test");
    run_tensor_ops_step.dependOn(&run_tensor_ops_cmd.step);
    
    // Create the memory_management executable
    const memory_management_exe = b.addExecutable(.{
        .name = "memory_management",
        .root_source_file = .{ .cwd_relative = "examples/memory_management.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies
    memory_management_exe.root_module.addImport("vk", vk_module);
    memory_management_exe.root_module.addImport("vulkan/context", context_module);
    memory_management_exe.root_module.addImport("vulkan/memory", memory_module);

    // Link against system libraries
    memory_management_exe.linkLibC();
    memory_management_exe.linkSystemLibrary("vulkan");
    memory_management_exe.linkSystemLibrary("dl");  // For dynamic loading
    memory_management_exe.linkSystemLibrary("pthread");  // For threading
    memory_management_exe.linkSystemLibrary("m");  // For math
    memory_management_exe.linkSystemLibrary("rt");  // For real-time extensions
    memory_management_exe.linkSystemLibrary("X11"); // For X11 (if needed for windowing)


    // Add to install step
    b.installArtifact(memory_management_exe);

    // Add run step
    const memory_management_run_cmd = b.addRunArtifact(memory_management_exe);
    memory_management_run_cmd.step.dependOn(b.getInstallStep());
    const memory_management_run_step = b.step("run-memory-management", "Run the memory management example");
    memory_management_run_step.dependOn(&memory_management_run_cmd.step);

    // Default run step
    const run_step = b.step("run", "Run the tensor operations test");
    // Add the example to the main run step
    run_step.dependOn(memory_management_run_step);
}
