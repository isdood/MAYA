const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const shaders = b.addModule("shaders", .{
        .root_source_file = .{ .path = "shaders.zig" },
    });
    
    // Add the shaders directory to the module's include paths
    shaders.addIncludePath(.{ .path = "." });
    
    // Add the module to the build
    b.getInstallStep().dependOn(&b.addInstallDirectory(.{
        .source_dir = ".",
        .install_dir = .{ .custom = "zig-out/shaders" },
        .install_subdir = "",
        .include_extensions = &[_][]const u8{".spv"},
    }).step);
}
