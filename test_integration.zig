
const std = @import("std");
const testing = std.testing;

// Import our modules
const neural = @import("src/neural/mod.zig");
const quantum_types = @import("src/neural/quantum_types.zig");
const QuantumState = quantum_types.QuantumState;
const VisualState = neural.VisualState;
const NeuralProcessor = neural.NeuralProcessor;
const QuantumProcessor = neural.QuantumProcessor;
const VisualProcessor = neural.VisualProcessor;

// Test the complete pipeline from quantum state through visual processing to pattern recognition
test "neural-quantum-visual integration test" {
    const allocator = testing.allocator;
    
    // Initialize processors
    var neural_processor = try NeuralProcessor.init(allocator);
    defer neural_processor.deinit();
    
    var quantum_processor = try QuantumProcessor.init(allocator);
    defer quantum_processor.deinit();
    
    var visual_processor = try VisualProcessor.init(allocator);
    defer visual_processor.deinit();

    // Create test pattern data
    const pattern_data = "test_pattern";

    // Process pattern through quantum processor
    const quantum_result = try quantum_processor.process(pattern_data);
    try testing.expect(quantum_result.coherence >= 0.0 and quantum_result.coherence <= 1.0);
    try testing.expect(quantum_result.entanglement >= 0.0 and quantum_result.entanglement <= 1.0);
    try testing.expect(quantum_result.superposition >= 0.0 and quantum_result.superposition <= 1.0);

    // Process pattern through visual processor
    const visual_result = try visual_processor.process(pattern_data);
    try testing.expect(visual_result.brightness >= 0.0 and visual_result.brightness <= 1.0);
    try testing.expect(visual_result.contrast >= 0.0 and visual_result.contrast <= 1.0);
    try testing.expect(visual_result.saturation >= 0.0 and visual_result.saturation <= 1.0);

    // Process through neural network
    const result = try neural_processor.process(pattern_data);
    defer neural_processor.allocator.free(result.pattern_id);
    
    // Verify results
    try testing.expect(result.confidence >= 0.0 and result.confidence <= 1.0);
    try testing.expect(result.pattern_id.len > 0);
    
    std.debug.print("Integration test passed! Pattern ID: {s}, Confidence: {d:.2}\n", 
        .{result.pattern_id, result.confidence});
}

// Test error handling with invalid states
test "error handling with invalid states" {
    const allocator = testing.allocator;
    
    var neural_processor = try NeuralProcessor.init(allocator);
    defer neural_processor.deinit();
    
    // Test with invalid pattern data for quantum processor with a fresh instance
    var quantum_processor2 = try QuantumProcessor.init(allocator);
    defer quantum_processor2.deinit();
    try testing.expectError(error.InvalidPatternData, 
        quantum_processor2.process(""));
    
    // Test with invalid pattern data for visual processor with a fresh instance
    var visual_processor2 = try VisualProcessor.init(allocator);
    defer visual_processor2.deinit();
    try testing.expectError(error.InvalidPatternData,
        visual_processor2.process(""));
}
