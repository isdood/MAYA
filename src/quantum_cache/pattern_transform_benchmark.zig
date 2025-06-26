const std = @import("std");
const Pattern = @import("./pattern_transform.zig").Pattern;
const TransformParams = @import("./pattern_transform.zig").TransformParams;
const PatternMatchParams = @import("./pattern_transform.zig").PatternMatchParams;
const Vec4 = @import("./pattern_transform.zig").Vec4;

// Benchmark configuration
const config = struct {
    const warmup_runs = 3;
    const benchmark_runs = 10;
    const pattern_size = 64; // 64x64x4x4 pattern (width, height, depth, time)
    const output_file = "pattern_transform_benchmark.json";
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("🚀 Starting 4D Pattern Transform Benchmark...\n", .{});
    
    // Create a test pattern with random data
    const pattern = try createTestPattern(allocator, config.pattern_size);
    defer {
        pattern.deinit(allocator);
        allocator.destroy(pattern);
    }
    
    // Define test cases
    const test_cases = [_]struct {
        name: []const u8,
        params: TransformParams,
    }{
        .{
            .name = "identity_2d",
            .params = .{
                .match_params = PatternMatchParams.default2D(),
            },
        },
        .{
            .name = "scale_2d",
            .params = .{
                .scale = Vec4.new(1.5, 1.5, 1.0, 1.0),
                .match_params = PatternMatchParams.default2D(),
            },
        },
        .{
            .name = "rotate_2d",
            .params = .{
                .rotation = Vec4.new(0, 0, 45.0, 0), // 45 degree rotation in XY plane
                .match_params = PatternMatchParams.default2D(),
            },
        },
        .{
            .name = "identity_4d",
            .params = .{
                .match_params = PatternMatchParams.default4D(),
            },
        },
        .{
            .name = "gravity_well",
            .params = .{
                .match_params = .{
                    .gravity_well = true,
                    .well_center = Vec4.new(0.5, 0.5, 0.5, 0.5),
                    .well_mass = 2.0,
                    .well_radius = 0.7,
                },
            },
        },
        .{
            .name = "spiral_processing",
            .params = .{
                .match_params = .{
                    .spiral_processing = true,
                    .spiral_turns = 3,
                },
            },
        },
    };
    
    var results = std.ArrayList(struct {
        name: []const u8,
        avg_time_ns: u64,
        memory_used: usize,
    }).init(allocator);
    defer results.deinit();
    
    // Run benchmarks
    for (test_cases) |test_case| {
        try stdout.print("\n🧪 Benchmarking: {s}\n", .{test_case.name});
        
        // Warmup
        try stdout.print("  Warming up... ", .{});
        for (0..config.warmup_runs) |_| {
            const transformed = try test_case.params.apply4DTransform(pattern, test_case.params);
            transformed.deinit(allocator);
            allocator.destroy(transformed);
        }
        try stdout.print("Done\n", .{});
        
        // Benchmark
        try stdout.print("  Running benchmark... ", .{});
        var total_time: u64 = 0;
        var max_memory: usize = 0;
        
        for (0..config.benchmark_runs) |i| {
            // Reset memory tracking
            const start_mem = std.heap.page_allocator.allocated_bytes;
            
            // Time the transformation
            const start_time = std.time.nanoTimestamp();
            const transformed = try test_case.params.apply4DTransform(pattern, test_case.params);
            const end_time = std.time.nanoTimestamp();
            
            // Calculate memory used
            const end_mem = std.heap.page_allocator.allocated_bytes;
            const memory_used = end_mem - start_mem;
            max_memory = @max(max_memory, memory_used);
            
            // Clean up
            transformed.deinit(allocator);
            allocator.destroy(transformed);
            
            // Record time
            total_time += @as(u64, @intCast(end_time - start_time));
            
            try stdout.print(".", .{});
            if ((i + 1) % 10 == 0) try stdout.print("\n  ", .{});
        }
        
        const avg_time_ns = total_time / config.benchmark_runs;
        try results.append(.{
            .name = test_case.name,
            .avg_time_ns = avg_time_ns,
            .memory_used = max_memory,
        });
        
        try stdout.print("\n  ✅ Average time: {d:.2} ms\n", .{@as(f64, @floatFromInt(avg_time_ns)) / 1_000_000.0});
        try stdout.print("  💾 Max memory used: {d:.2} MB\n", .{@as(f64, @floatFromInt(max_memory)) / (1024 * 1024)});
    }
    
    // Save results to JSON
    try saveResults(allocator, config.output_file, results.items);
    try stdout.print("\n📊 Results saved to {s}\n", .{config.output_file});
}

fn createTestPattern(allocator: std.mem.Allocator, size: u32) !*Pattern {
    const depth = 4;
    const time_steps = 4;
    const channels = 4; // RGBA
    const total_elements = size * size * depth * time_steps * channels;
    
    // Allocate and initialize with random data
    const data = try allocator.alloc(f32, total_elements);
    var prng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
    const rand = prng.random();
    
    for (0..total_elements) |i| {
        data[i] = rand.float(f32);
    }
    
    return try Pattern.create(allocator, data, size, size, depth, time_steps);
}

fn saveResults(
    allocator: std.mem.Allocator,
    path: []const u8,
    results: []const struct { name: []const u8, avg_time_ns: u64, memory_used: usize },
) !void {
    var json_array = std.ArrayList(u8).init(allocator);
    defer json_array.deinit();
    
    const writer = json_array.writer();
    try writer.writeAll("[\n");
    
    for (results, 0..) |result, i| {
        if (i > 0) try writer.writeAll(",\n");
        try writer.print("  {{\"name\": \"{s}\", \"avg_time_ms\": {d:.2}, \"memory_mb\": {d:.2}}}", .{
            result.name,
            @as(f64, @floatFromInt(result.avg_time_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(result.memory_used)) / (1024 * 1024),
        });
    }
    
    try writer.writeAll("\n]");
    
    try std.fs.cwd().writeFile(path, json_array.items);
}
