@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 09:26:00",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/neural/quantum_types.zig",
    "type": "zig",
    "hash": "4a42b38807a620174fb83187785444b48f50231a"
  }
}
@pattern_meta@

// Quantum types shared between quantum_processor and pattern_recognition
pub const QuantumState = struct {
    coherence: f64,
    entanglement: f64,
    superposition: f64,
}; 