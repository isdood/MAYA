const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const time = std.time;
const math = std.math;
const crypto = std.crypto;
const neural = @import("neural");
const Pattern = neural.Pattern;
const profiling = neural.profiling;
const ProfileSection = profiling.ProfileSection;

// Random number generator is passed to functions that need it

// Enable profiling if compiled with -DENABLE_PROFILING
const enable_profiling = @import("build_options").enable_profiling;

// Profiling configuration
const ProfilingConfig = struct {
    const default_warmup_iters = 5;
    const default_benchmark_iters = 100;
    const default_pattern_size = 256; // Default pattern size for benchmarks
};

/// Measures execution time of a function and prints the result
fn measureExecution(comptime name: []const u8, func: anytype, context: anytype) !void {
    const start = std.time.nanoTimestamp();
    try func(context);
    const end = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
    std.debug.print("✅ {s}: {d:.2} ms\n", .{ name, elapsed_ms });
}

/// Context for benchmark functions
const BenchmarkContext = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    size: usize,
};

/// Profiles a specific section of code
fn profileSection(name: []const u8, func: anytype, args: anytype) @TypeOf(@call(.auto, func, args)) {
    if (enable_profiling) {
        profiling.beginSection(name);
        defer profiling.endSection();
    }
    
    // Handle functions with different parameter counts
    const result = @call(.auto, func, args);
    return result;
}

/// Profiles a block of code
fn profileBlock(comptime name: []const u8, block: anytype) @TypeOf(block) {
    if (enable_profiling) {
        profiling.beginSection(name);
        defer profiling.endSection();
    }
    return block;
}

/// Measures memory usage of a pattern
fn measurePatternMemory(name: []const u8, allocator: std.mem.Allocator, width: usize, height: usize) !void {
    const pattern = try profileSection("create_pattern", struct {
        fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize) !*Pattern {
            return createSimplePattern(alloc, id, w, h, true);
        }
    }.f, .{ allocator, name, width, height });
    defer pattern.deinit(allocator);
    
    const size_mb = @as(f64, @floatFromInt(pattern.data.len)) / (1024.0 * 1024.0);
    std.debug.print("Pattern '{s}' memory usage: {d:.2} MB ({}x{}, {} bytes)\n", .{
        name, 
        size_mb,
        width, 
        height,
        pattern.data.len
    });
}

pub fn createSimplePattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize, deinit_after: bool) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    
    const pattern = try Pattern.initPattern(allocator, @intCast(width), @intCast(height), 1);
    
    // Fill with simple pattern (e.g., gradient)
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = y * width + x;
            pattern.data[idx] = @as(u8, @intFromFloat(255.0 * (@as(f32, @floatFromInt(x + y)) / @as(f32, @floatFromInt(width + height - 2)))));
        }
    }
    
    // If deinit_after is true, we need to make a copy that we can safely free
    if (deinit_after) {
        const pattern_copy = try Pattern.initPattern(allocator, @intCast(width), @intCast(height), 1);
        @memcpy(pattern_copy.data, pattern.data);
        pattern.deinit(allocator);
        return pattern_copy;
    } else {
        return pattern;
    }
}

pub fn createRandomPattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize, deinit_after: bool) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    
    const pattern = try Pattern.initPattern(allocator, @intCast(width), @intCast(height), 1);
    
    // Fill with random data using crypto.random
    std.crypto.random.bytes(pattern.data);
    
    // If deinit_after is true, we need to make a copy that we can safely free
    if (deinit_after) {
        const pattern_copy = try Pattern.initPattern(allocator, @intCast(width), @intCast(height), 1);
        @memcpy(pattern_copy.data, pattern.data);
        pattern.deinit(allocator);
        return pattern_copy;
    } else {
        return pattern;
    }
}

pub fn createCheckerboardPattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize, tile_size: usize, deinit_after: bool) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    _ = deinit_after; // Mark as used to avoid unused parameter warning
    
    const pattern = try Pattern.initPattern(allocator, @intCast(width), @intCast(height), 1);
    
    // Fill with checkerboard pattern using the specified tile size
    for (0..height) |y| {
        const tile_y = y / tile_size;
        for (0..width) |x| {
            const tile_x = x / tile_size;
            const idx = y * width + x;
            // Alternate between black and white based on tile position
            pattern.data[idx] = if ((tile_x + tile_y) % 2 == 0) 0 else 255;
        }
    }
    
    pattern.pattern_type = .Visual;
    pattern.complexity = 0.7;
    pattern.stability = 0.9;
    
    return pattern;
}

/// Runs a series of benchmarks on pattern creation and processing
fn runBenchmarks(allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== Running Benchmarks ===\n", .{});
    
    // Test different pattern sizes
    const ctx = BenchmarkContext{
        .allocator = allocator,
        .id = "benchmark",
        .size = 256, // Fixed size for consistent benchmarking
    };
    
    std.debug.print("\n=== Running benchmarks with size {d}x{d} ===\n", .{ctx.size, ctx.size});
    
    // Benchmark simple pattern creation
    try measureExecution("simple_pattern", struct {
        fn f(context: BenchmarkContext) !void {
            var pattern = try createSimplePattern(context.allocator, context.id, 
                context.size, context.size, false);
            defer pattern.deinit(context.allocator);
            // Access pattern data to prevent optimization
            _ = pattern.data[0];
        }
    }.f, ctx);
    
    // Benchmark random pattern creation
    try measureExecution("random_pattern", struct {
        fn f(context: BenchmarkContext) !void {
            var pattern = try createRandomPattern(context.allocator, context.id, 
                context.size, context.size, false);
            defer pattern.deinit(context.allocator);
            // Access pattern data to prevent optimization
            _ = pattern.data[0];
        }
    }.f, ctx);
    
    // Benchmark checkerboard pattern creation
    try measureExecution("checker_pattern", struct {
        fn f(context: BenchmarkContext) !void {
            var pattern = try createCheckerboardPattern(context.allocator, context.id, 
                context.size, context.size, 10, false);
            defer pattern.deinit(context.allocator);
            // Access pattern data to prevent optimization
            _ = pattern.data[0];
        }
    }.f, ctx);
}

/// Runs memory usage tests
fn runMemoryTests(allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== Memory Usage Tests ===\n", .{});
    
    // Test different pattern sizes
    const sizes = [_]usize{ 64, 128, 256, 512, 1024 };
    
    for (sizes) |size| {
        const name = try std.fmt.allocPrint(allocator, "size_{}", .{size});
        defer allocator.free(name);
        try measurePatternMemory(name, allocator, size, size);
    }
}

/// Main entry point with profiling support
pub fn main() !void {
    // Check if we're in quick mode
    const argv0 = std.mem.span(std.os.argv[0]);
    const base_name = std.fs.path.basenamePosix(argv0);
    const is_quick = std.mem.eql(u8, base_name, "quick");
    
    // No need to initialize crypto.random, it's ready to use
    
    // Initialize memory tracking
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .enable_memory_limit = true,
        .safety = true,
    }){};
    defer _ = gpa.deinit();
    
    const allocator = gpa.allocator();
    
    // Initialize global pattern pool with memory limits
    try neural.initGlobalPool(allocator);
    defer neural.deinitGlobalPool();
    
    // Initialize profiler if enabled
    if (enable_profiling) {
        try profiling.initProfiler(allocator);
        defer profiling.deinitProfiler();
    }
    
    // Start main profiling section
    const main_section = if (enable_profiling) 
        ProfileSection.init("main") else undefined;
    defer if (enable_profiling) main_section.deinit();
    
    // Run basic pattern creation tests
    {
        const section = if (enable_profiling) 
            ProfileSection.init("basic_tests") else undefined;
        defer if (enable_profiling) section.deinit();
        
        std.debug.print("\n=== Basic Pattern Creation Tests ===\n", .{});
        
        // Test simple gradient pattern
        {
            std.debug.print("\nCreating simple gradient pattern...\n", .{});
            const pattern = try profileSection("create_gradient", struct {
                fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize) !*Pattern {
                    return createSimplePattern(alloc, id, w, h, false);
                }
            }.f, .{ allocator, "gradient", 100, 100 });
            defer pattern.deinit(allocator);
            std.debug.print("  - Created pattern: {d}x{d} ({} bytes)\n", 
                .{pattern.width, pattern.height, pattern.data.len});
        }
        
        // Test random noise pattern
        {
            std.debug.print("\nCreating random noise pattern...\n", .{});
            const pattern = try profileSection("create_random", struct {
                fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize) !*Pattern {
                    return createRandomPattern(alloc, id, w, h, false);
                }
            }.f, .{ allocator, "random", 100, 100 });
            defer pattern.deinit(allocator);
            std.debug.print("  - Created pattern: {d}x{d} ({} bytes)\n", 
                .{pattern.width, pattern.height, pattern.data.len});
        }
        
        // Test checkerboard pattern
        {
            std.debug.print("\nCreating checkerboard pattern...\n", .{});
            const pattern = try profileSection("create_checkerboard", struct {
                fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize) !*Pattern {
                    return createCheckerboardPattern(alloc, id, w, h, 10, false);
                }
            }.f, .{ allocator, "checker", 100, 100 });
            defer pattern.deinit(allocator);
            std.debug.print("  - Created pattern: {d}x{d} ({} bytes)\n", 
                .{pattern.width, pattern.height, pattern.data.len});
        }
    }
    
    // Run benchmarks if not in quick mode
    if (!is_quick) {
        try runBenchmarks(allocator);
        try runMemoryTests(allocator);
    }
    
    // Print profiling summary if enabled
    if (enable_profiling) {
        try profiling.printSummary(std.io.getStdErr().writer());
    }
    
    std.debug.print("\nAll tests completed successfully!\n", .{});
}
