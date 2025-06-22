const std = @import("std");

// Build configuration options
const Options = struct {
    enable_gpu: bool = true,
    rocm_path: ?[]const u8 = "/opt/rocm",
};

// Parse command line options
fn parseOptions(b: *std.Build) Options {
    const options = b.option(bool, "enable-gpu", "Enable GPU acceleration (default: true)") orelse true;
    const rocm_path = b.option([]const u8, "rocm-path", "Path to ROCm installation (default: /opt/rocm)");
    
    return .{
        .enable_gpu = options,
        .rocm_path = rocm_path,
    };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = parseOptions(b);

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
    
    // GPU module (optional)
    if (options.enable_gpu) {
        const gpu_mod = b.addModule("gpu", .{
            .root_source_file = .{ .cwd_relative = "src/gpu/gpu.zig" },
        });
        
        // Add ROCm include path
        const rocm_include = if (options.rocm_path) |path|
            std.fs.path.join(b.allocator, &[_][]const u8{ path, "include" }) catch @panic("OOM")
        else
            "/opt/rocm/include";
            
        // For Zig 0.14.1 - use addIncludePath with a direct path string
        gpu_mod.addIncludePath(.{ .path = rocm_include });
        
        // Link against ROCm libraries
        gpu_mod.linkSystemLibrary("hsa-runtime64");
        gpu_mod.linkSystemLibrary("amdhip64");
        
        // Add compile flags for ROCm
        gpu_mod.addCSourceFlags(&.{
            "-D__HIP_PLATFORM_AMD__",
            "-D__HIP_ROCclr__",
            "-fPIC",
        });
        
        // Make GPU module available to other modules
        neural_mod.addImport("gpu", gpu_mod);
    }

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
    
    // GPU Evolution Example
    const gpu_evolution_example = b.addExecutable("gpu_evolution", .{
        .root_source_file = .{ .cwd_relative = "examples/gpu_evolution.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    gpu_evolution_example.root_module.addImport("neural", neural_mod);
    gpu_evolution_example.root_module.addImport("starweave", starweave_mod);
    gpu_evolution_example.root_module.addImport("glimmer", glimmer_mod);
    
    // Link against ROCm libraries if enabled
    if (options.enable_gpu) {
        gpu_evolution_example.linkSystemLibrary("hsa-runtime64");
        gpu_evolution_example.linkSystemLibrary("amdhip64");
    }
    
    b.installArtifact(gpu_evolution_example);

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