const Builder = @import("std").build.Builder;
const Step = @import("std").build.Step;

pub fn build(b: *Builder) !void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    
    // Standard optimization options
    const mode = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable("test-patterns", "src/quantum_cache/test_patterns.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    
    // Add include paths
    exe.addIncludePath("src");
    
    // Link against libc if needed
    exe.linkLibC();
    
    // Install the executable
    exe.install();
    
    // Create run step
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    // Create a run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
