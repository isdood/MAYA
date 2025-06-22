# 🚀 GPU Acceleration Module

This module provides GPU-accelerated pattern evolution using ROCm/HIP for AMD GPUs.

## Features

- GPU-accelerated fitness calculation
- Automatic CPU fallback when GPU is not available
- Memory-efficient batch processing
- Support for AMD GPUs via ROCm

## Requirements

- Linux (ROCm currently has limited Windows support)
- AMD GPU with ROCm support (e.g., Radeon RX 5000/6000/7000 series)
- ROCm 5.x or later installed
- Zig 0.11.0 or later

## Installation

1. Install ROCm following the [official instructions](https://rocm.docs.amd.com/en/latest/Installation_Guide/Installation-Guide.html)
2. Verify ROCm installation:
   ```bash
   rocminfo
   ```
3. Build with GPU support:
   ```bash
   zig build -Doptimize=ReleaseFast -Denable-gpu=true
   ```

## Usage

```zig
const gpu = @import("gpu");

// Initialize GPU evolution
var gpu_evolution = try gpu_evolution.GPUEvolution.init(
    allocator,
    .{
        .batch_size = 1024,
        .threads_per_block = 256,
        .enabled = true,
    }
);
defer gpu_evolution.deinit();

// Calculate fitness for a batch of patterns
const fitness_values = try gpu_evolution.calculateFitnessBatch(patterns, width, height);
defer allocator.free(fitness_values);
```

## Configuration

### `GPUEvolution.Config`

- `batch_size`: Maximum number of patterns to process in parallel (default: 1024)
- `threads_per_block`: Number of threads per GPU block (default: 256)
- `enabled`: Whether to enable GPU acceleration (default: true)

## Performance Tips

1. **Batch Size**: Larger batches generally provide better GPU utilization
2. **Memory**: Ensure you have enough GPU memory for your batch size
3. **CPU Fallback**: The module will automatically fall back to CPU if GPU is not available
4. **Profiling**: Use `rocprof` to profile GPU kernel performance

## Example

See `examples/gpu_evolution.zig` for a complete example.

## Building the Example

```bash
zig build gpu_evolution
./zig-out/bin/gpu_evolution
```

## Troubleshooting

### ROCm Not Found

If you get errors about missing ROCm libraries:

1. Verify ROCm is installed and in your library path:
   ```bash
   echo $LD_LIBRARY_PATH
   ```
   Should include `/opt/rocm/lib`

2. If using a custom ROCm installation path, specify it during build:
   ```bash
   zig build -Drocm-path=/path/to/rocm
   ```

### Unsupported GPU

If your GPU is not supported by ROCm, the module will automatically fall back to CPU. Check the [ROCm documentation](https://rocm.docs.amd.com/en/latest/Installation_Guide/Installation-Guide.html#supported-gpus) for a list of supported GPUs.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
