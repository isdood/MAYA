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

/// Measures execution time of a function
fn measureExecution(comptime name: []const u8, func: anytype, args: anytype) !void {
    const warmup_iters = 3;  // Reduced for brevity
    const bench_iters = 10;  // Reduced for brevity
    
    // Warmup
    for (0..warmup_iters) |_| {
        _ = try @call(.auto, func, args);
    }
    
    // Benchmark
    var min_time: u64 = math.maxInt(u64);
    var max_time: u64 = 0;
    var total_time: u64 = 0;
    
    for (0..bench_iters) |_| {
        const start = time.nanoTimestamp();
        _ = try @call(.auto, func, args);
        const elapsed = @as(u64, @intCast(time.nanoTimestamp() - start));
        
        min_time = @min(min_time, elapsed);
        max_time = @max(max_time, elapsed);
        total_time += elapsed;
    }
    
    const avg_time = @as(f64, @floatFromInt(total_time)) / @as(f64, @floatFromInt(bench_iters));
    
    std.debug.print(
        "{s: <20} - Min: {d:8.3}µs, Avg: {d:8.3}µs, Max: {d:8.3}µs\n",
        .{
            name,
            @as(f64, @floatFromInt(min_time)) / 1000.0,
            avg_time / 1000.0,
            @as(f64, @floatFromInt(max_time)) / 1000.0,
        },
    );
}

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
    
    const pixel_count = width * height * 4; // RGBA
    var data = try allocator.alloc(u8, pixel_count);
    errdefer if (deinit_after) allocator.free(data);
    
    // Create a simple gradient pattern
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = (y * width + x) * 4;
            data[idx] = @as(u8, @intCast((x * 255) / width));      // R
            data[idx + 1] = @as(u8, @intCast((y * 255) / height)); // G
            data[idx + 2] = @as(u8, @intCast(((x + y) * 255) / (width + height))); // B
            data[idx + 3] = 255; // A
        }
    }
    
    const pattern = try Pattern.init(allocator, data, width, height);
    
    if (deinit_after) {
        allocator.free(data);
    } else {
        // If we're not deinitializing, ensure the pattern owns the data
        pattern.owns_data = true;
    }
    
    pattern.pattern_type = .Visual;
    pattern.complexity = 0.5;
    pattern.stability = 0.8;
    
    return pattern;
}

pub fn createRandomPattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize, deinit_after: bool) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    
    const pixel_count = width * height * 4; // RGBA
    var data = try allocator.alloc(u8, pixel_count);
    errdefer if (deinit_after) allocator.free(data);
    
    // Fill with random data
    std.crypto.random.bytes(data);
    
    // Ensure alpha is always 255
    var i: usize = 3; // Start at first alpha channel
    while (i < pixel_count) : (i += 4) {
        data[i] = 255;
    }
    
    const pattern = try Pattern.init(allocator, data, width, height);
    
    if (deinit_after) {
        allocator.free(data);
    } else {
        // If we're not deinitializing, ensure the pattern owns the data
        pattern.owns_data = true;
    }
    
    pattern.pattern_type = .Quantum;
    pattern.complexity = 0.9;
    pattern.stability = 0.1;
    
    return pattern;
}

pub fn createCheckerboardPattern(allocator: std.mem.Allocator, id: []const u8, width: usize, height: usize, tile_size: usize, deinit_after: bool) !*Pattern {
    _ = id; // Mark as used to avoid unused parameter warning
    
    const pixel_count = width * height * 4; // RGBA
    var data = try allocator.alloc(u8, pixel_count);
    errdefer if (deinit_after) allocator.free(data);
    
    // Create a checkerboard pattern
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = (y * width + x) * 4;
            const tile_x = x / tile_size;
            const tile_y = y / tile_size;
            const is_black = (tile_x + tile_y) % 2 == 0;
            
            data[idx] = if (is_black) 0 else 255;     // R
            data[idx + 1] = if (is_black) 0 else 255;  // G
            data[idx + 2] = if (is_black) 0 else 255;  // B
            data[idx + 3] = 255;                       // A
        }
    }
    
    const pattern = try Pattern.init(allocator, data, width, height);
    
    if (deinit_after) {
        allocator.free(data);
    } else {
        // If we're not deinitializing, ensure the pattern owns the data
        pattern.owns_data = true;
    }
    
    pattern.pattern_type = .Hybrid;
    pattern.complexity = 0.7;
    pattern.stability = 0.6;
    
    return pattern;
}

/// Runs a series of benchmarks on pattern creation and processing
fn runBenchmarks(allocator: std.mem.Allocator) !void {
    std.debug.print("\n=== Running Benchmarks ===\n", .{});
    
    // Test different pattern sizes
    const sizes = [_]usize{ 64, 128, 256 };
    
    for (sizes) |size| {
        std.debug.print("\n=== Pattern Size: {}x{} ===\n", .{size, size});
        
        // Benchmark simple pattern creation
        {
            var pattern: ?*Pattern = null;
            try measureExecution("simple_pattern", struct {
                fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize, p: *?*Pattern) !void {
                    p.* = try createSimplePattern(alloc, id, w, h, false);
                }
            }.f, .{allocator, "bench", size, size, &pattern});
            if (pattern) |p| {
                p.deinit(allocator);
                allocator.destroy(p);
            }
        }
        
        // Benchmark random pattern creation
        {
            var pattern: ?*Pattern = null;
            try measureExecution("random_pattern", struct {
                fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize, p: *?*Pattern) !void {
                    p.* = try createRandomPattern(alloc, id, w, h, false);
                }
            }.f, .{allocator, "bench_random", size, size, &pattern});
            if (pattern) |p| {
                p.deinit(allocator);
                allocator.destroy(p);
            }
        }
        
        // Benchmark checkerboard pattern creation
        {
            var pattern: ?*Pattern = null;
            try measureExecution("checker_pattern", struct {
                fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize, p: *?*Pattern) !void {
                    p.* = try createCheckerboardPattern(alloc, id, w, h, 10, false);
                }
            }.f, .{allocator, "bench_checker", size, size, &pattern});
            if (pattern) |p| {
                p.deinit(allocator);
                allocator.destroy(p);
            }
        }
    }
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
        
        std.debug.print("=== Basic Pattern Creation Tests ===\n", .{});
        
        // Test simple gradient pattern
        {
            std.debug.print("\nCreating simple gradient pattern...\n", .{});
            const pattern = try profileSection("create_gradient", struct {
                fn f(alloc: std.mem.Allocator, id: []const u8, w: usize, h: usize) !*Pattern {
                    return createSimplePattern(alloc, id, w, h, false);
                }
            }.f, .{ allocator, "gradient", 100, 100 });
            defer pattern.deinit(allocator);
            std.debug.print("  - Created pattern: {}x{} ({} bytes)\n", 
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
            std.debug.print("  - Created pattern: {}x{} ({} bytes)\n", 
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
            std.debug.print("  - Created pattern: {}x{} ({} bytes)\n", 
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
