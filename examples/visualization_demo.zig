const std = @import("std");
const CrystalState = @import("../src/neural/crystal_computing.zig").CrystalState;
const QuantumVisualizer = @import("../src/visualization/quantum_visualizer.zig").QuantumVisualizer;
const Metrics = @import("../src/monitoring/metrics.zig").Metrics;
const Dashboard = @import("../src/monitoring/dashboard.zig").Dashboard;

// Mock QuantumState for demonstration
const MockQuantumState = struct {
    qubits: u6,
    
    pub fn getProbability(self: *const @This(), _: usize) f64 {
        return 1.0 / @as(f64, @floatFromInt(@as(u64, 1) << @intCast(self.qubits)));
    }
};

// Mock QuantumState for demonstration
const MockQuantumState = struct {
    qubits: u6,
    
    pub fn getProbability(self: *const @This(), _: usize) f64 {
        return 1.0 / @intToFloat(f64, 1 << @intCast(u6, self.qubits));
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize visualizer
    var visualizer = QuantumVisualizer.init(allocator);
    defer visualizer.deinit();
    
    // Create a test crystal state with spectral analysis
    var spectral = try allocator.create(CrystalState.SpectralAnalysis);
    spectral.* = .{
        .dominant_frequency = 440.0,
        .spectral_entropy = 2.5,
        .harmonic_energy = try allocator.alloc(f64, 8),
    };
    
    // Fill with some test data
    for (spectral.harmonic_energy, 0..) |*energy, i| {
        energy.* = 1.0 / @intToFloat(f64, i + 1);
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
        if (crystal_state.spectral) |s| {
            allocator.free(s.harmonic_energy);
            allocator.destroy(s);
        }
    }
    
    // Create a mock quantum state
    var quantum_state = MockQuantumState{ .qubits = 2 };
    
    // Visualize states
    std.debug.print("\n=== Quantum State Visualization ===\n", .{});
    try visualizer.visualizeQuantumState(&quantum_state);
    
    std.debug.print("\n=== Crystal State Visualization ===\n", .{});
    try visualizer.visualizeCrystalState(&crystal_state);
    
    // Set up metrics and dashboard in a separate thread
    var metrics = Metrics.init(allocator);
    defer metrics.deinit();
    
    // Start dashboard in a separate thread
    var dashboard = Dashboard.init(allocator, &metrics);
    const dashboard_thread = try std.Thread.spawn(.{}, Dashboard.start, .{&dashboard});
    
    // Record some metrics
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try metrics.record("quantum_ops", @as(f64, @floatFromInt(1_000_000 + i * 100_000)), "ops", "Quantum operations per second");
        try metrics.record("memory_usage", 100.0 + @as(f64, @floatFromInt(i)) * 5.0, "MB", "Memory usage");
        try metrics.record("accuracy", 0.95 - @as(f64, @floatFromInt(i)) * 0.01, "", "Prediction accuracy");
        
        std.time.sleep(std.time.ns_per_ms * 500); // 500ms
    }
    
    // Stop the dashboard
    dashboard.stop();
    dashboard_thread.join();
    
    std.debug.print("\nDemo completed.\n", .{});
}
