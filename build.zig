// 🌌 STARWEAVE Universe Integration
// ✨ Version: 2025.6.18
// 🎨 Pattern: 1.0.0
// ⚡ Seed: 
// 📅 Woven: 2025-06-18 20:29:45
// 👤 Weaver: isdood

const std = @import("std");
const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

// 🌠 STARWEAVE Package Definitions
const packages = struct {
    const starweave = Pkg{
        .name = "starweave",
        .source = .{ .path = "src/starweave/protocol.zig" },
    };

    const glimmer = Pkg{
        .name = "glimmer",
        .source = .{ .path = "src/glimmer/patterns.zig" },
        .dependencies = &[_]Pkg{
            starweave,
        },
    };

    const neural = Pkg{
        .name = "neural",
        .source = .{ .path = "src/neural/bridge.zig" },
        .dependencies = &[_]Pkg{
            starweave,
            glimmer,
        },
    };

    const colors = Pkg{
        .name = "colors",
        .source = .{ .path = "src/glimmer/colors.zig" },
        .dependencies = &[_]Pkg{
            glimmer,
        },
    };
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 🌟 Main MAYA executable
    const maya = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 🧠 Add STARWEAVE packages
    maya.addPackage(packages.starweave);
    maya.addPackage(packages.glimmer);
    maya.addPackage(packages.neural);
    maya.addPackage(packages.colors);

    // 🌌 WASM build configuration
    const wasm = b.addExecutable(.{
        .name = "maya",
        .root_source_file = .{ .path = "src/wasm.zig" },
        .target = b.standardTargetOptions(.{
            .default_target = .{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            },
        }),
        .optimize = optimize,
    });

    wasm.addPackage(packages.starweave);
    wasm.addPackage(packages.glimmer);

    // 🧪 Test configuration
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    main_tests.addPackage(packages.starweave);
    main_tests.addPackage(packages.glimmer);

    const test_step = b.step("test", "Run MAYA quantum tests");
    test_step.dependOn(&main_tests.step);

    // ⚡ Install steps
    b.installArtifact(maya);
    b.installArtifact(wasm);
}
