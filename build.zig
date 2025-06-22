const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create modules
    const neural_mod = b.addModule("neural", .{
        .root_source_file = .{ .cwd_relative = "src/neural/mod.zig" },
    });
    
    const starweave_mod = b.addModule("starweave", .{
        .root_source_file = .{ .cwd_relative = "src/starweave/starweave.zig" },
    });
    
    const glimmer_mod = b.addModule("glimmer", .{
        .root_source_file = .{ .cwd_relative = "src/glimmer/glimmer.zig" },
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize
    });
    
    // Add module imports
    exe.root_module.addImport("neural", neural_mod);
    exe.root_module.addImport("starweave", starweave_mod);
    exe.root_module.addImport("glimmer", glimmer_mod);
    
    // Add dependencies
    exe.linkLibC();
    
    b.installArtifact(exe);

    // Test step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize
    });
    
    const test_run = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run.step);

    // Pattern generator tool
    const pattern_gen = b.addExecutable(.{
        .name = "maya-pattern-gen",
        .root_source_file = .{ .cwd_relative = "src/pattern_gen.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add module imports to pattern generator
    pattern_gen.root_module.addImport("neural", neural_mod);
    pattern_gen.root_module.addImport("starweave", starweave_mod);
    pattern_gen.root_module.addImport("glimmer", glimmer_mod);
    
    // Install the pattern generator
    b.installArtifact(pattern_gen);
    
    // Create a run step for the pattern generator
    const pattern_gen_run = b.addRunArtifact(pattern_gen);
    if (b.args) |args| {
        pattern_gen_run.addArgs(args);
    }
    
    const pattern_gen_step = b.step("pattern-gen", "Generate sample patterns");
    pattern_gen_step.dependOn(&pattern_gen_run.step);
}