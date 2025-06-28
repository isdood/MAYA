const std = @import("std");

pub fn build(b: *std.Build) !void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Get the Vulkan module from the parent build.zig
    const vk_module = b.dependency("vulkan", .{}).module("vulkan");
    
    // Create the context module
    const context_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "../src/vulkan/compute/context.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
        },
    });
    
    // Create the memory module
    const memory_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "../src/vulkan/compute/memory.zig" },
        .imports = &.{
            .{
                .name = "vk",
                .module = vk_module,
            },
            .{
                .name = "context",
                .module = context_module,
            },
        },
    });

    // Create the test_tensor_ops executable
    const test_tensor_ops = b.addExecutable(.{
        .name = "test_tensor_ops",
        .root_source_file = .{ .cwd_relative = "test_tensor_ops.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add the modules
    test_tensor_ops.root_module.addImport("vk", vk_module);
    test_tensor_ops.root_module.addImport("context", context_module);
    test_tensor_ops.root_module.addImport("memory", memory_module);
    
    // Link against Vulkan
    test_tensor_ops.linkSystemLibrary("vulkan");
    
    // Install the executable
    b.installArtifact(test_tensor_ops);
    
    // Create run step for test_tensor_ops
    const run_test_tensor_ops = b.addRunArtifact(test_tensor_ops);
    run_test_tensor_ops.step.dependOn(b.getInstallStep());
    
    // Add run step
    const run_step = b.step("test_tensor_ops", "Run the tensor operations test");
    run_step.dependOn(&run_test_tensor_ops.step);
    
    // Add a default run step that runs all tests
    const all_tests = b.step("all", "Run all tests");
    all_tests.dependOn(run_step);
}
