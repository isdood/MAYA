const std = @import("std");
const Allocator = std.mem.Allocator;

// Import pattern synthesis module
const pattern_synthesis = @import("../pattern_synthesis/mod.zig");
const SynthesizedPattern = pattern_synthesis.SynthesizedPattern;
const PatternSynthesizer = pattern_synthesis.PatternSynthesizer;

/// Configuration for the pattern processor
pub const ProcessorConfig = struct {
    /// Maximum number of patterns to keep in memory
    max_patterns: usize = 1000,
    /// Minimum confidence threshold for pattern recognition
    min_confidence: f32 = 0.7,
    /// Maximum number of synthesis iterations
    max_synthesis_iterations: u32 = 1000,
    /// Batch size for parallel processing
    batch_size: usize = 32,
};

/// Main pattern processor
pub const PatternProcessor = struct {
    allocator: Allocator,
    config: ProcessorConfig,
    synthesizer: PatternSynthesizer,
    
    /// Initialize a new pattern processor
    pub fn init(allocator: Allocator, config: ProcessorConfig) !PatternProcessor {
        const synth_config = .{
            .max_patterns = config.max_patterns,
            .min_confidence = config.min_confidence,
            .max_iterations = config.max_synthesis_iterations,
            .batch_size = config.batch_size,
        };
        
        return PatternProcessor{
            .allocator = allocator,
            .config = config,
            .synthesizer = try PatternSynthesizer.init(allocator, synth_config),
        };
    }
    
    /// Clean up resources
    pub fn deinit(self: *PatternProcessor) void {
        self.synthesizer.deinit();
    }
    
    /// Process input features through the pattern processor
    pub fn process(
        self: *PatternProcessor,
        input_features: []const f32,
        pattern_id: []const u8,
    ) !*SynthesizedPattern {
        // For now, just pass through to the synthesizer
        return try self.synthesizer.synthesize(input_features, pattern_id);
    }
    
    /// Get a synthesized pattern by ID
    pub fn getPattern(
        self: *PatternProcessor,
        pattern_id: []const u8,
    ) ?*SynthesizedPattern {
        for (self.synthesizer.patterns.items) |pattern| {
            if (std.mem.eql(u8, pattern.id, pattern_id)) {
                return pattern;
            }
        }
        return null;
    }
    
    /// Get all synthesized patterns
    pub fn getAllPatterns(
        self: *PatternProcessor,
    ) []*SynthesizedPattern {
        return self.synthesizer.patterns.items;
    }
    
    /// Get the number of synthesized patterns
    pub fn getPatternCount(self: *const PatternProcessor) usize {
        return self.synthesizer.patterns.items.len;
    }
};

// Tests
const testing = std.testing;

test "PatternProcessor initialization" {
    var processor = try PatternProcessor.init(
        testing.allocator,
        .{ .max_patterns = 50 },
    );
    defer processor.deinit();
    
    try testing.expectEqual(@as(usize, 0), processor.getPatternCount());
}

test "Pattern processing flow" {
    var processor = try PatternProcessor.init(
        testing.allocator,
        .{ .max_patterns = 50 },
    );
    defer processor.deinit();
    
    // Process a new pattern
    const input1 = [_]f32{0.1, 0.2, 0.3};
    const pattern = try processor.process(&input1, "test_pattern");
    
    // Should have one pattern
    try testing.expectEqual(@as(usize, 1), processor.getPatternCount());
    
    // Get the pattern
    const retrieved = processor.getPattern("test_pattern");
    try testing.expect(retrieved != null);
    
    // Verify pattern properties
    try testing.expectEqual(@as(usize, 3), pattern.features.len);
    try testing.expect(pattern.confidence >= 0.0 and pattern.confidence <= 1.0);
}

// Run all tests
pub fn runTests() !void {
    std.debug.print("\n=== Running Pattern Processor Tests ===\n", .{});
    
    // Run all test blocks
    try testing.runTest("PatternProcessor initialization", testPatternProcessorInitialization);
    try testing.runTest("Pattern processing flow", testPatternProcessingFlow);
    
    std.debug.print("\n✅ All Pattern Processor Tests Passed!\n", .{});
}

// Wrapper functions for test blocks
fn testPatternProcessorInitialization() !void {
    var processor = try PatternProcessor.init(
        testing.allocator,
        .{ .max_patterns = 50 },
    );
    defer processor.deinit();
    
    try testing.expectEqual(@as(usize, 0), processor.getPatternCount());
}

fn testPatternProcessingFlow() !void {
    var processor = try PatternProcessor.init(
        testing.allocator,
        .{ .max_patterns = 50 },
    );
    defer processor.deinit();
    
    const input1 = [_]f32{0.1, 0.2, 0.3};
    const pattern = try processor.process(&input1, "test_pattern");
    
    try testing.expectEqual(@as(usize, 1), processor.getPatternCount());
    try testing.expectEqual(@as(usize, 3), pattern.features.len);
}
