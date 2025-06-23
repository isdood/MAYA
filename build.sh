#!/bin/bash
set -e

# Create output directory
mkdir -p zig-out/bin

# First, let's check if we can compile a simple Zig program
echo "Testing Zig installation with a simple program..."

echo 'const std = @import("std"); pub fn main() void { std.debug.print("Zig is working!\n", .{}); }' > test.zig
zig build-exe -O ReleaseSafe test.zig -femit-bin=test-program
./test-program
rm test.zig test-program

echo -e "\nNow trying to compile the test_patterns executable..."

# Compile the test_patterns executable
zig build-exe -O ReleaseSafe \
    src/quantum_cache/test_patterns.zig \
    -lc \
    -I src \
    --mod neural:neural:src/neural/mod.zig \
    -femit-bin=zig-out/bin/test-patterns

echo -e "\nBuild successful! Executable is at zig-out/bin/test-patterns"
