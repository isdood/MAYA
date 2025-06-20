@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 12:21:59",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/starweave/README.md",
    "type": "md",
    "hash": "0a9b967ccacf8cf0e2fb69801791a0723169fae7"
  }
}
@pattern_meta@

# STARWEAVE Client

A high-performance, type-safe Zig implementation of the STARWEAVE protocol client, designed for secure and efficient quantum-neural communication within the MAYA ecosystem.

## Features

- **Quantum-Neural Communication**
  - Quantum state synchronization
  - Neural activity pattern transmission
  - Bidirectional streaming support
  - Protocol version negotiation

- **Security**
  - TLS 1.3 with certificate pinning
  - Quantum-resistant encryption
  - Mutual TLS authentication
  - Token-based authentication with automatic refresh

- **Reliability**
  - Automatic reconnection with exponential backoff
  - Configurable retry policies
  - Message deduplication
  - Exactly-once delivery semantics

- **Performance**
  - Zero-copy message processing
  - Connection pooling
  - Batch message processing
  - Compression (zstd, gzip, deflate)

- **Observability**
  - Structured logging
  - Prometheus metrics
  - Distributed tracing
  - Health checks

## Prerequisites

- Zig 0.11.0 or later
- MAYA project dependencies
- OpenSSL 3.0+ (for TLS support)
- zstd development libraries

## Installation

Add the STARWEAVE client as a dependency in your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "your-application",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add STARWEAVE client module
    const starweave = b.dependency("starweave", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("starweave", starweave.module("starweave"));
    exe.linkLibrary(starweave.artifact("starweave"));

    // Link system libraries
    exe.linkSystemLibrary("zstd");
    exe.linkSystemLibrary("ssl");
    exe.linkSystemLibrary("crypto");

    b.installArtifact(exe);
}
```

## Quick Start

### Basic Client Initialization

```zig
const std = @import("std");
const starweave = @import("starweave");

pub fn main() !void {
    // Initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize client configuration
    const config = starweave.Config{
        .host = "starweave.example.com",
        .port = 443,
        .auth = .{
            .token = .{
                .token = "your-auth-token",
                .token_type = "Bearer",
            },
        },
        .tls = .{
            .enabled = true,
            .verify_cert = true,
            .ca_cert_path = "/etc/ssl/certs/ca-certificates.crt",
        },
        .compression = .{
            .enabled = true,
            .algorithm = .zstd,
            .level = .default,
        },
        .timeouts = .{
            .connect = 10_000,  // 10 seconds
            .read = 30_000,     // 30 seconds
            .write = 30_000,    // 30 seconds
        },
        .retry = .{
            .max_attempts = 5,
            .initial_delay = 100,  // 100ms
            .max_delay = 30_000,   // 30 seconds
            .backoff_factor = 2.0,
        },
    };

    // Initialize client
    var client = try starweave.Client.init(allocator, config);
    defer client.deinit();

    // Connect to server
    try client.connect();
    defer client.disconnect();

    // Send a quantum state update
    const quantum_state = try starweave.QuantumState.init(
        allocator,
        .{ .superposition = .{ .amplitudes = &.{0.5, 0.5} } },
        .{ .phase = 0.0 },
        .{ .energy = 1.0 },
    );
    defer quantum_state.deinit();

    try client.sendQuantumState("quantum-channel-1", quantum_state);

    // Receive neural activity updates
    while (true) {
        const activity = try client.receiveNeuralActivity();
        defer activity.deinit();
        
        std.debug.print("Received neural activity: {d} Hz\n", .{activity.frequency});
        
        // Process activity...
        if (activity.frequency > 100.0) {
            // Handle high-frequency activity
            try client.sendPattern(.{
                .intensity = 1.0,
                .frequency = activity.frequency,
                .phase = 0.0,
            });
        }
    }
}
```

## Configuration

### Client Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `host` | `[]const u8` | Required | STARWEAVE server hostname |
| `port` | `u16` | Required | STARWEAVE server port |
| `auth` | `AuthConfig` | Required | Authentication configuration |
| `tls` | `TlsConfig` | See below | TLS configuration |
| `compression` | `CompressionConfig` | See below | Compression settings |
| `timeouts` | `Timeouts` | See below | Connection timeouts |
| `retry` | `RetryConfig` | See below | Retry policy |
| `metrics` | `MetricsConfig` | Disabled | Metrics collection |
| `logging` | `LoggingConfig` | Default logging | Logging configuration |

### TLS Configuration

```zig
.tls = .{
    .enabled = true,
    .verify_cert = true,
    .ca_cert_path = "/path/to/ca.crt",
    .client_cert_path = "/path/to/client.crt",
    .client_key_path = "/path/to/client.key",
    .min_version = .tls12,
    .max_version = .tls13,
    .ciphers = "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256",
},
```

### Compression Configuration

```zig
.compression = .{
    .enabled = true,
    .algorithm = .zstd,  // .zstd, .gzip, .deflate
    .level = .default,  // .fastest, .default, .best
    .threshold = 1024,  // Minimum size to compress (bytes)
},
```

### Timeout Configuration

```zig
.timeouts = .{
    .connect = 10_000,  // 10 seconds
    .read = 30_000,    // 30 seconds
    .write = 30_000,   // 30 seconds
    .handshake = 5_000, // 5 seconds
    .idle = 300_000,   // 5 minutes
},
```

### Retry Configuration

```zig
.retry = .{
    .max_attempts = 5,
    .initial_delay = 100,  // 100ms
    .max_delay = 30_000,  // 30 seconds
    .backoff_factor = 2.0,
    .jitter_factor = 0.2,
    .timeout = 60_000,   // 60 seconds
},
```

## Authentication

### Token Authentication

```zig
.auth = .{
    .token = .{
        .token = "your-token",
        .token_type = "Bearer",
        .refresh_token = "refresh-token",  // Optional
        .refresh_url = "https://auth.example.com/token",  // Optional
    },
},
```

### JWT Authentication

```zig
.auth = .{
    .jwt = .{
        .token = "your.jwt.token",
        .public_key = "public-key-for-verification",
        .audience = "your-audience",
        .issuer = "token-issuer",
        .refresh = .{
            .url = "https://auth.example.com/refresh",
            .interval = 300,  // 5 minutes
        },
    },
},
```

### OAuth2 Authentication

```zig
.auth = .{
    .oauth2 = .{
        .access_token = "oauth2-access-token",
        .token_type = "Bearer",
        .refresh_token = "refresh-token",
        .token_url = "https://auth.example.com/oauth2/token",
        .client_id = "your-client-id",
        .client_secret = "your-client-secret",
        .scopes = &{"read", "write"},
    },
},
```

### mTLS Authentication

```zig
.auth = .{
    .mtls = .{
        .cert_path = "/path/to/client.crt",
        .key_path = "/path/to/client.key",
    },
},
```

## API Reference

### Core Types

#### `Client`

The main client type for interacting with the STARWEAVE server.

```zig
const Client = struct {
    pub fn init(allocator: std.mem.Allocator, config: Config) !Client;
    pub fn deinit(self: *Client) void;
    pub fn connect(self: *Client) !void;
    pub fn disconnect(self: *Client) void;
    pub fn isConnected(self: *const Client) bool;
    pub fn sendQuantumState(self: *Client, channel: []const u8, state: QuantumState) !void;
    pub fn receiveQuantumState(self: *Client) !QuantumState;
    pub fn sendNeuralActivity(self: *Client, activity: NeuralActivity) !void;
    pub fn receiveNeuralActivity(self: *Client) !NeuralActivity;
    pub fn sendPattern(self: *Client, pattern: Pattern) !void;
    pub fn receivePattern(self: *Client) !Pattern;
    pub fn subscribe(self: *Client, channel: []const u8) !void;
    pub fn unsubscribe(self: *Client, channel: []const u8) void;
    pub fn ping(self: *Client) !void;
};
```

#### `QuantumState`

Represents a quantum state with amplitude, phase, and energy.

```zig
const QuantumState = struct {
    amplitude: Amplitude,
    phase: Phase,
    energy: Energy,
    timestamp: i64,
    
    pub fn init(allocator: std.mem.Allocator, amplitude: Amplitude, phase: Phase, energy: Energy) !QuantumState;
    pub fn deinit(self: *QuantumState) void;
    pub fn measure(self: *const QuantumState) !f64;
    pub fn entangle(self: *QuantumState, other: *QuantumState) !void;
};
```

#### `NeuralActivity`

Represents neural activity with frequency, amplitude, and phase.

```zig
const NeuralActivity = struct {
    frequency: f64,  // Hz
    amplitude: f64,  // 0.0 to 1.0
    phase: f64,      // radians
    timestamp: i64,
    
    pub fn init(frequency: f64, amplitude: f64, phase: f64) NeuralActivity;
    pub fn validate(self: *const NeuralActivity) !void;
};
```

### Example: Quantum-Neural Bridge

```zig
// Initialize quantum state
var quantum_state = try QuantumState.init(
    allocator,
    .{ .superposition = .{ .amplitudes = &.{0.7, 0.3} } },
    .{ .phase = 0.0 },
    .{ .energy = 1.0 },
);
defer quantum_state.deinit();

// Send quantum state update
try client.sendQuantumState("quantum-channel", quantum_state);

// Handle neural activity updates
while (true) {
    const activity = try client.receiveNeuralActivity();
    defer activity.deinit();
    
    // Process neural activity
    if (activity.frequency > 100.0) {
        // Update quantum state based on neural activity
        quantum_state.amplitude = .{ .superposition = .{
            .amplitudes = &.{activity.amplitude, 1.0 - activity.amplitude}
        }};
        
        // Send updated state
        try client.sendQuantumState("quantum-channel", quantum_state);
    }
}
```

## Error Handling

### Error Types

```zig
const Error = error{
    ConnectionFailed,
    AuthenticationFailed,
    InvalidMessage,
    Timeout,
    ProtocolError,
    InvalidState,
    ResourceExhausted,
    NotSupported,
    NetworkError,
    SerializationError,
    DeserializationError,
    InvalidArgument,
    OutOfMemory,
};
```

### Example: Error Handling

```zig
errdefer {
    std.log.err("Error: {}", .{err});
    
    // Attempt to reconnect on connection errors
    if (err == error.ConnectionFailed || err == error.Timeout) {
        std.log.info("Attempting to reconnect...", .{});
        
        // Exponential backoff with jitter
        const backoff = std.math.min(
            initial_delay * std.math.pow(u64, 2, attempt) + 
            std.crypto.random.intRangeAtMost(u64, 0, 1000),
            max_delay
        );
        
        std.time.sleep(backoff * std.time.ns_per_ms);
        
        // Reconnect logic...
    }
}
```

## Monitoring and Observability

### Metrics

The client exposes Prometheus metrics when enabled:

```zig
.metrics = .{
    .enabled = true,
    .port = 9090,
    .path = "/metrics",
    .namespace = "starweave",
    .buckets = .{ 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0 },
},
```

Example metrics:

```
# HELP starweave_connection_attempts_total Total connection attempts
# TYPE starweave_connection_attempts_total counter
starweave_connection_attempts_total 42

# HELP starweave_messages_sent_total Total messages sent
# TYPE starweave_messages_sent_total counter
starweave_messages_sent_total{type="quantum"} 100
starweave_messages_sent_total{type="neural"} 150

# HELP starweave_message_duration_seconds Message processing duration
# TYPE starweave_message_duration_seconds histogram
starweave_message_duration_seconds_bucket{type="quantum",le="0.1"} 50
starweave_message_duration_seconds_bucket{type="quantum",le="0.25"} 75
```

### Tracing

Distributed tracing is supported through OpenTelemetry:

```zig
const tracer = std.telemetry.tracer("starweave-client");

// Create a new span
const span = tracer.startSpan("process_quantum_state");
defer span.end();

// Add attributes
span.setAttribute("qubit_count", qubit_count);
span.setAttribute("amplitude", amplitude);

// Add events
span.addEvent("state_prepared", .{ .timestamp = std.time.nanoTimestamp() });
```

## Advanced Topics

### Custom Message Handlers

```zig
fn handleQuantumState(state: *const QuantumState, userdata: ?*anyopaque) !void {
    const context = @ptrCast(*Context, @alignCast(@alignOf(Context), userdata.?));
    // Process quantum state...
}

// Register handler
client.setQuantumStateHandler(handleQuantumState, &context);
```

### Connection Pooling

```zig
const pool_config = PoolConfig{
    .max_connections = 10,
    .min_connections = 2,
    .max_idle_time = 300_000,  // 5 minutes
    .validation_interval = 60_000,  // 1 minute
};

var pool = try ConnectionPool.init(allocator, config, pool_config);
defer pool.deinit();

// Get a connection from the pool
var conn = try pool.acquire();
defer pool.release(conn);

// Use the connection
try conn.sendQuantumState("channel", state);
```

### Message Batching

```zig
// Create a batch of messages
var batch = try MessageBatch.init(allocator, 100);
defer batch.deinit();

// Add messages to batch
for (0..100) |i| {
    const state = try createQuantumState(i);
    try batch.add(.{ .quantum = state });
}

// Send entire batch
try client.sendBatch(batch);
```

## Performance Tuning

### Buffer Sizes

```zig
.buffers = .{
    .read = 64 * 1024,  // 64KB
    .write = 64 * 1024, // 64KB
    .max_frame_size = 16 * 1024 * 1024,  // 16MB
},
```

### Thread Pool

```zig
.thread_pool = .{
    .min_threads = 4,
    .max_threads = 16,
    .idle_timeout = 60_000,  // 1 minute
    .stack_size = 2 * 1024 * 1024,  // 2MB
},
```

## Security Considerations

### Certificate Pinning

```zig
.tls = .{
    .enabled = true,
    .verify_cert = true,
    .pinned_cert_hashes = &.{
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    },
},
```

### Rate Limiting

```zig
.rate_limiting = .{
    .enabled = true,
    .requests_per_second = 1000,
    .burst_size = 100,
},
```

## Troubleshooting

### Common Issues

1. **Connection Timeouts**
   - Verify network connectivity
   - Check firewall settings
   - Increase timeout values

2. **TLS Handshake Failures**
   - Verify certificate chain
   - Check TLS version compatibility
   - Ensure system clock is accurate

3. **Memory Leaks**
   - Use Zig's built-in memory leak detection
   - Check for missing `defer` statements
   - Monitor memory usage with `std.heap.GeneralPurposeAllocator`

### Debugging

Enable debug logging:

```zig
.logging = .{
    .level = .debug,
    .format = .text,
    .destination = .stderr,
},
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `zig build test`
5. Submit a pull request

## License

MIT License - See [LICENSE](LICENSE) for details.
        .header = "X-API-Key",
        .prefix = "ApiKey ",
    },
},
```

## Metrics

The client exposes various metrics that can be collected and exported:

```zig
// Initialize metrics registry
var registry = try starweave.metrics.Registry.init(allocator);
defer registry.deinit();

// Create a collector for Prometheus
var collector = try starweave.metrics.PrometheusCollector.init(allocator, registry);

// Start HTTP server to expose metrics
var server = try std.http.Server.init(allocator, .{ .reuse_address = true });
try server.listen(try std.net.Address.parseIp("0.0.0.0", 8080));

defer server.deinit();

while (true) {
    var response = try server.accept(.{ .allocator = allocator });
    defer response.deinit();
    
    try response.headers.append("Content-Type", "text/plain; version=0.0.4");
    try response.do();
    
    if (std.mem.eql(u8, response.request.target, "/metrics")) {
        try response.writer().print("{s}", .{try collector.export()});
    }
    
    try response.finish();
}
```

## Testing

Run the test suite:

```bash
zig test src/starweave/client_test.zig
```

## License

This project is licensed under the [License Name] - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) for details.

## Support

For support, please open an issue in the [issue tracker](https://github.com/your-org/maya/issues).
