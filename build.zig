const std = @import("std");

// Build configuration options
const Options = struct {
    enable_gpu: bool = true,
    rocm_path: ?[]const u8 = "/opt/rocm",
};

// Parse command line options
fn parseOptions(b: *std.Build) Options {
    const options = b.option(bool, "enable-gpu", "Enable GPU acceleration (default: true)") orelse true;
    const rocm_path = b.option([]const u8, "rocm-path", "Path to ROCm installation (default: /opt/rocm");
    
    return .{
        .enable_gpu = options,
        .rocm_path = rocm_path,
    };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = parseOptions(b);

    // Create neural module
    const neural_mod = b.addModule("neural", .{
        .root_source_file = .{ .cwd_relative = "src/neural/mod.zig" },
    });

    // GPU module (optional)
    if (options.enable_gpu) {
        const gpu_mod = b.addModule("gpu", .{
            .root_source_file = .{ .cwd_relative = "src/gpu/gpu.zig" },
        });
        
        // Set ROCm paths
        const rocm_path = options.rocm_path orelse "/opt/rocm";
        
        // Add ROCm include path
        const include_path = std.fs.path.join(b.allocator, &[_][]const u8{rocm_path, "include"}) catch @panic("OOM");
        gpu_mod.addSystemIncludePath(.{ .cwd_relative = include_path });
        
        // Add ROCm library path
        const lib_path = std.fs.path.join(b.allocator, &[_][]const u8{rocm_path, "lib"}) catch @panic("OOM");
        gpu_mod.addLibraryPath(.{ .cwd_relative = lib_path });
        
        // Link against ROCm system libraries with default options
        const link_options = std.Build.Module.LinkSystemLibraryOptions{
            .needed = true,
            .use_pkg_config = .yes,
            .preferred_link_mode = .dynamic,
        };
        
        // Link system libraries with proper options
        gpu_mod.linkSystemLibrary("hsa-runtime64", link_options);
        gpu_mod.linkSystemLibrary("amdhip64", link_options);
        gpu_mod.linkSystemLibrary("rocblas", link_options);
        gpu_mod.linkSystemLibrary("hipblas", link_options);
        gpu_mod.linkSystemLibrary("MIOpen", link_options);
        
        // Add rpath for ROCm libraries
        gpu_mod.addRPath(.{ .cwd_relative = lib_path });
        
        // Set target-specific flags and define macros
        gpu_mod.addCSourceFlags(&.{
            "-fPIC",
            "-std=c++17",
            "-O3",
            "-DNDEBUG",
            "-D__HIP_PLATFORM_AMD__",
            "-D__HIP_ROCclr__",
            "-lstdc++",  // Link C++ standard library
        });
        
        // Make GPU module available to neural module
        neural_mod.addImport("gpu", gpu_mod);
    }

    // Test patterns executable
    const test_patterns = b.addExecutable(.{
        .name = "test-patterns",
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/test_patterns.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add module dependencies
    test_patterns.root_module.addImport("neural", neural_mod);
    
    // Install the executable
    b.installArtifact(test_patterns);
    
    // Create run step for test patterns
    const run_test_patterns = b.addRunArtifact(test_patterns);
    const run_test_patterns_step = b.step("test-patterns", "Run test patterns for QuantumCache");
    run_test_patterns_step.dependOn(&run_test_patterns.step);
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_test_patterns.addArgs(args);
    }
}
