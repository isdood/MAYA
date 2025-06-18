// 🧪 MAYA Pattern Recognition Tests
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-18
// 👤 Author: isdood

const std = @import("std");
const pattern_recognition = @import("pattern_recognition");
const quantum_processor = @import("quantum_processor");
const visual_processor = @import("visual_processor");
const neural_processor = @import("neural_processor");

test "pattern recognition system integration" {
    const allocator = std.testing.allocator;

    // Initialize processors
    var quantum = try quantum_processor.QuantumProcessor.init(allocator);
    defer quantum.deinit();

    var visual = try visual_processor.VisualProcessor.init(allocator);
    defer visual.deinit();

    var neural = try neural_processor.NeuralProcessor.init(allocator);
    defer neural.deinit();

    // Test pattern data
    const pattern_data = "test pattern data for quantum and visual processing";

    // Test quantum processing
    const quantum_state = try quantum.process(pattern_data);
    try std.testing.expect(quantum_state.coherence >= 0.0);
    try std.testing.expect(quantum_state.coherence <= 1.0);
    try std.testing.expect(quantum_state.entanglement >= 0.0);
    try std.testing.expect(quantum_state.entanglement <= 1.0);
    try std.testing.expect(quantum_state.superposition >= 0.0);
    try std.testing.expect(quantum_state.superposition <= 1.0);

    // Test visual processing
    const visual_state = try visual.process(pattern_data);
    try std.testing.expect(visual_state.contrast >= 0.0);
    try std.testing.expect(visual_state.contrast <= 1.0);
    try std.testing.expect(visual_state.noise >= 0.0);
    try std.testing.expect(visual_state.noise <= 1.0);
    try std.testing.expect(visual_state.resolution > 0);
    try std.testing.expect(visual_state.resolution <= visual.config.resolution);

    // Test neural processing
    const result = try neural.process(pattern_data);
    try std.testing.expect(result.confidence >= 0.0);
    try std.testing.expect(result.confidence <= 1.0);
    try std.testing.expect(result.pattern_id.len > 0);
    try std.testing.expect(result.metadata.timestamp > 0);

    // Verify pattern type determination
    try std.testing.expect(result.pattern_type != pattern_recognition.PatternType.Unknown);
}

test "pattern recognition confidence calculation" {
    const allocator = std.testing.allocator;
    var neural = try neural_processor.NeuralProcessor.init(allocator);
    defer neural.deinit();

    // Test high confidence pattern
    const high_confidence_data = "high confidence pattern with clear quantum and visual characteristics";
    const high_result = try neural.process(high_confidence_data);
    try std.testing.expect(high_result.confidence >= 0.8);

    // Test low confidence pattern
    const low_confidence_data = "low confidence pattern with unclear characteristics";
    const low_result = try neural.process(low_confidence_data);
    try std.testing.expect(low_result.confidence < 0.8);
}

test "pattern type classification" {
    const allocator = std.testing.allocator;
    var neural = try neural_processor.NeuralProcessor.init(allocator);
    defer neural.deinit();

    // Test quantum pattern
    const quantum_data = "quantum pattern with high coherence and entanglement";
    const quantum_result = try neural.process(quantum_data);
    try std.testing.expect(quantum_result.pattern_type == pattern_recognition.PatternType.Quantum);

    // Test visual pattern
    const visual_data = "visual pattern with high contrast and resolution";
    const visual_result = try neural.process(visual_data);
    try std.testing.expect(visual_result.pattern_type == pattern_recognition.PatternType.Visual);

    // Test universal pattern
    const universal_data = "universal pattern with both quantum and visual characteristics";
    const universal_result = try neural.process(universal_data);
    try std.testing.expect(universal_result.pattern_type == pattern_recognition.PatternType.Universal);
}

test "pattern metadata generation" {
    const allocator = std.testing.allocator;
    var neural = try neural_processor.NeuralProcessor.init(allocator);
    defer neural.deinit();

    const pattern_data = "test pattern for metadata generation";
    const result = try neural.process(pattern_data);

    // Verify metadata fields
    try std.testing.expect(result.metadata.timestamp > 0);
    try std.testing.expect(result.metadata.quantum.coherence >= 0.0);
    try std.testing.expect(result.metadata.quantum.coherence <= 1.0);
    try std.testing.expect(result.metadata.visual.contrast >= 0.0);
    try std.testing.expect(result.metadata.visual.contrast <= 1.0);
}

test "pattern ID generation" {
    const allocator = std.testing.allocator;
    var neural = try neural_processor.NeuralProcessor.init(allocator);
    defer neural.deinit();

    const pattern_data = "test pattern for ID generation";
    const result = try neural.process(pattern_data);

    // Verify pattern ID format
    try std.testing.expect(result.pattern_id.len > 0);
    try std.testing.expect(std.mem.startsWith(u8, result.pattern_id, "pattern_"));
} 