@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 12:32:20",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./scripts/build-windsurf.fish",
    "type": "fish",
    "hash": "2200bf1c14f95514f01f1bf7b5645bb2701eadee"
  }
}
@pattern_meta@

#!/usr/bin/env fish
# Build and test script for Windsurf integration
# Usage: fish scripts/build-windsurf.fish [--release] [--test] [--clean]

# Configuration
set -l zig_cmd zig
set -l build_dir "build"
set -l release_build false
set -l run_tests false
set -l clean_build false
set -l build_options ""
set -l test_options ""

# Parse command line arguments
for arg in $argv
    switch $arg
        case '--release'
            set release_build true
        case '--test'
            set run_tests true
        case '--clean'
            set clean_build true
        case '-h' '--help'
            echo "Build and test script for Windsurf integration"
            echo "Usage: fish scripts/build-windsurf.fish [options]"
            echo "Options:"
            echo "  --release    Build in release mode"
            echo "  --test       Run tests after building"
            echo "  --clean      Clean build directory before building"
            echo "  -h, --help   Show this help message"
            return 0
    end
end

# Set build options
if test "$release_build" = "true"
    set build_options "-Doptimize=ReleaseSafe"
    echo "Building in release mode..."
else
    set build_options "-Doptimize=Debug"
    echo "Building in debug mode..."
end

# Clean build directory if requested
if test "$clean_build" = "true"
    echo "Cleaning build directory..."
    rm -rf "$build_dir"
end

# Create build directory if it doesn't exist
if not test -d "$build_dir"
    echo "Creating build directory: $build_dir"
    mkdir -p "$build_dir"
end

# Check Zig version
set -l zig_version ($zig_cmd version | cut -d' ' -f2)
echo "Using Zig version: $zig_version"

# Build the project
echo "Building project..."
if not $zig_cmd build $build_options
    echo "Build failed"
    return 1
end

# Run tests if requested
if test "$run_tests" = "true"
    echo "Running tests..."
    # First run the main test suite if it exists
    if test -f "test/main.zig"
        if not $zig_cmd test test/main.zig $build_options
            echo "Tests failed"
            return 1
        end
    end
    
    # Run integration tests
    echo "Running integration tests..."
    if not $zig_cmd test src/starweave/client_test.zig $build_options --test-filter "integration"
        echo "Integration tests failed"
        return 1
    end
end

echo "Build completed successfully!"
return 0
