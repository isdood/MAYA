# STARWEAVE Client Implementation

A high-performance, feature-rich client implementation for the STARWEAVE protocol, designed for secure and efficient pattern transmission and processing within the MAYA ecosystem.

## Features

- **Secure Communication**
  - TLS 1.2/1.3 support with certificate verification
  - Multiple authentication methods (Token, JWT, OAuth2, HMAC, API Key)
  - Automatic token refresh

- **Reliability**
  - Automatic reconnection with exponential backoff
  - Configurable retry policies
  - Connection state management
  - Message queuing with flow control

- **Performance**
  - Zero-copy message processing
  - Compression support (gzip, deflate, zstd)
  - Connection pooling
  - Batch message processing

- **Observability**
  - Comprehensive metrics collection
  - Structured logging
  - Performance monitoring
  - Health checks

- **Extensibility**
  - Pluggable authentication providers
  - Custom message handlers
  - Middleware support
  - Event-driven architecture

## Getting Started

### Prerequisites

- Zig 0.11.0 or later
- MAYA project dependencies

### Installation

Add this as a dependency in your `build.zig`:

```zig
exe.addModule("starweave", b.createModule(.{
    .source_file = .{ .path = "src/starweave/client.zig" },
}));
```

### Basic Usage

```zig
const std = @import("std");
const starweave = @import("starweave");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize client
    var client = try starweave.Client.init(allocator, .{
        .host = "api.starweave.example",
        .port = 443,
        .auth_token = "your-auth-token",
        .tls = .{
            .enabled = true,
            .verify_cert = true,
        },
    });
    defer client.deinit();

    // Connect to server
    try client.connect();
    defer client.disconnect();

    // Send a message
    const message = try starweave.Message.init(.{
        .type = .custom,
        .data = .{ .custom = .{
            .type = "test.message",
            .data = "Hello, World!",
        }},
    });
    defer message.deinit(allocator);

    try client.sendMessage(&message);

    // Receive response
    const response = try client.receiveMessage();
    defer response.deinit(allocator);

    // Process response
    std.debug.print("Received: {s}\n", .{response.data.custom.data});
}
```

## Configuration

The client can be configured using the `Config` struct:

```zig
const config = starweave.Config{
    .host = "api.starweave.example",
    .port = 443,
    .auth = .{
        .token = .{
            .token = "your-token",
            .token_type = "Bearer",
        },
    },
    .tls = .{
        .enabled = true,
        .ca_cert_path = "/path/to/ca.crt",
        .client_cert_path = "/path/to/client.crt",
        .client_key_path = "/path/to/client.key",
    },
    .compression = .{
        .enabled = true,
        .algorithm = .gzip,
        .level = 6,
    },
    .timeouts = .{
        .connect = 5_000, // 5 seconds
        .read = 10_000,  // 10 seconds
        .write = 10_000, // 10 seconds
    },
    .retry = .{
        .max_attempts = 3,
        .initial_delay = 100, // 100ms
        .max_delay = 5_000,   // 5 seconds
    },
    .metrics = .{
        .enabled = true,
        .prefix = "starweave_",
    },
};
```

## Authentication

The client supports multiple authentication methods:

### Token Authentication

```zig
.auth = .{
    .token = .{
        .token = "your-token",
        .token_type = "Bearer",
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
    },
},
```

### HMAC Authentication

```zig
.auth = .{
    .hmac = .{
        .key_id = "your-key-id",
        .secret_key = "your-secret-key",
        .algorithm = .sha256,
    },
},
```

### API Key Authentication

```zig
.auth = .{
    .api_key = .{
        .key = "your-api-key",
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
