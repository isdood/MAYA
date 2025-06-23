const std = @import("std");

pub fn build(b: *std.Build) void {
    // Create an executable step
    const exe = b.addExecutable(.{
        .name = "test-patterns",
        .root_source_file = .{ .owner = b, .sub_path = "src/quantum_cache/test_patterns.zig" },
    });
    
    // Set target and optimization
    exe.setTarget(b.standardTargetOptions(.{}));
    exe.setBuildMode(.ReleaseSafe);
    
    // Add include paths if needed
    exe.addIncludePath("src");
    
    // Install the executable
    b.installArtifact(exe);
    
    // Add a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    // Create a run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
