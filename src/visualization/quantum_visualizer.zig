const std = @import("std");
const CrystalState = @import("../neural/crystal_computing.zig").CrystalState;

/// QuantumVisualizer provides visualization tools for quantum states and crystal states
pub const QuantumVisualizer = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) QuantumVisualizer {
        return .{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *QuantumVisualizer) void {
        _ = self;
        // No resources to free yet
    }
    
    /// Visualize a quantum state's probability distribution
    pub fn visualizeQuantumState(self: *QuantumVisualizer, state: anytype) !void {
        const stdout = std.io.getStdOut().writer();
        const num_qubits = state.qubits;
        const num_states = @as(usize, 1) << @intCast(num_qubits);
        
        try stdout.print("\nQuantum State Probabilities ({} qubits, {} states):\n", .{num_qubits, num_states});
        
        // Calculate max probability for scaling
        var max_prob: f64 = 0.0;
        for (0..num_states) |i| {
            const prob = state.getProbability(i);
            if (prob > max_prob) max_prob = prob;
        }
        
        // Print histogram
        const bar_width = 50;
        for (0..num_states) |i| {
            const prob = state.getProbability(i);
            const scaled_width = if (max_prob > 0) @as(usize, @intFromFloat(@floatCast(bar_width * (prob / max_prob)))) else 0;
            
            try stdout.print("|{b:0>2} | {s:<5.3} |", .{
                i,
                std.fmt.fmtFloatDecimal(prob, .{}),
            });
            
            // Print bar
            for (0..scaled_width) |_| try stdout.writeAll("█");
            try stdout.writeAll("\n");
        }
    }
    
    /// Visualize crystal state metrics
    pub fn visualizeCrystalState(self: *QuantumVisualizer, state: *const CrystalState) !void {
        const stdout = std.io.getStdOut().writer();
        
        // Basic crystal state info
        try stdout.print("\nCrystal State Analysis\n", .{});
        try stdout.print("  Pattern ID: {s}\n", .{state.pattern_id});
        try stdout.print("  Coherence:  {d:.3}\n", .{state.coherence});
        try stdout.print("  Entanglement: {d:.3}\n", .{state.entanglement});
        try stdout.print("  Depth: {d}\n", .{state.depth});
        
        // Spectral analysis if available
        if (state.spectral) |spectral| {
            try stdout.print("\nSpectral Analysis:\n", .{});
            try stdout.print("  Dominant Frequency: {d:.2} Hz\n", .{spectral.dominant_frequency});
            try stdout.print("  Spectral Entropy: {d:.3}\n", .{spectral.spectral_entropy});
            
            // Visualize harmonic energy distribution
            try stdout.print("\nHarmonic Energy Distribution:\n", .{});
            
            const max_energy = blk: {
                var max: f64 = 0;
                for (spectral.harmonic_energy) |energy| {
                    if (energy > max) max = energy;
                }
            }
        }
    }
    
    /// Print state probabilities as a histogram
    fn printStateProbabilities(self: *QuantumVisualizer, state: *const QuantumState) !void {
        _ = self;
        const stdout = std.io.getStdOut().writer();
        
        const num_states = @as(usize, 1) << @intCast(u6, state.qubits);
        const max_bars = 50;
        
        // Find max probability for scaling
        var max_prob: f64 = 0.0;
        for (0..num_states) |i| {
            const prob = state.getProbability(i);
            if (prob > max_prob) max_prob = prob;
        }
        
        // Print histogram
        for (0..num_states) |i| {
            const prob = state.getProbability(i);
            const bars = if (max_prob > 0) 
                @floatToInt(usize, (prob / max_prob) * @intToFloat(f64, max_bars)) 
            else 0;
            
            const state_str = try std.fmt.allocPrint(
                self.allocator,
                "|{s:0>w$}",
                .{
                    try std.fmt.allocPrint(self.allocator, "{b}", .{i}),
                    @intCast(usize, state.qubits),
                },
            );
            defer self.allocator.free(state_str);
            
            try stdout.print("{} | {s} | {d:.2}%\n", .{
                state_str,
                "#".* @as(u8, @intCast(u8, bars)),
                prob * 100.0,
            });
        }
    }
};

// Tests
const testing = std.testing;

test "quantum visualizer initialization" {
    const allocator = testing.allocator;
    var visualizer = QuantumVisualizer.init(allocator);
    defer visualizer.deinit();
    
    // Just verify it initializes and deinitializes properly
    try testing.expect(true);
}

test "visualize crystal state" {
    const allocator = testing.allocator;
    var visualizer = QuantumVisualizer.init(allocator);
    defer visualizer.deinit();
    
    // Create a test crystal state
    var state = CrystalState{
        .coherence = 0.85,
        .entanglement = 0.7,
        .depth = 5,
        .pattern_id = try allocator.dupe(u8, "test_pattern"),
        .spectral = null,
    };
    defer state.deinit(allocator);
    
    // Test visualization
    try visualizer.visualizeCrystalState(&state);
}
