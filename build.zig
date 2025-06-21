const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add include paths
    exe.addIncludePath(.{ .path = "src" });
    
    // Add source files directly
    exe.addCSourceFile(.{
        .file = .{ .path = "src/starweave/protocol.zig" },
        .flags = &[0][]const u8{},
    });
    exe.addCSourceFile(.{
        .file = .{ .path = "src/neural/quantum_processor.zig" },
        .flags = &[0][]const u8{},
    });
    exe.addCSourceFile(.{
        .file = .{ .path = "src/glimmer/mod.zig" },
        .flags = &[0][]const u8{},
    });
    exe.addCSourceFile(.{
        .file = .{ .path = "src/neural/mod.zig" },
        .flags = &[0][]const u8{},
    });
    exe.addCSourceFile(.{
        .file = .{ .path = "src/glimmer/colors.zig" },
        .flags = &[0][]const u8{},
    });

    // Install the executable
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}