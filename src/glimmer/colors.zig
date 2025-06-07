const std = @import("std");

/// GLIMMER color system for MAYA GUI
pub const GlimmerColors = struct {
    /// Color structure with RGBA components
    pub const Color = struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8,

        /// Create a color from RGBA values
        pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
            return Color{
                .r = r,
                .g = g,
                .b = b,
                .a = a,
            };
        }

        /// Create a color from a hex value
        pub fn fromHex(hex: u32) Color {
            return Color{
                .r = @intCast((hex >> 24) & 0xFF),
                .g = @intCast((hex >> 16) & 0xFF),
                .b = @intCast((hex >> 8) & 0xFF),
                .a = @intCast(hex & 0xFF),
            };
        }

        /// Convert color to hex value
        pub fn toHex(self: Color) u32 {
            return (@as(u32, self.r) << 24) |
                   (@as(u32, self.g) << 16) |
                   (@as(u32, self.b) << 8) |
                   @as(u32, self.a);
        }

        /// Blend two colors with a given factor
        pub fn blend(a: Color, b: Color, factor: f32) Color {
            const inv_factor = 1.0 - factor;
            return Color{
                .r = @intCast(@as(f32, @floatFromInt(a.r)) * factor + @as(f32, @floatFromInt(b.r)) * inv_factor),
                .g = @intCast(@as(f32, @floatFromInt(a.g)) * factor + @as(f32, @floatFromInt(b.g)) * inv_factor),
                .b = @intCast(@as(f32, @floatFromInt(a.b)) * factor + @as(f32, @floatFromInt(b.b)) * inv_factor),
                .a = @intCast(@as(f32, @floatFromInt(a.a)) * factor + @as(f32, @floatFromInt(b.a)) * inv_factor),
            };
        }
    };

    /// Primary colors
    pub const quantum_blue = Color.fromHex(0x1E88E5FF);
    pub const neural_purple = Color.fromHex(0x7E57C2FF);
    pub const cosmic_gold = Color.fromHex(0xFFD700FF);

    /// Accent colors
    pub const stellar_white = Color.fromHex(0xFFFFFFFF);
    pub const void_black = Color.fromHex(0x000000FF);

    /// State colors
    pub const success_green = Color.fromHex(0x4CAF50FF);
    pub const warning_yellow = Color.fromHex(0xFFC107FF);
    pub const error_red = Color.fromHex(0xF44336FF);

    /// Material design elevation colors
    pub const elevation_colors = [_]Color{
        Color.fromHex(0x00000000), // Level 0 (no shadow)
        Color.fromHex(0x1A000000), // Level 1
        Color.fromHex(0x1F000000), // Level 2
        Color.fromHex(0x24000000), // Level 3
        Color.fromHex(0x29000000), // Level 4
        Color.fromHex(0x2E000000), // Level 5
    };

    /// Get elevation color for a given level
    pub fn getElevationColor(level: u8) Color {
        if (level >= elevation_colors.len) {
            return elevation_colors[elevation_colors.len - 1];
        }
        return elevation_colors[level];
    }

    /// Create a color scheme for a component
    pub const ColorScheme = struct {
        primary: Color,
        secondary: Color,
        background: Color,
        surface: Color,
        error_color: Color,
        on_primary: Color,
        on_secondary: Color,
        on_background: Color,
        on_surface: Color,
        on_error: Color,

        /// Create a light theme color scheme
        pub fn light() ColorScheme {
            return ColorScheme{
                .primary = quantum_blue,
                .secondary = neural_purple,
                .background = stellar_white,
                .surface = Color.fromHex(0xFAFAFAFF),
                .error_color = error_red,
                .on_primary = stellar_white,
                .on_secondary = stellar_white,
                .on_background = void_black,
                .on_surface = void_black,
                .on_error = stellar_white,
            };
        }

        /// Create a dark theme color scheme
        pub fn dark() ColorScheme {
            return ColorScheme{
                .primary = quantum_blue,
                .secondary = neural_purple,
                .background = void_black,
                .surface = Color.fromHex(0x121212FF),
                .error_color = error_red,
                .on_primary = stellar_white,
                .on_secondary = stellar_white,
                .on_background = stellar_white,
                .on_surface = stellar_white,
                .on_error = stellar_white,
            };
        }
    };
};

test "Color operations" {
    const color1 = GlimmerColors.Color.init(0xFF, 0x00, 0x00, 0xFF);
    const color2 = GlimmerColors.Color.init(0x00, 0x00, 0xFF, 0xFF);
    
    const blended = GlimmerColors.Color.blend(color1, color2, 0.5);
    try std.testing.expect(blended.r == 0x7F);
    try std.testing.expect(blended.g == 0x00);
    try std.testing.expect(blended.b == 0x7F);
    try std.testing.expect(blended.a == 0xFF);

    const hex = color1.toHex();
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), hex);
} 