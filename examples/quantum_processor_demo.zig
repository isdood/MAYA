const std = @import("std");
const QuantumProcessor = @import("neural/quantum_processor").QuantumProcessor;
const quantum_types = @import("neural/quantum_types");

// Workaround for missing math functions in Zig 0.15.0
fn fabs(x: anytype) @TypeOf(x) {
    return if (x < 0) -x else x;
}

// Simple visualization function for quantum state
fn visualizeQuantumState(state: *quantum_types.QuantumState) !void {
    const stdout = std.io.getStdOut().writer();
    const num_qubits = state.qubits.len;
    const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
    
    try stdout.print("\n=== Quantum State ({} qubits, {} states) ===\n\n", .{
        num_qubits, num_states
    });
    
    // Calculate probabilities for each state
    var probabilities = try std.heap.page_allocator.alloc(f64, num_states);
    defer std.heap.page_allocator.free(probabilities);
    
    // Calculate max probability for scaling
    var max_prob: f64 = 0.0;
    for (0..num_states) |i| {
        var prob: f64 = 1.0;
        for (0..num_qubits) |q| {
            const bit = (i >> @intCast(q)) & 1;
            const amp = if (bit == 0) state.qubits[q].amplitude0 else state.qubits[q].amplitude1;
            prob *= amp * amp; // Probability is amplitude squared
        }
        probabilities[i] = prob;
        if (prob > max_prob) max_prob = prob;
    }
    
    // Print histogram
    const bar_width = 50;
    for (0..num_states) |i| {
        const prob = probabilities[i];
        const scaled_width = if (max_prob > 0) 
            @as(usize, @intFromFloat(@as(f64, @floatCast(bar_width * (prob / max_prob))))) 
            else 0;
        
        // Format the state as binary
        var state_str: [32]u8 = undefined;
        for (0..num_qubits) |q| {
            const bit = (i >> @intCast(q)) & 1;
            state_str[num_qubits - 1 - q] = '0' + @as(u8, @intCast(bit));
        }
        
        // Format probability with 3 decimal places
        const prob_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d:.3}", .{prob});
        defer std.heap.page_allocator.free(prob_str);
        
        try stdout.print("|{s} | {s:<5} |", .{
            state_str[0..num_qubits],
            prob_str,
        });
        
        // Print bar
        for (0..scaled_width) |_| try stdout.writeAll("█");
        try stdout.writeAll("\n");
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize quantum processor with default config
    var qp = try QuantumProcessor.init(allocator, .{});
    defer qp.deinit();
    
    // Create a simple quantum circuit
    const num_qubits = 2;
    try qp.reset(num_qubits);
    
    // Apply Hadamard gate to create superposition
    try qp.applyGate(.h, 0, null);
    
    // Apply CNOT gate to create entanglement
    try qp.applyGate(.x, 1, &[_]usize{0});
    
    // Get the current state
    const state = qp.getState();
    
    // Visualize the state
    std.debug.print("\n=== Quantum Processor Demo ===\n", .{});
    std.debug.print("Applied gates:\n", .{});
    std.debug.print("  H(0) - Hadamard on qubit 0\n", .{});
    std.debug.print("  CNOT(0,1) - Controlled-NOT with control 0 and target 1\n\n", .{});
    
    try visualizeQuantumState(&state);
    
    // Measure the qubits
    std.debug.print("\nMeasurement results (10 samples):\n", .{});
    for (0..10) |_| {
        var result: usize = 0;
        for (0..num_qubits) |q| {
            if (qp.measure(q)) {
                result |= @as(usize, 1) << @intCast(q);
            }
        }
        
        // Format as binary
        var bits: [num_qubits]u8 = undefined;
        for (0..num_qubits) |q| {
            bits[num_qubits - 1 - q] = '0' + @as(u8, @intCast((result >> @intCast(q)) & 1));
        }
        
        std.debug.print("|{s}> ", .{&bits});
    }
    std.debug.print("\n\nNote: Due to quantum mechanics, you should see approximately 50% |00> and 50% |11>\n", .{});
}
