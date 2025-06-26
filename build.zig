const std = @import("std");

// Build CUDA kernel
fn buildCudaKernel(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const cuda_kernel = b.addObject(.{
        .name = "spiral_convolution_kernel",
        .target = target,
        .optimize = optimize,
    });
    
    // Add CUDA source file with appropriate flags
    cuda_kernel.addCSourceFile(.{
        .file = .{ .cwd_relative = "src/quantum_cache/cuda/spiral_convolution.cu" },
        .flags = &[_][]const u8{
            "-std=c++17",
            "--ptxas-options=-v",
            "-O3",
            "-Xcompiler", "-fPIC",
        },
    });
    
    // Add include paths
    cuda_kernel.addIncludePath(.{ .cwd_relative = "src/quantum_cache" });
    cuda_kernel.addSystemIncludePath(.{ .cwd_relative = "/usr/local/cuda/include" });
    
    // Link against CUDA libraries
    cuda_kernel.linkSystemLibrary("cuda");
    cuda_kernel.linkSystemLibrary("cudart");
    cuda_kernel.linkLibCpp();
    
    // Set CUDA compiler
    const which_nvcc = b.addSystemCommand(&.{"which", "nvcc"});
    cuda_kernel.step.dependOn(&which_nvcc.step);
    
    return cuda_kernel;
}

pub fn build(b: *std.Build) !void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    
    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for build options
    const build_options_module = b.createModule(.{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "build_options.zig",
        }}
    });

    // Create a module for the neural network
    const neural_module = b.createModule(.{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/neural/neural.zig",
        }}
    });
    
    // Add include paths for the neural module
    neural_module.addIncludePath(.{ .cwd_relative = "src/neural" });

    // Create test-patterns executable
    const test_patterns_exe = b.addExecutable(.{
        .name = "test-patterns",
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/test_patterns.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add modules to the test-patterns executable
    test_patterns_exe.root_module.addImport("neural", neural_module);
    test_patterns_exe.root_module.addImport("build_options", build_options_module);
    
    // Add include paths
    test_patterns_exe.addIncludePath(.{ .cwd_relative = "src" });
    test_patterns_exe.addIncludePath(.{ .cwd_relative = "src/neural" });
    test_patterns_exe.addSystemIncludePath(.{ .cwd_relative = "src/neural" });
    
    // Link against libc if needed
    test_patterns_exe.linkLibC();
    
    // Install the test-patterns executable
    b.installArtifact(test_patterns_exe);
    
    // Create run step for test-patterns
    const run_test_patterns_cmd = b.addRunArtifact(test_patterns_exe);
    run_test_patterns_cmd.step.dependOn(b.getInstallStep());
    
    // Create pattern recognition test executable
    const pattern_recognition_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/pattern_recognition_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add modules to the pattern recognition test
    pattern_recognition_test.root_module.addImport("neural", neural_module);
    pattern_recognition_test.root_module.addImport("build_options", build_options_module);
    
    // Add include paths
    pattern_recognition_test.addIncludePath(.{ .cwd_relative = "src" });
    pattern_recognition_test.addSystemIncludePath(.{ .cwd_relative = "src/neural" });
    
    // Create a test step for pattern recognition
    const test_step = b.step("test-pattern-recognition", "Run pattern recognition tests");
    test_step.dependOn(&pattern_recognition_test.step);
    
    // Add pattern recognition tests to the main test step
    const test_all = b.step("test", "Run all tests");
    test_all.dependOn(test_step);
    test_all.dependOn(&test_patterns_exe.step);
    
    // Create run step for pattern recognition tests
    const run_pattern_recognition_test = b.addRunArtifact(pattern_recognition_test);
    run_pattern_recognition_test.step.dependOn(b.getInstallStep());

    // Add a test step for test patterns
    const test_patterns_step = b.step("test_patterns", "Run the test patterns");
    test_patterns_step.dependOn(&run_test_patterns_cmd.step);
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_test_patterns_cmd.addArgs(args);
    }
    
    // Create a run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_test_patterns_cmd.step);
    
    // Add Vulkan source files directly to the test executable

    // Build CUDA kernel
    const enable_cuda = b.option(bool, "enable_cuda", "Enable CUDA support") orelse false;
    var cuda_kernel: ?*std.Build.Step.Compile = null;
    if (enable_cuda) {
        cuda_kernel = try buildCudaKernel(b, target, optimize);
    }
    
    // Create benchmark executable
    const benchmark_exe = b.addExecutable(.{
        .name = "pattern_transform_benchmark",
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/pattern_transform_benchmark.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add CUDA kernel to benchmark
    if (enable_cuda) {
        cuda_kernel = try buildCudaKernel(b, target, optimize);
        benchmark_exe.addObject(cuda_kernel.?);
        
        // Add include paths
        benchmark_exe.addIncludePath(.{ .cwd_relative = "src/quantum_cache" });
        benchmark_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/local/cuda/include" });
        
        benchmark_exe.linkSystemLibrary("cuda");
        benchmark_exe.linkSystemLibrary("cudart");
        benchmark_exe.linkLibCpp();
    }
    
    // Enable Vulkan support
    const enable_vulkan = true;
    var glslc_step: ?*std.Build.Step = null;
    
    if (enable_vulkan) {
        benchmark_exe.linkSystemLibrary("vulkan");
        
        // Create output directory for shaders
        const mkdir = b.addSystemCommand(&.{"mkdir", "-p", "shaders"});
        
        // Add Vulkan shader compilation step
        const glslc = b.addSystemCommand(&.{
            "glslc",
            "src/vulkan/compute/spiral_convolution.comp",
            "-o",
            "shaders/spiral_convolution.comp.spv",
            "-O",
        });
        
        glslc.step.dependOn(&mkdir.step);
        glslc_step = &glslc.step;
        
        // Make sure shaders are compiled before the executable
        if (glslc_step) |step| {
            benchmark_exe.step.dependOn(step);
        }
    }
    
    // Install the benchmark executable
    b.installArtifact(benchmark_exe);
    
    // Create benchmark step
    const benchmark_cmd = b.addRunArtifact(benchmark_exe);
    benchmark_cmd.step.dependOn(b.getInstallStep());
    
    // Add benchmark step to build system
    const benchmark_step = b.step("benchmark", "Run pattern transform benchmarks");
    benchmark_step.dependOn(&benchmark_cmd.step);
    
    // Add CUDA test step
    const cuda_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/cuda_wrapper.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add CUDA kernel to tests
    if (enable_cuda) {
        cuda_test.addObject(cuda_kernel.?);
        
        // Add include paths
        cuda_test.addIncludePath(.{ .cwd_relative = "src/quantum_cache" });
        cuda_test.addSystemIncludePath(.{ .cwd_relative = "/usr/local/cuda/include" });
        
        // Link against CUDA libraries
        cuda_test.linkSystemLibrary("cuda");
        cuda_test.linkSystemLibrary("cudart");
        cuda_test.linkLibCpp();
    }
    
    // Create CUDA test run step
    const cuda_test_run = b.addRunArtifact(cuda_test);
    cuda_test_run.step.dependOn(b.getInstallStep());
    
    // Create CUDA test step
    const cuda_test_step = b.step("test-cuda", "Run CUDA wrapper tests");
    cuda_test_step.dependOn(&cuda_test_run.step);
    
    // Create minimal Vulkan test executable
    const minimal_vulkan_test = b.addExecutable(.{
        .name = "minimal_vulkan_test",
        .root_source_file = .{ .cwd_relative = "src/vulkan/minimal_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link against libc and Vulkan
    minimal_vulkan_test.linkLibC();
    minimal_vulkan_test.linkSystemLibrary("vulkan");
    
    // Add include paths
    minimal_vulkan_test.addIncludePath(.{ .cwd_relative = "src" });
    minimal_vulkan_test.addIncludePath(.{ .cwd_relative = "src/vulkan" });
    minimal_vulkan_test.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    minimal_vulkan_test.addSystemIncludePath(.{ .cwd_relative = "/usr/include/vulkan" });
    
    // Create a run step for the minimal test
    const minimal_test_run = b.addRunArtifact(minimal_vulkan_test);
    const minimal_test_step = b.step("test-minimal-vulkan", "Run minimal Vulkan test");
    minimal_test_step.dependOn(&minimal_test_run.step);
    
    // Create Vulkan test executable
    const vulkan_test_exe = b.addExecutable(.{
        .name = "test_vulkan",
        .root_source_file = .{ .cwd_relative = "src/vulkan/test_vulkan.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link against libc for C allocator
    vulkan_test_exe.linkLibC();
    
    // Add include paths
    vulkan_test_exe.addIncludePath(.{ .cwd_relative = "src" });
    vulkan_test_exe.addIncludePath(.{ .cwd_relative = "src/vulkan" });
    vulkan_test_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    vulkan_test_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include/vulkan" });
    
    // Link against Vulkan
    vulkan_test_exe.linkSystemLibrary("vulkan");
    
    // Create the Vulkan module first
    const vk_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/vk.zig" },
    });
    
    // Create the memory module
    const memory_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/memory.zig" },
    });
    
    // Create the context module
    const context_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/context.zig" },
    });
    
    // Create the pipeline module
    const pipeline_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/compute/pipeline.zig" },
    });
    
    // Create the debug module
    const debug_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/vulkan/debug.zig" },
    });
    
    // Set up module dependencies
    // Memory module needs vk
    memory_module.addImport("vk", vk_module);
    
    // Context module needs vk
    context_module.addImport("vk", vk_module);
    
    // Pipeline module needs vk and context
    pipeline_module.addImport("vk", vk_module);
    pipeline_module.addImport("context", context_module);
    
    // Debug module needs vk
    debug_module.addImport("vk", vk_module);
    
    // Add all modules to the test executable
    vulkan_test_exe.root_module.addImport("vk", vk_module);
    vulkan_test_exe.root_module.addImport("memory", memory_module);
    vulkan_test_exe.root_module.addImport("context", context_module);
    vulkan_test_exe.root_module.addImport("pipeline", pipeline_module);
    vulkan_test_exe.root_module.addImport("debug", debug_module);
    
    if (glslc_step) |step| {
        vulkan_test_exe.step.dependOn(step);
    }
    b.installArtifact(vulkan_test_exe);
    
    // Create a run step for the Vulkan test
    const vulkan_test_run = b.addRunArtifact(vulkan_test_exe);
    
    // Create Vulkan test step
    const vulkan_test_step = b.step("test-vulkan", "Run Vulkan compute tests");
    vulkan_test_step.dependOn(&vulkan_test_run.step);
    
    // Add CUDA tests to the main test step
    test_all.dependOn(cuda_test_step);
    test_all.dependOn(vulkan_test_step);
    
    // Add CUDA integration test
    const cuda_integration_test = b.addExecutable(.{
        .name = "test_cuda_integration",
        .root_source_file = .{ .cwd_relative = "scripts/test_cuda_integration.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link against CUDA
    cuda_integration_test.linkSystemLibrary("cuda");
    cuda_integration_test.linkSystemLibrary("cudart");
    cuda_integration_test.linkLibC();
    
    // Add test step
    const run_cuda_integration = b.addRunArtifact(cuda_integration_test);
    const cuda_integration_step = b.step("test-cuda-integration", "Test CUDA integration");
    cuda_integration_step.dependOn(&run_cuda_integration.step);
    test_all.dependOn(cuda_integration_step);
    
    // Add Vulkan compute test (using the existing vulkan_test_exe)
    const run_vulkan_test = b.addRunArtifact(vulkan_test_exe);
    const vulkan_compute_step = b.step("test-vulkan-compute", "Test Vulkan compute pipeline");
    vulkan_compute_step.dependOn(&run_vulkan_test.step);
    test_all.dependOn(vulkan_compute_step);
    
    // Create a test-patterns step (alias for run)
    const run_test_patterns_step = b.step("test-patterns", "Run the test patterns application");
    run_test_patterns_step.dependOn(&run_test_patterns_cmd.step);
    
    // Create hypercube library
    const hypercube_lib = b.addStaticLibrary(.{
        .name = "hypercube",
        .root_source_file = .{ .cwd_relative = "src/core/hypercube/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add hypercube library to install step
    b.installArtifact(hypercube_lib);
    
    // Create hypercube executable
    const hypercube_exe = b.addExecutable(.{
        .name = "hypercube",
        .root_source_file = .{ .cwd_relative = "src/core/hypercube/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Install hypercube executable
    b.installArtifact(hypercube_exe);
    
    // Create run step for hypercube
    const run_hypercube_cmd = b.addRunArtifact(hypercube_exe);
    run_hypercube_cmd.step.dependOn(b.getInstallStep());
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_hypercube_cmd.addArgs(args);
    }
    
    // Create hypercube test step
    const hypercube_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/core/hypercube/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Create a test step for hypercube
    const hypercube_test_step = b.step("test-hypercube", "Run HYPERCUBE tests");
    hypercube_test_step.dependOn(&hypercube_test.step);
    
    // Add hypercube tests to the main test step
    test_all.dependOn(hypercube_test_step);
    
    // Create hypercube run step
    const hypercube_run_step = b.step("hypercube", "Run HYPERCUBE example");
    hypercube_run_step.dependOn(&run_hypercube_cmd.step);
    
    // Add hypercube to the main run step
    run_step.dependOn(&run_hypercube_cmd.step);
}
