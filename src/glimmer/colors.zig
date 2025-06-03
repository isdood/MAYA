const std = @import("std");

/// GLIMMER color system for quantum-aware visual patterns
pub const GlimmerColors = struct {
    pub const primary = "#B19CD9";    // Stellar Primary
    pub const secondary = "#87CEEB";  // Neural Flow
    pub const accent = "#FFB7C5";     // Quantum Sparkle
    pub const neural = "#98FB98";     // Neural Pathways
    pub const cosmic = "#DDA0DD";     // Cosmic Harmony

    /// Convert hex color to RGB components
    pub fn hexToRgb(hex: []const u8) !struct { r: u8, g: u8, b: u8 } {
        if (hex.len != 7 or hex[0] != '#') {
            return error.InvalidHexColor;
        }

        const r = try std.fmt.parseInt(u8, hex[1..3], 16);
        const g = try std.fmt.parseInt(u8, hex[3..5], 16);
        const b = try std.fmt.parseInt(u8, hex[5..7], 16);

        return .{ .r = r, .g = g, .b = b };
    }

    /// Create a quantum-aware color transition
    pub fn createTransition(from: []const u8, to: []const u8, steps: usize) ![][]const u8 {
        const from_rgb = try hexToRgb(from);
        const to_rgb = try hexToRgb(to);

        var transitions = try std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, steps);
        defer transitions.deinit();

        for (0..steps) |i| {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps - 1));
            
            const r = @as(u8, @intFromFloat(@as(f32, @floatFromInt(from_rgb.r)) * (1 - t) + @as(f32, @floatFromInt(to_rgb.r)) * t));
            const g = @as(u8, @intFromFloat(@as(f32, @floatFromInt(from_rgb.g)) * (1 - t) + @as(f32, @floatFromInt(to_rgb.g)) * t));
            const b = @as(u8, @intFromFloat(@as(f32, @floatFromInt(from_rgb.b)) * (1 - t) + @as(f32, @floatFromInt(to_rgb.b)) * t));

            const hex = try std.fmt.allocPrint(
                std.heap.page_allocator,
                "#{X:0>2}{X:0>2}{X:0>2}",
                .{ r, g, b }
            );

            try transitions.append(hex);
        }

        return transitions.toOwnedSlice();
    }
};

test "GLIMMER color system" {
    const colors = GlimmerColors;
    
    // Test hex to RGB conversion
    const rgb = try colors.hexToRgb(colors.primary);
    try std.testing.expectEqual(@as(u8, 0xB1), rgb.r);
    try std.testing.expectEqual(@as(u8, 0x9C), rgb.g);
    try std.testing.expectEqual(@as(u8, 0xD9), rgb.b);

    // Test color transition
    const transition = try colors.createTransition(colors.primary, colors.secondary, 3);
    defer std.heap.page_allocator.free(transition);
    
    try std.testing.expectEqual(@as(usize, 3), transition.len);
    try std.testing.expectEqualStrings(colors.primary, transition[0]);
    try std.testing.expectEqualStrings(colors.secondary, transition[2]);
} 