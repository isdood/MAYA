
//! Quantum Types and Operations
//! Defines quantum states, gates, and operations for the MAYA quantum processor

const std = @import("std");

/// Quantum state representation
pub const QuantumState = struct {
    // Basic quantum properties
    coherence: f64,
    entanglement: f64,
    superposition: f64,
    
    // Quantum register state
    qubits: []Qubit,
    
    /// Initialize a new quantum state with n qubits
    pub fn init(allocator: std.mem.Allocator, num_qubits: usize) !@This() {
        const qubits = try allocator.alloc(Qubit, num_qubits);
        @memset(qubits, Qubit{ .amplitude0 = 1.0, .amplitude1 = 0.0 });
        
        return .{
            .coherence = 1.0,
            .entanglement = 0.0,
            .superposition = 0.0,
            .qubits = qubits,
        };
    }
    
    /// Deinitialize and free resources
    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.qubits);
    }
    
    /// Measure the quantum state (collapses the state)
    pub fn measure(self: *@This(), qubit_index: usize) bool {
        if (qubit_index >= self.qubits.len) @panic("Qubit index out of bounds");
        
        const qubit = &self.qubits[qubit_index];
        const prob1 = qubit.amplitude1 * qubit.amplitude1;
        const result = std.crypto.random.float(f64) < prob1;
        
        // Collapse the state
        if (result) {
            qubit.amplitude0 = 0.0;
            qubit.amplitude1 = 1.0;
        } else {
            qubit.amplitude0 = 1.0;
            qubit.amplitude1 = 0.0;
        }
        
        return result;
    }
};

/// Single qubit state
pub const Qubit = struct {
    // Complex amplitudes for |0⟩ and |1⟩ states
    amplitude0: f64 = 1.0,  // Amplitude for |0⟩
    amplitude1: f64 = 0.0,  // Amplitude for |1⟩
    
    // Phase information
    phase: f64 = 0.0,
    
    /// Apply a quantum gate to this qubit
    pub fn applyGate(self: *Qubit, gate: Gate) void {
        switch (gate) {
            .x => self.x(),
            .y => self.y(),
            .z => self.z(),
            .h => self.h(),
            .s => self.s(),
            .t => self.t(),
            .rx => |angle| self.rx(angle),
            .ry => |angle| self.ry(angle),
            .rz => |angle| self.rz(angle),
            .phase => |angle| self.phase_shift(angle),
        }
    }
    
    // Basic quantum gates
    fn x(self: *Qubit) void {
        // Pauli-X gate (quantum NOT)
        const tmp = self.amplitude0;
        self.amplitude0 = self.amplitude1;
        self.amplitude1 = tmp;
    }
    
    fn y(self: *Qubit) void {
        // Pauli-Y gate
        const tmp = self.amplitude0;
        self.amplitude0 = self.amplitude1 * std.math.sin(self.phase + std.math.pi/2);
        self.amplitude1 = -tmp * std.math.sin(self.phase + std.math.pi/2);
        self.phase += std.math.pi/2;
    }
    
    fn z(self: *Qubit) void {
        // Pauli-Z gate
        self.amplitude1 = -self.amplitude1;
    }
    
    fn h(self: *Qubit) void {
        // Hadamard gate
        const a = self.amplitude0;
        const b = self.amplitude1;
        const sqrt2 = 1.0 / std.math.sqrt(2.0);
        
        self.amplitude0 = (a + b) * sqrt2;
        self.amplitude1 = (a - b) * sqrt2;
    }
    
    fn s(self: *Qubit) void {
        // Phase gate (S gate)
        self.amplitude1 *= std.complex.exp(@as(f64, 0), std.math.pi/2);
    }
    
    fn t(self: *Qubit) void {
        // T gate (π/8 gate)
        self.amplitude1 *= std.complex.exp(@as(f64, 0), std.math.pi/4);
    }
    
    // Rotation gates
    fn rx(self: *Qubit, theta: f64) void {
        // Rotation around X-axis
        const cos_t = @cos(theta/2);
        const sin_t = @sin(theta/2);
        
        const a = self.amplitude0 * cos_t - std.complex.I * self.amplitude1 * sin_t;
        const b = -std.complex.I * self.amplitude0 * sin_t + self.amplitude1 * cos_t;
        
        self.amplitude0 = a;
        self.amplitude1 = b;
    }
    
    fn ry(self: *Qubit, theta: f64) void {
        // Rotation around Y-axis
        const cos_t = @cos(theta/2);
        const sin_t = @sin(theta/2);
        
        const a = self.amplitude0 * cos_t - self.amplitude1 * sin_t;
        const b = self.amplitude0 * sin_t + self.amplitude1 * cos_t;
        
        self.amplitude0 = a;
        self.amplitude1 = b;
    }
    
    fn rz(self: *Qubit, theta: f64) void {
        // Rotation around Z-axis
        const cos_t = @cos(theta/2);
        const sin_t = @sin(theta/2);
        
        self.amplitude0 = self.amplitude0 * (cos_t - std.complex.I * sin_t);
        self.amplitude1 = self.amplitude1 * (cos_t + std.complex.I * sin_t);
    }
    
    fn phase_shift(self: *Qubit, phi: f64) void {
        // Phase shift gate
        self.amplitude1 *= std.complex.exp(@as(f64, 0), phi);
    }
};

/// Quantum gates
pub const Gate = union(enum) {
    x, y, z,          // Pauli gates
    h, s, t,           // Clifford gates
    rx: f64, ry: f64, rz: f64,  // Rotation gates
    phase: f64,        // Phase shift
};

/// Quantum circuit operation
pub const Operation = struct {
    gate: Gate,
    target_qubit: usize,
    control_qubits: ?[]const usize = null,  // For controlled gates
};

/// Quantum circuit
pub const QuantumCircuit = struct {
    num_qubits: usize,
    operations: std.ArrayList(Operation),
    
    pub fn init(allocator: std.mem.Allocator, num_qubits: usize) @This() {
        return .{
            .num_qubits = num_qubits,
            .operations = std.ArrayList(Operation).init(allocator),
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.operations.deinit();
    }
    
    /// Add a quantum gate to the circuit
    pub fn addGate(self: *@This(), gate: Gate, target: usize, controls: ?[]const usize) !void {
        if (target >= self.num_qubits) return error.InvalidQubitIndex;
        
        if (controls) |ctrl_qubits| {
            for (ctrl_qubits) |q| {
                if (q >= self.num_qubits) return error.InvalidControlQubit;
            }
        }
        
        try self.operations.append(Operation{
            .gate = gate,
            .target_qubit = target,
            .control_qubits = controls,
        });
    }
    
    /// Execute the quantum circuit on a given state
    pub fn execute(self: *const @This(), state: *QuantumState) !void {
        for (self.operations.items) |op| {
            try self.applyGate(state, op);
        }
    }
    
    /// Apply a single gate operation to the quantum state
    fn applyGate(_: *const @This(), state: *QuantumState, op: Operation) !void {
        // For now, just apply directly to the target qubit
        // In a real implementation, this would handle controlled gates and entanglement
        if (op.target_qubit >= state.qubits.len) return error.InvalidQubitIndex;
        state.qubits[op.target_qubit].applyGate(op.gate);
    }
};

/// Quantum pattern matching result
pub const PatternMatch = struct {
    similarity: f64,           // Similarity score (0.0 to 1.0)
    confidence: f64,           // Confidence in the match (0.0 to 1.0)
    pattern_id: []const u8,    // ID of the matched pattern
    qubits_used: usize,        // Number of qubits used in the match
    depth: usize,              // Circuit depth required
    
    pub fn isValid(self: *const @This()) bool {
        return (self.similarity >= 0.0 and self.similarity <= 1.0) and
               (self.confidence >= 0.0 and self.confidence <= 1.0) and
               (self.pattern_id.len > 0);
    }
};
