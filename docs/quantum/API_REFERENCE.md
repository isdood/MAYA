# Quantum Circuit Builder API Reference

## Table of Contents
- [QubitState](#qubitstate)
- [QuantumCircuit](#quantumcircuit)
- [Gates](#gates)
- [Command Parser](#command-parser)

## QubitState

Represents the quantum state of a single qubit.

### Fields
- `alpha: f64` - Amplitude of |0⟩ state (real part)
- `beta: f64` - Amplitude of |1⟩ state (real part)
- `beta_imag: f64` - Amplitude of |1⟩ state (imaginary part)

### Methods

#### `applyGate`
```zig
fn applyGate(self: *QubitState, gate: []const f64) void
```
Applies a 2x2 unitary gate to the qubit state.

**Parameters:**
- `gate`: 4-element array representing the 2x2 gate matrix in row-major order

#### `measure`
```zig
fn measure(self: *QubitState) bool
```
Meures the qubit and collapses its state.

**Returns:**
- `true` if |1⟩ was measured, `false` if |0⟩

#### `normalize`
```zig
fn normalize(self: *QubitState) void
```
Normalizes the qubit state vector.

## QuantumCircuit

Manages a collection of qubits and operations.

### Creation
```zig
fn init(allocator: Allocator, num_qubits: usize) !QuantumCircuit
```

### Methods

#### `deinit`
```zig
fn deinit(self: *QuantumCircuit) void
```
Frees all resources.

#### `applyGate`
```zig
fn applyGate(
    self: *QuantumCircuit,
    gate: []const f64,
    target: usize
) !void
```
Applies a single-qubit gate.

#### `applyControlledGate`
```zig
fn applyControlledGate(
    self: *QuantumCircuit,
    gate: []const f64,
    control: usize,
    target: usize
) !void
```
Applies a controlled gate.

#### `measure`
```zig
fn measure(self: *QuantumCircuit, qubit: usize) !bool
```
Measures a qubit.

#### `printState`
```zig
fn printState(self: *const QuantumCircuit) !void
```
Prints the current state of all qubits.

#### `saveToFile`
```zig
fn saveToFile(self: *const QuantumCircuit, filename: []const u8) !void
```
Saves the circuit to a file.

#### `loadFromFile`
```zig
fn loadFromFile(
    allocator: Allocator,
    filename: []const u8
) !QuantumCircuit
```
Loads a circuit from a file.

## Gates

Predefined quantum gates.

### Single-Qubit Gates
- `X`: Pauli-X (bit flip)
- `Y`: Pauli-Y
- `Z`: Pauli-Z (phase flip)
- `H`: Hadamard
- `S`: Phase (√Z)
- `T`: π/8 gate

### Two-Qubit Gates
- `CNOT`: Controlled-NOT

### Usage
```zig
// Apply a Hadamard gate to qubit 0
try circuit.applyGate(Gates.H, 0);

// Apply CNOT with control 0 and target 1
try circuit.applyControlledGate(Gates.X, 0, 1);
```

## Command Parser

Parses user input into commands.

### Commands
- `add <n>`: Add n qubits
- `gate <name> <target>`: Apply gate
- `cnot <control> <target>`: Apply CNOT
- `measure <qubit>`: Measure qubit
- `show`: Show state
- `save <file>`: Save circuit
- `load <file>`: Load circuit
- `help`: Show help
- `quit`: Exit

### Usage
```zig
const cmd = try Command.parse("gate h 0");
switch (cmd) {
    .apply_gate => |g| {
        // Handle gate application
    },
    // ... other commands ...
}
```

## File Format

See [CIRCUIT_FORMAT.md](CIRCUIT_FORMAT.md) for details on the file format used for saving/loading circuits.

## Error Handling

All functions that can fail return an error union. Common errors include:
- `error.OutOfMemory`: Allocation failure
- `error.InvalidQubit`: Invalid qubit index
- `error.InvalidGate`: Unknown gate name
- `error.FileNotFound`: Circuit file not found
- `error.InvalidFileFormat`: Malformed circuit file
