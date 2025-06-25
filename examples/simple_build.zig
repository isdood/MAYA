const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("temporal_processing", null);
    exe.setBuildMode(mode);
    
    // Add source files
    exe.addCSourceFile("temporal_processing.zig", "");
    exe.addCSourceFile("../src/neural/tensor4d.zig", "");
    exe.addCSourceFile("../src/neural/attention.zig", "");
    exe.addCSourceFile("../src/neural/quantum_tunneling.zig", "");
    exe.addCSourceFile("../src/neural/temporal.zig", "");
    exe.addCSourceFile("../src/neural/hypercube_bridge.zig", "");
    
    // Add include paths
    exe.addIncludeDir("../src");
    exe.addIncludeDir("../src/neural");
    
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
