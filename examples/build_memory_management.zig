const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the Vulkan module
    const vk_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "../src/vulkan/vk.zig" },
    });

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
        .root_source_file = .{ .cwd_relative = "../src/vulkan/memory.zig" },
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

    // Create the memory management executable
    const exe = b.addExecutable(.{
        .name = "memory_management",
        .root_source_file = .{ .cwd_relative = "memory_management.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add module imports
    exe.root_module.addImport("vk", vk_module);
    exe.root_module.addImport("vulkan/context", context_module);
    exe.root_module.addImport("vulkan/memory", memory_module);

    // Link system libraries
    exe.linkLibC();
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("dl");  // For dynamic loading
    exe.linkSystemLibrary("pthread");
    exe.linkSystemLibrary("m");
    exe.linkSystemLibrary("rt");

    // Install the executable
    b.installArtifact(exe);

    // Add a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    const run_step = b.step("run", "Run the memory management example");
    run_step.dependOn(&run_cmd.step);
}
