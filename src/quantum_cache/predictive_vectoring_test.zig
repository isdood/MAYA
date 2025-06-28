const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqAbs = testing.expectApproxEqAbs;
const debug = std.debug;

const PredictiveVectoring = @import("predictive_vectoring.zig");
const Pattern = PredictiveVectoring.Pattern;
const PatternSignature = PredictiveVectoring.PatternSignature;
const PredictiveVectoringSystem = PredictiveVectoring.PredictiveVectoringSystem;

// Test helper to create a simple pattern
fn createTestPattern(allocator: std.mem.Allocator, width: u32, height: u32, value: f32) !Pattern {
    const size = width * height * 4; // RGBA
    const data = try allocator.alloc(f32, size);
    @memset(data, value);
    
    return Pattern{
        .data = data,
        .width = width,
        .height = height,
        .owns_data = true,
    };
}

test "PatternSignature coherence updates" {
    const allocator = testing.allocator;
    
    var sig = try PatternSignature.init(allocator);
    defer sig.deinit();
    
    // Initial state should be COLLAPSED with some coherence
    try expectEqual(PredictiveVectoring.STARWEAVE_META.CoherenceState.COLLAPSED, sig.coherence_state);
    
    // Update coherence with current time
    const start_time = std.time.milliTimestamp();
    sig.updateCoherence(start_time);
    
    // After update, state might change based on coherence
    try expect(sig.coherence >= 0.0 and sig.coherence <= 1.0);
    
    // Test state transitions
    sig.coherence = 0.9;
    sig.updateCoherence(start_time + 1000);
    try expect(sig.coherence_state == .ENTANGLED);
    
    sig.coherence = 0.7;
    sig.updateCoherence(start_time + 2000);
    try expect(sig.coherence_state == .RESONANT);
    
    sig.coherence = 0.4;
    sig.updateCoherence(start_time + 3000);
    try expect(sig.coherence_state == .SUPERPOSED);
    
    sig.coherence = 0.2;
    sig.updateCoherence(start_time + 4000);
    try expect(sig.coherence_state == .COLLAPSED);
    
    sig.coherence = 0.05;
    sig.updateCoherence(start_time + 5000);
    try expect(sig.coherence_state == .DECOHERED);
}

test "PredictiveVectoringSystem basic operations" {
    const allocator = testing.allocator;
    
    // Test initialization
    var pvs = try PredictiveVectoringSystem.init(allocator);
    defer pvs.deinit();
    
    // Create a test pattern
    const pattern_data = try allocator.alloc(f32, 16);
    defer allocator.free(pattern_data);
    @memset(pattern_data, 0.5);
    
    const pattern = Pattern{
        .data = pattern_data,
        .width = 4,
        .height = 4,
        .owns_data = false,
    };
    
    // Add pattern to the system
    try pvs.addPattern(&pattern);
    
    // Verify pattern was added
    try expect(pvs.pattern_cache.count() > 0); // Pattern should be added to cache
    try expect(pvs.cache.count() > 0); // Signature should be added to cache
    
    // Test prediction (basic functionality test)
    const predictions = try pvs.predictNext();
    defer predictions.deinit();
    
    // For now, just check that prediction doesn't crash
    // We'll add more specific tests once the prediction logic is implemented
}

test "Pattern similarity calculation" {
    const allocator = testing.allocator;
    
    var sig1 = try PatternSignature.init(allocator);
    defer sig1.deinit();
    
    var sig2 = try PatternSignature.init(allocator);
    defer sig2.deinit();
    
    // Set up test aspects
    @memset(&sig1.aspects, 0);
    @memset(&sig2.aspects, 0);
    
    // Identical aspects
    sig1.aspects[0] = 1.0;
    sig2.aspects[0] = 1.0;
    
    var similarity = sig1.similarity(&sig2);
    try expectApproxEqAbs(@as(f32, 1.0), similarity, 0.001);
    
    // Orthogonal aspects
    sig1.aspects[1] = 1.0;
    sig2.aspects[2] = 1.0;
    
    similarity = sig1.similarity(&sig2);
    try expectApproxEqAbs(@as(f32, 0.5), similarity, 0.1);
    
    // Opposite aspects
    sig1.aspects[3] = 1.0;
    sig2.aspects[3] = -1.0;
    
    similarity = sig1.similarity(&sig2);
    try expect(similarity < 0.5);
}

// TODO: Add more comprehensive tests for prediction functionality
// once the prediction implementation is complete
