@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 12:56:33",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/starweave/client_test.zig",
    "type": "zig",
    "hash": "b8fd4019fad8584b5bec219343b67509a3fc16d8"
  }
}
@pattern_meta@

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const net = std.net;
const time = std.time;
const Thread = std.Thread;
const Allocator = mem.Allocator;

const protocol = @import("protocol.zig");
const Message = protocol.Message;
const MessageType = protocol.MessageType;
const ErrorCode = protocol.ErrorCode;

const starweave_client = @import("client.zig");
const Client = starweave_client.StarweaveClient;
const ClientConfig = starweave_client.Config;
const ClientError = starweave_client.Error;

const mock = @import("mock_server.zig");
const MockServer = mock.MockServer;
const MockServerConfig = mock.MockServerConfig;

const metrics = @import("metrics.zig");
const Registry = metrics.Registry;

// Test configuration
const test_config = struct {
    const host = "127.0.0.1";
    const port: u16 = 0; // Random port
    const auth_token = "test-token-123";
};

// Initialize a test server
fn initTestServer(allocator: Allocator) !*MockServer {
    var server = try MockServer.init(allocator, .{
        .host = test_config.host,
        .port = test_config.port,
        .auth_token = test_config.auth_token,
    });
    
    try server.start();
    return server;
}

// Get a test client configuration
fn getTestClientConfig(port: u16) ClientConfig {
    return .{
        .host = test_config.host,
        .port = port,
        .auth_token = test_config.auth_token,
        .connect_timeout = 1000, // 1 second
        .request_timeout = 1000, // 1 second
        .max_retries = 3,
        .retry_delay = 100, // 100ms
        .enable_metrics = true,
    };
}

// Test basic client connection
test "client connection" {
    const allocator = testing.allocator;
    
    // Start the mock server
    var server = try initTestServer(allocator);
    defer server.deinit();
    
    // Create and connect the client
    var client = try Client.init(allocator, getTestClientConfig(server.getPort()));
    defer client.deinit();
    
    try client.connect();
    try testing.expect(client.isConnected());
    
    // Disconnect
    client.disconnect();
    try testing.expect(!client.isConnected());
}

// Test authentication
test "client authentication" {
    const allocator = testing.allocator;
    
    // Start the mock server with authentication
    var server = try initTestServer(allocator);
    defer server.deinit();
    
    // Create client with correct token
    var client = try Client.init(allocator, .{
        .host = test_config.host,
        .port = server.getPort(),
        .auth_token = test_config.auth_token,
    });
    defer client.deinit();
    
    // Should connect and authenticate successfully
    try client.connect();
    try testing.expect(client.isConnected());
    try testing.expect(client.isAuthenticated());
    
    // Disconnect
    client.disconnect();
    
    // Try with invalid token
    var bad_client = try Client.init(allocator, .{
        .host = test_config.host,
        .port = server.getPort(),
        .auth_token = "invalid-token",
    });
    defer bad_client.deinit();
    
    try testing.expectError(ClientError.AuthenticationFailed, bad_client.connect());
    try testing.expect(!bad_client.isConnected());
}

// Test message sending and receiving
test "message exchange" {
    const allocator = testing.allocator;
    
    // Start the mock server
    var server = try initTestServer(allocator);
    defer server.deinit();
    
    // Create and connect the client
    var client = try Client.init(allocator, getTestClientConfig(server.getPort()));
    defer client.deinit();
    
    try client.connect();
    
    // Create a test message
    const test_msg = Message{
        .message_type = .custom,
        .custom = .{
            .type = "test.message",
            .data = "Hello, World!",
        },
    };
    
    // Send the message
    try client.sendMessage(&test_msg);
    
    // Receive the echo response
    const response = try client.receiveMessage();
    defer response.deinit(allocator);
    
    // Verify the response
    try testing.expectEqual(MessageType.custom, response.message_type);
    try testing.expectEqualStrings("test.message", response.custom.type);
    try testing.expectEqualStrings("Hello, World!", response.custom.data);
}

// Test reconnection
test "client reconnection" {
    const allocator = testing.allocator;
    
    // Start the mock server
    var server = try initTestServer(allocator);
    defer server.deinit();
    
    // Create client with reconnection enabled
    var config = getTestClientConfig(server.getPort());
    config.reconnect = true;
    config.reconnect_interval = 100; // 100ms
    
    var client = try Client.init(allocator, config);
    defer client.deinit();
    
    // Connect and verify
    try client.connect();
    try testing.expect(client.isConnected());
    
    // Stop the server
    try server.stop();
    
    // Wait a bit for the client to detect the disconnection
    time.sleep(200 * time.ns_per_ms);
    
    // Restart the server
    try server.start();
    
    // Wait for reconnection
    time.sleep(500 * time.ns_per_ms);
    
    // Verify reconnection
    try testing.expect(client.isConnected());
    
    // Test message after reconnection
    const test_msg = Message{
        .message_type = .ping,
        .ping = .{ .timestamp = time.milliTimestamp() },
    };
    
    try client.sendMessage(&test_msg);
    const response = try client.receiveMessage();
    defer response.deinit(allocator);
    
    try testing.expectEqual(MessageType.pong, response.message_type);
}

// Test metrics collection
test "client metrics" {
    const allocator = testing.allocator;
    
    // Initialize metrics registry
    try metrics.initDefaultRegistry(allocator);
    const registry = try metrics.getDefaultRegistry();
    
    // Start the mock server
    var server = try initTestServer(allocator);
    defer server.deinit();
    
    // Create and connect the client with metrics enabled
    var config = getTestClientConfig(server.getPort());
    config.enable_metrics = true;
    
    var client = try Client.init(allocator, config);
    defer client.deinit();
    
    try client.connect();
    
    // Send some messages
    for (0..10) |i| {
        const msg = Message{
            .message_type = .custom,
            .custom = .{
                .type = "test.metric",
                .data = try std.fmt.allocPrint(allocator, "message-{}", .{i}),
            },
        };
        defer allocator.free(msg.custom.data);
        
        try client.sendMessage(&msg);
        _ = try client.receiveMessage();
    }
    
    // Verify metrics were collected
    const messages_sent = registry.getCounter("starweave_messages_sent_total") orelse {
        return error.MetricNotFound;
    };
    
    const messages_received = registry.getCounter("starweave_messages_received_total") orelse {
        return error.MetricNotFound;
    };
    
    try testing.expect(messages_sent.get() >= 10);
    try testing.expect(messages_received.get() >= 10);
    
    // Test histogram metrics
    const request_duration = registry.getHistogram("starweave_request_duration_seconds") orelse {
        return error.MetricNotFound;
    };
    
    try testing.expect(request_duration.getCount() >= 10);
}

// Test compression
test "message compression" {
    const allocator = testing.allocator;
    
    // Start the mock server
    var server = try initTestServer(allocator);
    defer server.deinit();
    
    // Create client with compression enabled
    var config = getTestClientConfig(server.getPort());
    config.enable_compression = true;
    config.compression_level = 6;
    
    var client = try Client.init(allocator, config);
    defer client.deinit();
    
    try client.connect();
    
    // Send a large message that would benefit from compression
    var large_data = std.ArrayList(u8).init(allocator);
    defer large_data.deinit();
    
    // Generate some repetitive data that compresses well
    for (0..1000) |i| {
        try large_data.writer().print("repetitive-data-{}-{}", .{ i, i * 2 });
    }
    
    const test_msg = Message{
        .message_type = .custom,
        .custom = .{
            .type = "test.compression",
            .data = large_data.items,
        },
    };
    
    // Send and receive the message
    try client.sendMessage(&test_msg);
    const response = try client.receiveMessage();
    defer response.deinit(allocator);
    
    // Verify the response
    try testing.expectEqual(MessageType.custom, response.message_type);
    try testing.expectEqualStrings("test.compression", response.custom.type);
    try testing.expectEqualStrings(test_msg.custom.data, response.custom.data);
}

// Test TLS connection
test "tls connection" {
    const allocator = testing.allocator;
    
    // Skip if TLS is not supported
    if (!@hasDecl(std.crypto.tls, "Client")) {
        return error.SkipZigTest;
    }
    
    // Start the mock server with TLS
    var server = try MockServer.init(allocator, .{
        .host = test_config.host,
        .port = test_config.port,
        .tls = true,
        .tls_cert_path = "testdata/cert.pem",
        .tls_key_path = "testdata/key.pem",
    });
    defer server.deinit();
    
    // Create client with TLS enabled
    var config = getTestClientConfig(server.getPort());
    config.tls = .{
        .enabled = true,
        .ca_cert_path = "testdata/ca.pem",
        .verify_cert = true,
    };
    
    var client = try Client.init(allocator, config);
    defer client.deinit();
    
    // Should connect successfully with TLS
    try client.connect();
    try testing.expect(client.isConnected());
    
    // Test message exchange
    const test_msg = Message{
        .message_type = .ping,
        .ping = .{ .timestamp = time.milliTimestamp() },
    };
    
    try client.sendMessage(&test_msg);
    const response = try client.receiveMessage();
    defer response.deinit(allocator);
    
    try testing.expectEqual(MessageType.pong, response.message_type);
}

// Test error handling
test "error handling" {
    const allocator = testing.allocator;
    
    // Start the mock server
    var server = try initTestServer(allocator);
    defer server.deinit();
    
    // Create client with short timeouts
    var config = getTestClientConfig(server.getPort());
    config.connect_timeout = 1; // 1ms - should timeout
    config.request_timeout = 1; // 1ms - should timeout
    
    var client = try Client.init(allocator, config);
    defer client.deinit();
    
    // Should fail to connect due to timeout
    try testing.expectError(ClientError.ConnectionTimeout, client.connect());
    
    // Reset timeouts for the rest of the test
    config.connect_timeout = 1000;
    config.request_timeout = 1000;
    
    // Connect successfully
    try client.connect();
    
    // Test message with invalid type
    const invalid_msg = Message{
        .message_type = @as(MessageType, @enumFromInt(9999)), // Invalid type
    };
    
    try testing.expectError(ClientError.InvalidMessage, client.sendMessage(&invalid_msg));
    
    // Test receive with timeout
    try testing.expectError(ClientError.ReceiveTimeout, client.receiveMessageTimeout(1)); // 1ms
}
