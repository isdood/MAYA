const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();

// Simple Qubit State Representation
const QubitState = struct {
    alpha: f64 = 1.0,     // |0> amplitude (real)
    beta: f64 = 0.0,      // |1> amplitude (real part)
    beta_imag: f64 = 0.0, // |1> amplitude (imaginary part)

    pub fn applyGate(self: *@This(), gate: []const f64) void {
        // Apply 2x2 unitary gate to the qubit state
        const new_alpha = gate[0] * self.alpha + gate[1] * self.beta;
        const new_beta = gate[2] * self.alpha + gate[3] * self.beta;
        
        self.alpha = new_alpha;
        self.beta = new_beta;
        self.normalize();
    }

    fn normalize(self: *@This()) void {
        const norm = math.sqrt(self.alpha * self.alpha + 
                             self.beta * self.beta + 
                             self.beta_imag * self.beta_imag);
        if (norm > 0) {
            self.alpha /= norm;
            self.beta /= norm;
            self.beta_imag /= norm;
        }
    }

    pub fn measure(self: *@This()) bool {
        const prob1 = self.beta * self.beta + self.beta_imag * self.beta_imag;
        const r = std.crypto.random.float(f64);
        
        if (r < prob1) {
            // Collapse to |1>
            self.alpha = 0.0;
            self.beta = 1.0;
            self.beta_imag = 0.0;
            return true;
        } else {
            // Collapse to |0>
            self.alpha = 1.0;
            self.beta = 0.0;
            self.beta_imag = 0.0;
            return false;
        }
    }
};

// Quantum Circuit
const QuantumCircuit = struct {
    qubits: []QubitState,
    allocator: Allocator,

    pub fn init(allocator: Allocator, num_qubits: usize) !@This() {
        const qubits = try allocator.alloc(QubitState, num_qubits);
        for (qubits) |*qubit| {
            qubit.* = QubitState{};
        }
        return .{ .qubits = qubits, .allocator = allocator };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.qubits);
    }

    pub fn applyGate(self: *@This(), gate: []const f64, target: usize) void {
        if (target >= self.qubits.len) return;
        self.qubits[target].applyGate(gate);
    }

    pub fn applyControlledGate(self: *@This(), gate: []const f64, control: usize, target: usize) void {
        if (control >= self.qubits.len or target >= self.qubits.len) return;
        
        // Simple CNOT-like control
        if (self.qubits[control].measure()) {
            self.qubits[target].applyGate(gate);
        }
    }

    pub fn printState(self: *const @This()) !void {
        try stdout.print("\n=== Quantum Circuit State ===\n", .{});
        for (self.qubits, 0..) |qubit, i| {
            const prob0 = qubit.alpha * qubit.alpha;
            const prob1 = qubit.beta * qubit.beta + qubit.beta_imag * qubit.beta_imag;
            
            try stdout.print("Qubit {}: |ψ> = {d:.3}|0> + ({d:.3}{s}{d:.3}i)|1>  [P(0)={d:.3}, P(1)={d:.3}]\n", .{
                i,
                qubit.alpha,
                qubit.beta,
                if (qubit.beta_imag >= 0) "+" else "-",
                if (qubit.beta_imag >= 0) qubit.beta_imag else -qubit.beta_imag,
                prob0,
                prob1,
            });
            
            // Draw Bloch sphere representation
            try self.drawBlochSphere(qubit);
        }
    }

    fn drawBlochSphere(_: *const @This(), qubit: QubitState) !void {
        // Calculate Bloch sphere coordinates
        const x = 2.0 * (qubit.alpha * qubit.beta);
        const y = 2.0 * (qubit.alpha * -qubit.beta_imag);
        const z = qubit.alpha * qubit.alpha - (qubit.beta * qubit.beta + qubit.beta_imag * qubit.beta_imag);
        
        // Simple 2D projection of the Bloch sphere
        const width = 20;
        const height = 10;
        var grid: [height][width]u8 = undefined;
        
        // Initialize grid with spaces
        for (0..height) |i| {
            for (0..width) |j| {
                grid[i][j] = ' ';
            }
        }
        
        // Draw sphere outline
        for (0..100) |i| {
            const theta = 2.0 * math.pi * @as(f64, @floatFromInt(i)) / 100.0;
            const px = @as(usize, @intFromFloat((math.cos(theta) + 1.0) * 0.5 * @as(f64, @floatFromInt(width - 1))));
            const py = @as(usize, @intFromFloat((math.sin(theta) + 1.0) * 0.5 * @as(f64, @floatFromInt(height - 1))));
            if (px < width and py < height) {
                grid[py][px] = '.';
            }
        }
        
        // Draw axes
        for (0..width) |i| {
            grid[height/2][i] = '-';
        }
        for (0..height) |i| {
            grid[i][width/2] = '|';
        }
        
        // Draw state vector
        const px = @as(usize, @intFromFloat((x + 1.0) * 0.5 * @as(f64, @floatFromInt(width - 1))));
        const py = @as(usize, @intFromFloat((y + 1.0) * 0.5 * @as(f64, @floatFromInt(height - 1))));
        if (px < width and py < height) {
            grid[py][px] = '*';
        }
        
        // Draw grid
        try stdout.writeAll("  +");
        for (0..width) |_| try stdout.writeAll("-");
        try stdout.writeAll("+\n");
        
        for (0..height) |i| {
            try stdout.writeAll("  |");
            for (0..width) |j| {
                try stdout.writeByte(grid[i][j]);
            }
            try stdout.writeAll("|\n");
        }
        
        try stdout.writeAll("  +");
        for (0..width) |_| try stdout.writeAll("-");
        try stdout.writeAll("+\n");
        
        // Draw state info
        const theta = math.acos(z) * 2.0;
        const phi = math.atan2(y, x);
        try stdout.print("  θ = {d:.2}π, φ = {d:.2}π\n", .{theta / math.pi, phi / math.pi});
    }
};

// Common quantum gates
const Gates = struct {
    pub const X = &[_]f64{ 0, 1, 1, 0 };  // Pauli-X (NOT) gate
    pub const Y = &[_]f64{ 0, -1, 1, 0 };  // Pauli-Y gate
    pub const Z = &[_]f64{ 1, 0, 0, -1 };  // Pauli-Z gate
    pub const H = &[_]f64{ 1.0/math.sqrt(2.0), 1.0/math.sqrt(2.0), 
                          1.0/math.sqrt(2.0), -1.0/math.sqrt(2.0) };  // Hadamard
    pub const S = &[_]f64{ 1, 0, 0, 1.0 };  // Phase gate (S = √Z)
    pub const T = &[_]f64{ 1, 0, 0, 0.5 + 0.5 };  // π/8 gate (T = √S)
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a 2-qubit circuit
    var circuit = try QuantumCircuit.init(allocator, 2);
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
        .{ .name = "H", .gate = Gates.H, .target = 0, .control = null },
        .{ .name = "CNOT(0,1)", .gate = Gates.X, .target = 1, .control = 0 },
        .{ .name = "T", .gate = Gates.T, .target = 0, .control = null },
        .{ .name = "S", .gate = Gates.S, .target = 1, .control = null },
        .{ .name = "X", .gate = Gates.X, .target = 0, .control = null },
        .{ .name = "Y", .gate = Gates.Y, .target = 1, .control = null },
        .{ .name = "Z", .gate = Gates.Z, .target = 0, .control = null },
    };
    
    for (gates) |gate| {
        std.debug.print("\nApplying {s} to qubit {}:", .{gate.name, gate.target});
        if (gate.control) |c| std.debug.print(" (controlled by qubit {})", .{c});
        std.debug.print("\n", .{});
        
        if (gate.control) |c| {
            circuit.applyControlledGate(gate.gate, c, gate.target);
        } else {
            circuit.applyGate(gate.gate, gate.target);
        }
        
        try circuit.printState();
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
        std.debug.print("\n{s}\n", .{state.name});
        const q = QubitState{
            .alpha = state.alpha,
            .beta = state.beta,
            .beta_imag = state.beta_imag,
        };
        try circuit.drawBlochSphere(q);
    }
}
