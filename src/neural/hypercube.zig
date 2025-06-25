//! HYPERCUBE 4D Neural Architecture
//! Core module for HYPERCUBE's 4D tensor operations and neural processing

// Re-export core components
pub const Tensor4D = @import("tensor4d.zig").Tensor4D;
pub const attention = @import("attention.zig");
pub const quantum_tunneling = @import("quantum_tunneling.zig");
pub const temporal = @import("temporal.zig");

// Re-export common types for convenience
pub const GravityAttentionParams = attention.GravityAttentionParams;
pub const QuantumTunnelingParams = quantum_tunneling.QuantumTunnelingParams;
pub const TemporalConfig = temporal.TemporalConfig;

// Tests
const testing = @import("std").testing;

test "HYPERCUBE module imports" {
    // Just verify that the module compiles
    _ = Tensor4D;
    _ = attention;
    _ = quantum_tunneling;
    _ = temporal;
    
    // Test type exports
    _ = GravityAttentionParams;
    _ = QuantumTunnelingParams;
    _ = TemporalConfig;
}
