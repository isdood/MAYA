const std = @import("std");

pub fn build(b: *std.Build) !void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    
    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});

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
    
    // Add shader files to the build
    const shader_files = [_][]const u8{
        "shaders/4d_tensor_operations_float.comp.spv",
        "shaders/4d_tensor_operations_int.comp.spv",
        "shaders/4d_tensor_operations_uint.comp.spv",
    };
    
    // Create a shaders step
    const shaders_step = b.step("shaders", "Install shader files");
    
    // Install shader files to the output directory
    inline for (shader_files) |shader| {
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
    
    // Create a run step
    const run_cmd = b.addRunArtifact(test_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    const run_step = b.step("run", "Run the Vulkan initialization test");
    run_step.dependOn(&run_cmd.step);
}
