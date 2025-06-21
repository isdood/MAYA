# Quantum Circuit Builder

## Overview
The Quantum Circuit Builder is an interactive tool for creating, visualizing, and simulating quantum circuits in the terminal. It provides a simple yet powerful interface for experimenting with quantum computing concepts.

## Features
- Interactive command-line interface
- Support for multiple qubits
- Standard quantum gates (X, Y, Z, H, S, T)
- Controlled operations (CNOT)
- Measurement and state collapse
- Circuit saving and loading
- Real-time state visualization

## Installation
```bash
git clone https://github.com/yourusername/MAYA.git
cd MAYA
zig build quantum-circuit-builder
```

## Quick Start
1. Start the quantum circuit builder:
   ```bash
   ./zig-out/bin/quantum_circuit_builder
   ```

2. Basic commands:
   ```
   add <n>          Add n qubits to the circuit
   gate <g> <t>     Apply gate g to target qubit t
   cnot <c> <t>     Apply CNOT with control c and target t
   measure <q>      Measure qubit q
   show             Display current circuit state
   save <file>      Save circuit to file
   load <file>      Load circuit from file
   help             Show help
   quit             Exit the program
   ```

## Examples

### Create a Bell Pair
```
add 2           # Add 2 qubits
gate h 0        # Apply Hadamard to qubit 0
cnot 0 1        # Create entanglement
show           # View the resulting state
```

### Save and Load Circuits
```
# Save the current circuit
save bell_pair.qc

# Later, load it back
load bell_pair.qc
```

## File Format
Circuit files are plain text with one operation per line:
```
GATE H 0
CNOT 0 1
```

## Documentation
- [Implementation Details](IMPLEMENTATION.md)
- [Circuit File Format](CIRCUIT_FORMAT.md)
- [Examples](EXAMPLES.md)
- [API Reference](API_REFERENCE.md)

## License
[Your License Here]
