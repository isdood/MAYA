const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Neural module
    const neural_mod = b.addModule("neural", .{
        .root_source_file = .{ .cwd_relative = "src/neural/mod.zig" }
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize
    });
    exe.root_module.addImport("neural", neural_mod);
    
    b.installArtifact(exe);

    // Benchmark executable
    const bench_exe = b.addExecutable(.{
        .name = "quantum_bench",
        .root_source_file = .{ .cwd_relative = "bench/quantum_benchmarks.zig" },
        .target = target,
        .optimize = .ReleaseFast
    });
    bench_exe.root_module.addImport("neural", neural_mod);
    
    const bench_run = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&bench_run.step);

    // Test step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize
    });
    unit_tests.root_module.addImport("neural", neural_mod);
    
    const test_run = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run.step);
}