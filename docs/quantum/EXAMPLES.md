# Quantum Circuit Examples

## Basic Operations

### Initialize and Measure
```
add 1       # Add 1 qubit
measure 0   # Measure the qubit
```

### Pauli X Gate (Bit Flip)
```
add 1
gate x 0    # Apply X gate
show
```

### Hadamard Gate (Superposition)
```
add 1
gate h 0    # Create |+> state
show
```

## Entanglement

### Bell State (EPR Pair)
```
add 2
gate h 0    # Create superposition
cnot 0 1    # Entangle qubits 0 and 1
show
```

### GHZ State (3-Qubit Entanglement)
```
add 3
gate h 0
cnot 0 1
cnot 0 2
show
```

## Quantum Algorithms

### Quantum Teleportation
```
# Alice's qubit (to be teleported)
add 3
gate h 0

# Create Bell pair between Alice and Bob
gate h 1
cnot 1 2

# Alice's operations
cnot 0 1
gate h 0

# Measure Alice's qubits
measure 0
measure 1

# Bob's operations (classically controlled)
# These would be applied based on measurement results
# c_if 1 x 2
# c_if 0 z 2
show
```

### Deutsch-Jozsa Algorithm (1-bit)
```
# Constant function: f(x) = 0
add 2
gate x 1
gate h 0
gate h 1
# Oracle: I (identity)
gate h 0
show

# Balanced function: f(x) = x
add 2
gate x 1
gate h 0
gate h 1
# Oracle: CNOT
gate x 1
cnot 0 1
gate x 1
gate h 0
show
```

## Quantum Error Correction

### Bit Flip Code
```
# Encode logical |0>
add 3
gate h 0
cnot 0 1
cnot 0 2

# Simulate bit flip error on qubit 1
gate x 1

# Error correction
cnot 0 1
cnot 0 2
gate ccx 1 2 0
show
```

## Saving and Loading

### Save a Circuit
```
add 2
gate h 0
cnot 0 1
save bell_pair.qc
```

### Load a Circuit
```
load bell_pair.qc
show
```

## Visualization Examples

### Multiple Gates
```
add 1
gate h 0
gate s 0
gate t 0
show
```

### Interactive Exploration
```
add 2
gate h 0
show
# Now try adding more gates interactively
```
