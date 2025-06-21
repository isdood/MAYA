const std = @import("std");
const quantum_viz = @import("visualization/quantum_viz");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a 2-qubit circuit
    var circuit = try quantum_viz.QuantumCircuit.init(allocator, 2);
    defer circuit.deinit();
    
    // Print initial state
    std.debug.print("=== Quantum Circuit Demo ===\n\n", .{});
    std.debug.print("Initial state:\n", .{});
    try circuit.printState();
    
    // Apply gates and show state after each operation
    const gates = [_]struct {
        name: []const u8,
        gate: []const f64,
        target: usize,
        control: ?usize,
    }{
        .{ .name = "H", .gate = quantum_viz.Gates.H, .target = 0, .control = null },
        .{ .name = "CNOT(0,1)", .gate = quantum_viz.Gates.X, .target = 1, .control = 0 },
        .{ .name = "T", .gate = quantum_viz.Gates.T, .target = 0, .control = null },
        .{ .name = "S", .gate = quantum_viz.Gates.S, .target = 1, .control = null },
        .{ .name = "X", .gate = quantum_viz.Gates.X, .target = 0, .control = null },
        .{ .name = "Y", .gate = quantum_viz.Gates.Y, .target = 1, .control = null },
        .{ .name = "Z", .gate = quantum_viz.Gates.Z, .target = 0, .control = null },
    };
    
    for (gates) |gate| {
        std.debug.print("\nApplying {} to qubit {}:", .{gate.name, gate.target});
        if (gate.control) |c| std.debug.print(" (controlled by qubit {})", .{c});
        std.debug.print("\n", .{});
        
        if (gate.control) |c| {
            circuit.applyControlledGate(gate.gate, c, gate.target);
        } else {
            circuit.applyGate(gate.gate, gate.target);
        }
        
        try circuit.printState();
        
        // Show measurement results
        std.debug.print("  Measurement results (5 samples): ", .{});
        for (0..5) |_| {
            const q0 = circuit.qubits[0].measure();
            const q1 = circuit.qubits[1].measure();
            std.debug.print("|{}{}> ", .{ @intFromBool(q0), @intFromBool(q1) });
        }
        std.debug.print("\n");
        
        // Reset qubits for next operation
        if (circuit.qubits[0].alpha < 1.0) circuit.qubits[0].alpha = 1.0 / math.sqrt(2.0);
        if (circuit.qubits[1].alpha < 1.0) circuit.qubits[1].alpha = 1.0 / math.sqrt(2.0);
    }
    
    // Demonstrate Bloch sphere visualization with different states
    std.debug.print("\n=== Bloch Sphere Visualization ===\n", .{});
    
    const demo_states = [_]struct {
        name: []const u8,
        alpha: f64,
        beta: f64,
        beta_imag: f64,
    }{
        .{ .name = "|0> state", .alpha = 1.0, .beta = 0.0, .beta_imag = 0.0 },
        .{ .name = "|1> state", .alpha = 0.0, .beta = 1.0, .beta_imag = 0.0 },
        .{ .name = "|+> state", .alpha = 1.0/math.sqrt(2.0), .beta = 1.0/math.sqrt(2.0), .beta_imag = 0.0 },
        .{ .name = "|-> state", .alpha = 1.0/math.sqrt(2.0), .beta = -1.0/math.sqrt(2.0), .beta_imag = 0.0 },
        .{ .name = "|i> state", .alpha = 1.0/math.sqrt(2.0), .beta = 0.0, .beta_imag = 1.0/math.sqrt(2.0) },
    };
    
    for (demo_states) |state| {
        std.debug.print("\n{}\n", .{state.name});
        const q = quantum_viz.QubitState{
            .alpha = state.alpha,
            .beta = state.beta,
            .beta_imag = state.beta_imag,
        };
        try circuit.drawBlochSphere(q);
    }
}

// Helper functions
const math = std.math;
