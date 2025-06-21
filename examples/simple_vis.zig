const std = @import("std");

// Simple mock quantum state for demonstration
const MockQuantumState = struct {
    qubits: u6 = 2,
    
    pub fn getProbability(self: *const @This(), _: usize) f64 {
        return 1.0 / @as(f64, @floatFromInt(@as(u64, 1) << @intCast(self.qubits)));
    }
};

// Simple visualizer
const SimpleVisualizer = struct {
    pub fn visualizeQuantumState(state: anytype) !void {
        const stdout = std.io.getStdOut().writer();
        const num_qubits = state.qubits;
        const num_states = @as(usize, 1) << @intCast(num_qubits);
        
        try stdout.print("\n=== Quantum State ({} qubits, {} states) ===\n\n", .{
            num_qubits, num_states
        });
        
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
            const scaled_width = if (max_prob > 0) 
                @as(usize, @intFromFloat(@as(f64, @floatCast(bar_width * (prob / max_prob)))))
                else 0;
            
            try stdout.print("|{b:0>2} | {s:<5.3} |", .{
                i,
                std.fmt.fmtFloatDecimal(prob, .{}),
            });
            
            // Print bar
            for (0..scaled_width) |_| try stdout.writeAll("█");
            try stdout.writeAll("\n");
        }
    }
};

pub fn main() !void {
    // Create a mock quantum state
    var quantum_state = MockQuantumState{};
    
    // Visualize the state
    std.debug.print("\n=== Simple Quantum State Visualization ===\n", .{});
    try SimpleVisualizer.visualizeQuantumState(&quantum_state);
    
    std.debug.print("\nVisualization completed.\n", .{});
}
