@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-16 08:15:37",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/learning/pattern_recognizer.zig",
    "type": "zig",
    "hash": "c00beec8c1397f31c1692fd2b8517845120d11e9"
  }
}
@pattern_meta@

const std = @import("std");
const Interaction = @import("interaction_recorder.zig").Interaction;

/// Represents a detected pattern in the interaction log.
pub const Pattern = struct {
    /// A unique identifier for the pattern.
    id: []const u8,
    /// A human-readable description of the pattern.
    description: []const u8,
    /// The list of interactions that form this pattern.
    interactions: []const Interaction,
};

/// Represents a match of a pattern in the interaction log.
pub const PatternMatch = struct {
    /// The pattern that was matched.
    pattern: Pattern,
    /// The index in the interaction log where the pattern starts.
    start_index: usize,
    /// The index in the interaction log where the pattern ends.
    end_index: usize,
};

/// The PatternRecognizer is responsible for analyzing recorded interactions
/// and identifying recurring patterns.
pub const PatternRecognizer = struct {
    allocator: std.mem.Allocator,
    interactions: []const Interaction,

    /// Initialize a new PatternRecognizer.
    pub fn init(allocator: std.mem.Allocator, interactions: []const Interaction) PatternRecognizer {
        return PatternRecognizer{
            .allocator = allocator,
            .interactions = interactions,
        };
    }

    /// Deinitialize the PatternRecognizer.
    pub fn deinit(self: *PatternRecognizer) void {
        // No dynamic memory to free, but you can add cleanup logic if needed.
    }

    /// Detect patterns in the recorded interactions.
    /// Returns a list of detected patterns.
    pub fn detectPatterns(self: *PatternRecognizer) ![]Pattern {
        var patterns = std.ArrayList(Pattern).init(self.allocator);
        defer patterns.deinit();

        if (self.interactions.len < 2) {
            return &[_]Pattern{};
        }

        var i: usize = 0;
        while (i < self.interactions.len - 1) : (i += 1) {
            const current = self.interactions[i];
            const next = self.interactions[i + 1];

            if (current.action.type == next.action.type) {
                const pattern = Pattern{
                    .id = try std.fmt.allocPrint(self.allocator, "pattern_{d}", .{i}),
                    .description = try std.fmt.allocPrint(self.allocator, "Consecutive {s} actions", .{@tagName(current.action.type)}),
                    .interactions = self.interactions[i..i+2],
                };
                try patterns.append(pattern);
            }
        }

        return patterns.toOwnedSlice();
    }

    /// Find all matches of a given pattern in the interaction log.
    /// Returns a list of PatternMatch structs.
    pub fn findPatternMatches(self: *PatternRecognizer, pattern: Pattern) ![]PatternMatch {
        // TODO: Implement pattern matching logic.
        // For now, return an empty list.
        return &[_]PatternMatch{};
    }
};