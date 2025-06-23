const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("test-patterns", "src/quantum_cache/test_patterns.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    
    // Add include paths
    exe.addIncludePath("src");
    
    // Link against libc if needed
    exe.linkLibC();
    
    // Set output directory
    exe.setOutputDir("zig-out/bin");
    
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
