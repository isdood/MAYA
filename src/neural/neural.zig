//! MAYA Neural Network Module
//! This module provides neural network functionality for the MAYA project

// Re-export all the neural modules
pub const tensor4d = @import("tensor4d.zig");
pub const attention = @import("attention.zig");
pub const quantum_tunneling = @import("quantum_tunneling.zig");
pub const temporal = @import("temporal.zig");
pub const hypercube_bridge = @import("hypercube_bridge.zig");

// Re-export commonly used types for convenience
pub const Tensor4D = tensor4d.Tensor4D;
pub const HypercubeBridge = hypercube_bridge.HypercubeBridge;
