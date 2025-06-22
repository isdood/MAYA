// 🎨 MAYA Pattern Generator CLI
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-21
// 👤 Author: isdood

const std = @import("std");
const neural = @import("neural");
const PatternSynthesis = neural.pattern_synthesis.PatternSynthesis;
const PatternAlgorithm = neural.pattern_generator.PatternAlgorithm;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try stdout.writeAll("🎨 MAYA Pattern Generator\n");
    try stdout.writeAll("✨ Generating sample patterns...\n\n");

    // Initialize pattern synthesis
    var synthesis = try PatternSynthesis.init(allocator);
    defer synthesis.deinit();

    // List of algorithms to test
    const algorithms = [_]struct { name: []const u8, algo: PatternAlgorithm }{
        .{ .name = "Random", .algo = .Random },
        .{ .name = "Gradient", .algo = .Gradient },
        .{ .name = "Wave", .algo = .Wave },
        .{ .name = "Spiral", .algo = .Spiral },
        .{ .name = "Checkerboard", .algo = .Checkerboard },
        .{ .name = "Fractal", .algo = .Fractal },
    };

    // Generate and save sample patterns
    for (algorithms) |item| {
        try stdout.print("Generating {s} pattern... ", .{item.name});
        
        // Generate the pattern
        try synthesis.generatePattern(item.algo);
        
        try stdout.writeAll("✅\n");
    }

    try stdout.writeAll("\n✨ All patterns generated successfully!\n");
}

// Add the pattern generator to the build system
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const exe = b.addExecutable(.{
        .name = "maya-pattern-gen",
        .root_source_file = .{ .path = "src/pattern_gen.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add dependencies
    exe.addModule("neural", b.createModule(.{
        .source_file = .{ .path = "src/neural/mod.zig" },
    }));
    
    // Install the executable
    b.installArtifact(exe);
    
    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run-pattern-gen", "Run the pattern generator");
    run_step.dependOn(&run_cmd.step);
}
