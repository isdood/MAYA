const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();

pub const QubitState = struct {
    alpha: f64, // |0> amplitude (real)
    beta: f64,  // |1> amplitude (complex)
    beta_imag: f64, // Imaginary part of beta

    pub fn init() QubitState {
        return .{ .alpha = 1.0, .beta = 0.0, .beta_imag = 0.0 };
    }

    pub fn applyGate(self: *QubitState, gate: []const f64) void {
        // Apply 2x2 unitary gate to the qubit state
        const new_alpha = gate[0] * self.alpha + gate[1] * self.beta;
        const new_beta = gate[2] * self.alpha + gate[3] * self.beta;
        const new_beta_imag = gate[2] * self.beta_imag + gate[3] * self.beta_imag;
        
        self.alpha = new_alpha;
        self.beta = new_beta;
        self.beta_imag = new_beta_imag;
        self.normalize();
    }

    fn normalize(self: *QubitState) void {
        const norm = math.sqrt(self.alpha * self.alpha + 
                             self.beta * self.beta + 
                             self.beta_imag * self.beta_imag);
        if (norm > 0) {
            self.alpha /= norm;
            self.beta /= norm;
            self.beta_imag /= norm;
        }
    }

    pub fn measure(self: *QubitState) bool {
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

pub const QuantumCircuit = struct {
    qubits: []QubitState,
    allocator: Allocator,

    pub fn init(allocator: Allocator, num_qubits: usize) !@This() {
        const qubits = try allocator.alloc(QubitState, num_qubits);
        for (qubits) |*qubit| {
            qubit.* = QubitState.init();
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
        // In a real implementation, this would be more complex for multi-qubit states
        if (self.qubits[control].measure()) {
            self.qubits[target].applyGate(gate);
        }
    }

    pub fn printState(self: *const @This()) !void {
        try stdout.print("\n=== Quantum Circuit State ===\n", .{});
        for (self.qubits, 0..) |qubit, i| {
            const prob0 = qubit.alpha * qubit.alpha;
            const prob1 = qubit.beta * qubit.beta + qubit.beta_imag * qubit.beta_imag;
            
            try stdout.print("Qubit {}: |ψ> = {d:.3}|0> + ({d:.3}{+d:.3}i)|1>  [P(0)={d:.3}, P(1)={d:.3}]\n", .{
                i,
                qubit.alpha,
                qubit.beta,
                qubit.beta_imag,
                prob0,
                prob1,
            });
            
            // Draw Bloch sphere representation
            try self.drawBlochSphere(qubit);
        }
    }

    fn drawBlochSphere(self: *const @This(), qubit: QubitState) !void {
        // Calculate Bloch sphere coordinates
        const x = 2.0 * (qubit.alpha * qubit.beta + qubit.beta_imag * 0);
        const y = 2.0 * (qubit.alpha * -qubit.beta_imag + qubit.beta * 0);
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
        try stdout.writeAll("  +" ++ "-" ** width ++ "+\n");
        for (0..height) |i| {
            try stdout.writeAll("  |");
            for (0..width) |j| {
                try stdout.writeByte(grid[i][j]);
            }
            try stdout.writeAll("|\n");
        }
        try stdout.writeAll("  +" ++ "-" ** width ++ "+\n");
        
        // Draw state info
        const theta = math.acos(z) * 2.0;
        const phi = math.atan2(f64, y, x);
        try stdout.print("  θ = {d:.2}π, φ = {d:.2}π\n", .{theta / math.pi, phi / math.pi});
    }
};

// Common quantum gates
pub const Gates = struct {
    pub const X = &[_]f64{ 0, 1, 1, 0 };  // Pauli-X (NOT) gate
    pub const Y = &[_]f64{ 0, -1, 1, 0 };  // Pauli-Y gate
    pub const Z = &[_]f64{ 1, 0, 0, -1 };  // Pauli-Z gate
    pub const H = &[_]f64{ 1.0/math.sqrt(2.0), 1.0/math.sqrt(2.0), 
                          1.0/math.sqrt(2.0), -1.0/math.sqrt(2.0) };  // Hadamard
    pub const S = &[_]f64{ 1, 0, 0, 1.0i };  // Phase gate (S = √Z)
    pub const T = &[_]f64{ 1, 0, 0, (1.0 + 1.0i)/math.sqrt(2.0) };  // π/8 gate (T = √S)
};

// Example usage
pub fn demo() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a 2-qubit circuit
    var circuit = try QuantumCircuit.init(allocator, 2);
    defer circuit.deinit();
    
    try stdout.writeAll("Initial state:\n");
    try circuit.printState();
    
    // Apply Hadamard to first qubit
    try stdout.writeAll("\nAfter H(0):\n");
    circuit.applyGate(Gates.H, 0);
    try circuit.printState();
    
    // Apply CNOT (controlled-X)
    try stdout.writeAll("\nAfter CNOT(0,1):\n");
    circuit.applyControlledGate(Gates.X, 0, 1);
    try circuit.printState();
    
    // Apply T gate to first qubit
    try stdout.writeAll("\nAfter T(0):\n");
    circuit.applyGate(Gates.T, 0);
    try circuit.printState();
    
    // Apply S gate to second qubit
    try stdout.writeAll("\nAfter S(1):\n");
    circuit.applyGate(Gates.S, 1);
    try circuit.printState();
}
