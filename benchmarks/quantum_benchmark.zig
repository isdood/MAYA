const std = @import("std");
const time = std.time;
const print = std.debug.print;
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Import the quantum processor module
const QuantumProcessor = @import("../src/neural/quantum_processor.zig").QuantumProcessor;

// Import other required modules
const quantum_types = @import("../src/neural/quantum_types.zig");
const crystal_computing = @import("../src/neural/crystal_computing.zig");

const BENCHMARK_ITERATIONS = 1000;
const PATTERN_SIZES = [_]usize{ 4, 16, 64, 256, 1024 };

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try stdout.print("=== Quantum Processor Benchmark ===\n\n", .{});
    
    // Test with different configurations
    const configs = [_]struct {
        name: []const u8,
        config: QuantumProcessor.QuantumConfig,
    }{
        .{
            .name = "Scalar",
            .config = .{
                .use_parallel_execution = false,
                .use_simd = false,
                .optimize_circuit = false,
            },
        },
        .{
            .name = "Parallel",
            .config = .{
                .use_parallel_execution = true,
                .use_simd = false,
                .optimize_circuit = false,
            },
        },
        .{
            .name = "SIMD",
            .config = .{
                .use_parallel_execution = true,
                .use_simd = true,
                .optimize_circuit = true,
            },
        },
    };

    // Run benchmarks for each configuration and pattern size
    for (configs) |config| {
        try stdout.print("\n=== Configuration: {} ===\n", .{config.name});
        
        for (PATTERN_SIZES) |size| {
            // Generate test pattern
            var pattern = try allocator.alloc(u8, size);
            defer allocator.free(pattern);
            
            // Simple pattern: ascending values
            for (0..size) |i| {
                pattern[i] = @intCast(i % 256);
            }
            
            // Initialize processor with current config
            var processor = try QuantumProcessor.init(allocator, config.config);
            defer processor.deinit();
            
            // Warmup
            _ = try processor.processPattern(pattern[0..1]) catch |err| {
                std.debug.print("Error in warmup: {}\n", .{err});
                return err;
            };
            
            // Benchmark
            const start = time.nanoTimestamp();
            
            for (0..BENCHMARK_ITERATIONS) |i| {
                _ = try processor.processPattern(pattern) catch |err| {
                    std.debug.print("Error in iteration {}: {}\n", .{i, err});
                    return err;
                };
            }
            
            const elapsed_ns = time.nanoTimestamp() - start;
            const ns_per_op = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(BENCHMARK_ITERATIONS));
            
            try stdout.print("Pattern size {:4}: {:8.2f} ns/op\n", .{ size, ns_per_op });
        }
    }
}

// To build and run:
// zig build-exe -O ReleaseFast benchmarks/quantum_benchmark.zig -I src/ -lc && ./quantum_benchmark
