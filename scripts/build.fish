#!/usr/bin/env fish

# MAYA build script
# This script automates the build and test process for the MAYA project

function print_section
    set_color -o cyan
    echo "=== $argv ==="
    set_color normal
end

function check_command
    if not command -v $argv >/dev/null
        set_color red
        echo "Error: $argv is not installed"
        set_color normal
        exit 1
    end
end

# Check required tools
print_section "Checking dependencies"
check_command zig
check_command fish

# Create build directory if it doesn't exist
if not test -d build
    print_section "Creating build directory"
    mkdir -p build
end

# Build the project
print_section "Building MAYA"
zig build

# Run tests
print_section "Running tests"
zig build test

# Check build artifacts
print_section "Checking build artifacts"
if test -f zig-out/bin/maya
    set_color green
    echo "✓ Build successful: maya executable created"
    set_color normal
else
    set_color red
    echo "✗ Build failed: maya executable not found"
    set_color normal
    exit 1
end

# Print success message
set_color green
echo "✨ MAYA build completed successfully!"
set_color normal 