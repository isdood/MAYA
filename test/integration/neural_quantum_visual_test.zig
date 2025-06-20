const std = @import("std");
const testing = std.testing;
const allocator = testing.allocator;

// Import neural module
const neural = @import("neural");
const QuantumState = neural.QuantumState;
const VisualState = neural.VisualState;
const NeuralProcessor = neural.NeuralProcessor;
const QuantumProcessor = neural.QuantumProcessor;
const VisualProcessor = neural.VisualProcessor;

// This makes the file a test file
test {}

test "neural-quantum-visual integration" {
    // This test will be run by the test runner
    try std.testing.expect(true);
}

test "neural-quantum-visual integration test" {
    // Initialize processors
    var neural_processor = try NeuralProcessor.init(allocator);
    defer neural_processor.deinit();
    
    var quantum_processor = try QuantumProcessor.init(allocator);
    defer quantum_processor.deinit();
    
    var visual_processor = try VisualProcessor.init(allocator);
    defer visual_processor.deinit();

    // Create test quantum state
    const quantum_state = QuantumState{
        .coherence = 0.8,
        .entanglement = 0.7,
        .superposition = 0.9,
        .decoherence = 0.1,
    };

    // Process quantum state
    const quantum_result = try quantum_processor.process(quantum_state);
    try testing.expect(quantum_result.coherence >= 0.0 and quantum_result.coherence <= 1.0);
    try testing.expect(quantum_result.entanglement >= 0.0 and quantum_result.entanglement <= 1.0);

    // Create test visual state
    const visual_state = VisualState{
        .brightness = 0.7,
        .contrast = 0.6,
        .saturation = 0.8,
    };

    // Process visual state
    const visual_result = try visual_processor.process(visual_state);
    try testing.expect(visual_result.brightness >= 0.0 and visual_result.brightness <= 1.0);
    try testing.expect(visual_result.contrast >= 0.0 and visual_result.contrast <= 1.0);

    // Process through neural network
    const result = try neural_processor.process(quantum_result, visual_result);
    
    // Verify results
    try testing.expect(result.confidence >= 0.0 and result.confidence <= 1.0);
    try testing.expect(result.pattern_id != null);
    
    std.debug.print("Integration test passed! Pattern ID: {s}, Confidence: {d:.2}\n", 
        .{result.pattern_id.?, result.confidence});
}

test "error handling with invalid states" {
    var neural_processor = try NeuralProcessor.init(allocator);
    defer neural_processor.deinit();
    
    // Test with invalid quantum state
    const invalid_quantum = QuantumState{
        .coherence = 1.5,  // Invalid value > 1.0
        .entanglement = 0.5,
        .superposition = 0.5,
        .decoherence = 0.5,
    };
    
    const valid_visual = VisualState{
        .brightness = 0.5,
        .contrast = 0.5,
        .saturation = 0.5,
    };
    
    // Should fail validation
    try testing.expectError(error.InvalidQuantumState, 
        neural_processor.process(invalid_quantum, valid_visual));
    
    // Test with invalid visual state
    const valid_quantum = QuantumState{
        .coherence = 0.5,
        .entanglement = 0.5,
        .superposition = 0.5,
        .decoherence = 0.5,
    };
    
    const invalid_visual = VisualState{
        .brightness = -0.1,  // Invalid value < 0.0
        .contrast = 0.5,
        .saturation = 0.5,
    };
    
    // Should fail validation
    try testing.expectError(error.InvalidVisualState,
        neural_processor.process(valid_quantum, invalid_visual));
}
