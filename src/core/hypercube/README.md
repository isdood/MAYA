# HYPERCUBE: 4D Neural Architecture for MAYA

HYPERCUBE is a novel 4D neural architecture designed for the MAYA neural core, featuring advanced tensor operations, spiral convolutions, and GLIMMER visualization.

## Features

- **4D Tensor Operations**: Efficient manipulation of 4-dimensional tensors
- **Spiral Convolutions**: Unique convolution patterns following Fibonacci spirals
- **GLIMMER Visualization**: Intuitive visualization of high-dimensional data
- **Quantum-Inspired**: Leverages quantum-inspired computation patterns

## Building

To build the HYPERCUBE module:

```bash
# Build the hypercube library and executable
zig build

# Run the example
zig build hypercube -- example

# Run tests
zig build test-hypercube
```

## Usage

### Command Line Interface

```bash
# Show help
./zig-out/bin/hypercube

# Run the example
./zig-out/bin/hypercube example

# Visualize a spiral kernel
./zig-out/bin/hypercube visualize kernel

# Visualize a custom spiral kernel (size=15, 3 rotations)
./zig-out/bin/hypercube visualize kernel 15 3.0
```

### Programmatic Usage

```zig
const hypercube = @import("hypercube");
const Tensor4D = hypercube.Tensor4D;
const SpiralConv = hypercube.SpiralConv;
const glimmer = hypercube.glimmer;

// Create a 4D tensor
var tensor = try Tensor4D.init(allocator, [4]usize{1, 1, 32, 32});
defer tensor.deinit();

// Fill with data
// ...

// Create a spiral convolution layer
const conv = try SpiralConv.init(allocator, 1, 1, .{
    .kernel_size = 5,
    .stride = 1,
    .padding = 2,
});
defer conv.deinit();

// Apply convolution
const output = try conv.forward(&tensor);
defer output.deinit();

// Visualize the result
const ppm_data = try glimmer.renderTensor4D(allocator, &output, .{});
defer allocator.free(ppm_data);
```

## Examples

### 1. Basic Tensor Operations

```zig
// Create two 4D tensors
var a = try Tensor4D.init(allocator, [4]usize{1, 1, 5, 5});
defer a.deinit();

var b = try Tensor4D.init(allocator, [4]usize{1, 1, 5, 5});
defer b.deinit();

// Fill with data
a.fill(2.0);
b.fill(3.0);

// Element-wise addition
try a.add(&b);
```

### 2. Spiral Convolution

```zig
// Create input tensor (batch=1, channels=1, height=32, width=32)
var input = try Tensor4D.init(allocator, [4]usize{1, 1, 32, 32});
defer input.deinit();

// Create spiral convolution layer
const conv = try SpiralConv.init(allocator, 1, 1, .{
    .kernel_size = 5,
    .stride = 1,
    .padding = 2,
});
defer conv.deinit();

// Apply convolution
const output = try conv.forward(&input);
defer output.deinit();
```

## Visualization

HYPERCUBE includes the GLIMMER visualization system for exploring high-dimensional data:

```zig
// Create a gradient pattern
for (0..height) |y| {
    for (0..width) |x| {
        const value = (@as(f32, @floatFromInt(x + y)) / @as(f32, @floatFromInt(height + width - 2)));
        input.set(0, 0, y, x, value);
    }
}

// Render to PPM format
const ppm_data = try glimmer.renderTensor4D(allocator, &input, .{});
defer allocator.free(ppm_data);

// Save to file
try std.fs.cwd().writeFile("output.ppm", ppm_data);
```

## License

This project is part of the MAYA ecosystem and is licensed under the same terms as the main MAYA project.

## Contributing

Contributions are welcome! Please follow the contribution guidelines in the main MAYA repository.
