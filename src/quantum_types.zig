@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-20 09:27:00",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/quantum_types.zig",
    "type": "zig",
    "hash": "8c1ecd19accb5524601c74f62d7be0b6c427af2c"
  }
}
@pattern_meta@

//! Quantum types and utilities for the MAYA neural core

/// Represents a quantum state
pub const Qubit = struct {
    alpha: f32, // Amplitude for |0⟩
    beta: f32,  // Amplitude for |1⟩

};

/// Represents a quantum gate operation
pub const QuantumGate = struct {
    matrix: [2][2]f32, // 2x2 unitary matrix
    name: []const u8,  // Name of the gate (e.g., "H", "X", etc.)
};

/// Creates a Hadamard gate
pub fn hadamardGate() QuantumGate {
    const sqrt2 = 1.41421356237; // sqrt(2)
    const inv_sqrt2 = 1.0 / sqrt2;
    return .{
        .matrix = .{
            .{ inv_sqrt2, inv_sqrt2 },
            .{ inv_sqrt2, -inv_sqrt2 },
        },
        .name = "H",
    };
}

/// Creates a Pauli-X gate
pub fn pauliXGate() QuantumGate {
    return .{
        .matrix = .{
            .{ 0, 1 },
            .{ 1, 0 },
        },
        .name = "X",
    };
}

/// Creates a Pauli-Y gate
pub fn pauliYGate() QuantumGate {
    return .{
        .matrix = .{
            .{ 0, -1 },
            .{ 1, 0 },
        },
        .name = "Y",
    };
}

/// Creates a Pauli-Z gate
pub fn pauliZGate() QuantumGate {
    return .{
        .matrix = .{
            .{ 1, 0 },
            .{ 0, -1 },
        },
        .name = "Z",
    };
}
