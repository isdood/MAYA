const std = @import("std");
const CrystalState = @import("../src/neural/crystal_computing.zig").CrystalState;
const QuantumVisualizer = @import("../src/visualization/quantum_visualizer.zig").QuantumVisualizer;

// Mock QuantumState for demonstration
const MockQuantumState = struct {
    qubits: u6 = 2,
    
    pub fn getProbability(self: *const @This(), _: usize) f64 {
        return 1.0 / @as(f64, @floatFromInt(@as(u64, 1) << @intCast(self.qubits)));
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize visualizer
    var visualizer = QuantumVisualizer.init(allocator);
    defer visualizer.deinit();
    
    // Create a test crystal state with spectral analysis
    var spectral = try allocator.create(CrystalState.SpectralAnalysis);
    defer allocator.destroy(spectral);
    
    spectral.* = .{
        .dominant_frequency = 440.0,
        .spectral_entropy = 2.5,
        .harmonic_energy = try allocator.alloc(f64, 8),
    };
    defer allocator.free(spectral.harmonic_energy);
    
    // Fill with some test data
    for (spectral.harmonic_energy, 0..) |*energy, i| {
        energy.* = 1.0 / @as(f64, @floatFromInt(i + 1));
    }
    
    var crystal_state = CrystalState{
        .coherence = 0.85,
        .entanglement = 0.7,
        .depth = 5,
        .pattern_id = try allocator.dupe(u8, "demo_pattern"),
        .spectral = spectral,
    };
    defer {
        allocator.free(crystal_state.pattern_id);
        crystal_state.spectral = null; // Already freed above
    }
    
    // Create a mock quantum state
    var quantum_state = MockQuantumState{};
    
    // Visualize states
    std.debug.print("\n=== Quantum State Visualization ===\n", .{});
    try visualizer.visualizeQuantumState(&quantum_state);
    
    std.debug.print("\n=== Crystal State Visualization ===\n", .{});
    try visualizer.visualizeCrystalState(&crystal_state);
    
    std.debug.print("\nVisualization demo completed.\n", .{});
}
