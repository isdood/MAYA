const std = @import("std");

// Simple quantum state representation
const Qubit = struct {
    amplitude0: f64 = 1.0,
    amplitude1: f64 = 0.0,
    phase: f64 = 0.0,
};

const QuantumState = struct {
    qubits: []Qubit,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, num_qubits: usize) !@This() {
        const qubits = try allocator.alloc(Qubit, num_qubits);
        @memset(qubits, Qubit{});
        return .{
            .qubits = qubits,
            .allocator = allocator,
        };
    }

    fn deinit(self: *@This()) void {
        self.allocator.free(self.qubits);
    }

    fn hadamard(self: *@This(), qubit: usize) void {
        if (qubit >= self.qubits.len) return;
        
        const q = &self.qubits[qubit];
        const a0 = q.amplitude0;
        const a1 = q.amplitude1;
        
        // Apply Hadamard gate
        q.amplitude0 = (a0 + a1) / std.math.sqrt(2.0);
        q.amplitude1 = (a0 - a1) / std.math.sqrt(2.0);
    }

    fn cnot(self: *@This(), control: usize, target: usize) void {
        if (control >= self.qubits.len or target >= self.qubits.len) return;
        
        // Simple CNOT implementation for demonstration
        // In a real quantum computer, this would be more complex
        if (self.qubits[control].amplitude1 > 0.5) {
            // If control is |1>, flip the target
            const tmp = self.qubits[target].amplitude0;
            self.qubits[target].amplitude0 = self.qubits[target].amplitude1;
            self.qubits[target].amplitude1 = tmp;
        }
    }

    fn measure(self: *@This(), qubit: usize) bool {
        if (qubit >= self.qubits.len) return false;
        
        const q = &self.qubits[qubit];
        const prob1 = q.amplitude1 * q.amplitude1;
        const r = std.crypto.random.float(f64);
        
        if (r < prob1) {
            q.amplitude0 = 0.0;
            q.amplitude1 = 1.0;
            return true;
        } else {
            q.amplitude0 = 1.0;
            q.amplitude1 = 0.0;
            return false;
        }
    }

    fn printState(self: *const @This()) !void {
        const stdout = std.io.getStdOut().writer();
        const num_qubits = self.qubits.len;
        const num_states = @as(usize, 1) << @intCast(num_qubits);
        
        try stdout.print("\n=== Quantum State ({} qubits, {} states) ===\n\n", .{
            num_qubits, num_states
        });
        
        // Calculate probabilities for each state
        var max_prob: f64 = 0.0;
        var probs = try std.heap.page_allocator.alloc(f64, num_states);
        defer std.heap.page_allocator.free(probs);
        
        for (0..num_states) |i| {
            var prob: f64 = 1.0;
            for (0..num_qubits) |q| {
                const bit = (i >> @intCast(q)) & 1;
                const amp = if (bit == 0) self.qubits[q].amplitude0 else self.qubits[q].amplitude1;
                prob *= amp * amp;
            }
            probs[i] = prob;
            if (prob > max_prob) max_prob = prob;
        }
        
        // Print histogram
        const bar_width = 50;
        for (0..num_states) |i| {
            const prob = probs[i];
            const scaled_width = if (max_prob > 0) 
                @as(usize, @intFromFloat(bar_width * (prob / max_prob))) 
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
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize a 2-qubit quantum state
    var state = try QuantumState.init(allocator, 2);
    defer state.deinit();
    
    std.debug.print("=== Quantum Processor Demo ===\n", .{});
    std.debug.print("Initial state (|00>):\n", .{});
    try state.printState();
    
    // Apply Hadamard to first qubit
    std.debug.print("\nAfter H(0):\n", .{});
    state.hadamard(0);
    try state.printState();
    
    // Apply CNOT with control=0, target=1
    std.debug.print("\nAfter CNOT(0,1):\n", .{});
    state.cnot(0, 1);
    try state.printState();
    
    // Measure the qubits
    std.debug.print("\nMeasurement results (10 samples):\n", .{});
    for (0..10) |_| {
        var result: u2 = 0;
        for (0..state.qubits.len) |q| {
            if (state.measure(q)) {
                result |= @as(u2, 1) << @intCast(q);
            }
        }
        
        // Format as binary
        var bits: [2]u8 = undefined;
        for (0..state.qubits.len) |q| {
            bits[state.qubits.len - 1 - q] = '0' + @as(u8, @intCast((result >> @intCast(q)) & 1));
        }
        
        std.debug.print("|{s}> ", .{&bits});
    }
    std.debug.print("\n\nNote: Due to quantum mechanics, you should see approximately 50% |00> and 50% |11>\n", .{});
}
