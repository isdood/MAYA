#!/bin/bash
set -e

# Create output directory
mkdir -p zig-out/bin

# Build the example
zig build-exe -O Debug \
  -I../src -I../src/neural \
  -femit-bin=zig-out/bin/temporal_processing \
  --main-pkg-path . \
  temporal_processing.zig \
  ../src/neural/tensor4d.zig \
  ../src/neural/attention.zig \
  ../src/neural/quantum_tunneling.zig \
  ../src/neural/temporal.zig \
  ../src/neural/hypercube_bridge.zig

echo "Build successful! Run with: ./zig-out/bin/temporal_processing"
