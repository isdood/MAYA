# Quantum Circuit File Format

## Overview
Quantum circuits are stored in a simple text-based format that is both human-readable and easy to parse. Each line represents a single operation in the circuit.

## File Structure

### Header (Optional)
```
# Quantum Circuit File
# Format Version: 1.0
# Qubits: 2
```

### Operations
Each operation is on its own line with space-separated fields:
```
<OPERATION_TYPE> [ARGUMENTS...]
```

## Operation Reference

### Qubit Initialization
```
QUBITS <count>
```
- `count`: Number of qubits to initialize (default is 1 if not specified)

### Single-Qubit Gates
```
GATE <gate_name> <target_qubit>
```
- `gate_name`: One of: X, Y, Z, H, S, T
- `target_qubit`: Index of the target qubit (0-based)

### Two-Qubit Gates
```
CNOT <control_qubit> <target_qubit>
```
- `control_qubit`: Index of the control qubit
- `target_qubit`: Index of the target qubit

### Measurement
```
MEASURE <qubit_index> [classical_bit]
```
- `qubit_index`: Index of the qubit to measure
- `classical_bit`: (Optional) Classical bit to store result

## Example Files

### Bell Pair Circuit
```
# Create a Bell pair between qubits 0 and 1
QUBITS 2
GATE H 0
CNOT 0 1
```

### Grover's Algorithm (2 qubits)
```
# 2-qubit Grover's algorithm
QUBITS 2
GATE H 0
GATE H 1
GATE X 1
GATE H 1
CNOT 0 1
GATE H 1
GATE X 1
GATE H 0
GATE H 1
GATE X 0
GATE X 1
GATE H 1
CNOT 0 1
GATE H 1
GATE X 0
GATE X 1
GATE H 0
GATE H 1
```

## Versioning
- Version 1.0: Initial version

## Notes
- Lines starting with `#` are comments
- Blank lines are ignored
- Qubit indices are 0-based
- The order of operations is preserved during execution
