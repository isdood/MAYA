const std = @import("std");
const net = std.net;
const os = std.os;
const mem = std.mem;
const json = std.json;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const AutoHashMap = std.AutoHashMap;
const StringHashMap = std.StringHashMap;
const fmt = std.fmt;
const time = std.time;
const builtin = @import("builtin");

const protocol = @import("protocol.zig");
const Message = protocol.Message;
const MessageType = protocol.MessageType;
const ErrorCode = protocol.ErrorCode;

/// Configuration for the mock server
pub const MockServerConfig = struct {
    /// Port to listen on (0 for random port)
    port: u16 = 0,
    
    /// Host to bind to
    host: []const u8 = "127.0.0.1",
    
    /// Enable TLS
    tls: bool = false,
    
    /// Path to TLS certificate file (PEM format)
    tls_cert_path: ?[]const u8 = null,
    
    /// Path to TLS private key file (PEM format)
    tls_key_path: ?[]const u8 = null,
    
    /// Authentication token (if required)
    auth_token: ?[]const u8 = null,
    
    /// Maximum number of concurrent connections
    max_connections: u32 = 100,
    
    /// Maximum message size in bytes
    max_message_size: usize = 1024 * 1024, // 1MB
};

/// A mock STARWEAVE server for testing
pub const MockServer = struct {
    const Self = @This();
    
    allocator: Allocator,
    config: MockServerConfig,
    server: net.StreamServer,
    address: net.Address,
    is_running: bool = false,
    stop_requested: bool = false,
    
    /// Message handler function type
    pub const MessageHandler = *const fn (
        self: *Self,
        conn: *Connection,
        message: *Message,
    ) anyerror!void;
    
    /// Connection state
    pub const Connection = struct {
        stream: net.Stream,
        remote_addr: net.Address,
        is_authenticated: bool = false,
        last_active: i64 = 0,
        
        pub fn init(stream: net.Stream, remote_addr: net.Address) Connection {
            return .{
                .stream = stream,
                .remote_addr = remote_addr,
                .last_active = std.time.timestamp(),
            };
        }
        
        pub fn deinit(self: *Connection) void {
            self.stream.close();
        }
        
        pub fn sendMessage(self: *Connection, message: *const Message) !void {
            var buffer = std.ArrayList(u8).init(std.heap.page_allocator);
            defer buffer.deinit();
            
            try message.serialize(buffer.writer());
            try self.stream.writer().writeAll(buffer.items);
        }
        
        pub fn sendError(
            self: *Connection,
            code: ErrorCode,
            message: []const u8,
        ) !void {
            const error_msg = Message{
                .message_type = .error,
                .error = .{
                    .code = code,
                    .message = message,
                },
            };
            
            try self.sendMessage(&error_msg);
        }
    };
    
    /// Initialize a new mock server
    pub fn init(
        allocator: Allocator,
        config: MockServerConfig,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);
        
        // Resolve the address
        const address = try net.Address.parseIp(config.host, config.port);
        
        // Initialize the server
        var server = net.StreamServer.init(.{
            .reuse_address = true,
            .kernel_backlog = config.max_connections,
        });
        
        self.* = .{
            .allocator = allocator,
            .config = config,
            .server = server,
            .address = address,
        };
        
        return self;
    }
    
    /// Deinitialize the mock server
    pub fn deinit(self: *Self) void {
        self.stop() catch {};
        self.server.deinit();
        self.allocator.destroy(self);
    }
    
    /// Start the mock server
    pub fn start(self: *Self) !void {
        if (self.is_running) return error.AlreadyRunning;
        
        // Bind to the address
        try self.server.listen(self.address);
        self.is_running = true;
        self.stop_requested = false;
        
        // Start accepting connections in a separate thread
        const thread = try Thread.spawn(.{}, handleConnections, .{self});
        thread.detach();
    }
    
    /// Stop the mock server
    pub fn stop(self: *Self) !void {
        if (!self.is_running) return;
        
        self.stop_requested = true;
        self.is_running = false;
        
        // Close the server socket to unblock accept()
        self.server.close();
    }
    
    /// Get the actual port the server is listening on
    pub fn getPort(self: *const Self) u16 {
        return self.server.listen_address.in.getPort();
    }
    
    /// Handle incoming connections
    fn handleConnections(self: *Self) !void {
        defer {
            self.server.close();
            self.is_running = false;
        }
        
        while (!self.stop_requested) {
            const conn = self.server.accept() catch |err| {
                if (self.stop_requested) break;
                std.log.err("Failed to accept connection: {}", .{err});
                continue;
            };
            
            // Handle each connection in a separate thread
            const handle = try std.heap.page_allocator.create(Connection);
            handle.* = Connection.init(conn.stream, conn.address);
            
            const thread = try Thread.spawn(.{}, handleConnection, .{ self, handle });
            thread.detach();
        }
    }
    
    /// Handle a single connection
    fn handleConnection(self: *Self, conn: *Connection) void {
        defer {
            conn.deinit();
            std.heap.page_allocator.destroy(conn);
        }
        
        const reader = conn.stream.reader();
        
        while (!self.stop_requested) {
            // Read message length (4 bytes, big-endian)
            const len_bytes = reader.readBytesNoEof(4) catch |err| {
                if (err != error.EndOfStream) {
                    std.log.err("Error reading message length: {}", .{err});
                }
                break;
            };
            
            const message_len = std.mem.readIntBig(u32, &len_bytes);
            if (message_len > self.config.max_message_size) {
                std.log.err("Message too large: {} bytes", .{message_len});
                conn.sendError(.message_too_large, "Message too large") catch {};
                break;
            }
            
            // Read message data
            var message_data = std.heap.page_allocator.alloc(u8, message_len) catch {
                std.log.err("Out of memory", .{});
                break;
            };
            defer std.heap.page_allocator.free(message_data);
            
            _ = reader.readAll(message_data) catch |err| {
                std.log.err("Error reading message data: {}", .{err});
                break;
            };
            
            // Parse the message
            var message = Message.deserialize(message_data) catch |err| {
                std.log.err("Error parsing message: {}", .{err});
                conn.sendError(.invalid_message, "Invalid message format") catch {};
                continue;
            };
            
            // Handle the message
            self.handleMessage(conn, &message) catch |err| {
                std.log.err("Error handling message: {}", .{err});
                conn.sendError(.internal_error, "Internal server error") catch {};
            };
        }
    }
    
    /// Handle a single message
    fn handleMessage(self: *Self, conn: *Connection, message: *Message) !void {
        conn.last_active = std.time.timestamp();
        
        // Check authentication if required
        if (self.config.auth_token != null and !conn.is_authenticated) {
            if (message.message_type != .auth) {
                try conn.sendError(.authentication_required, "Authentication required");
                return;
            }
            
            // Verify auth token
            if (message.auth.token != self.config.auth_token) {
                try conn.sendError(.authentication_failed, "Invalid authentication token");
                return;
            }
            
            conn.is_authenticated = true;
            
            // Send auth success response
            const response = Message{
                .message_type = .auth_response,
                .auth_response = .{
                    .success = true,
                    .message = "Authentication successful",
                },
            };
            
            try conn.sendMessage(&response);
            return;
        }
        
        // Handle different message types
        switch (message.message_type) {
            .auth => {
                // Already handled above
                unreachable;
            },
            .ping => {
                const pong = Message{
                    .message_type = .pong,
                    .pong = .{
                        .timestamp = message.ping.timestamp,
                    },
                };
                
                try conn.sendMessage(&pong);
            },
            .pong => {
                // Ignore pong messages
            },
            .error => {
                std.log.warn("Received error from client: {s}", .{message.error.message});
            },
            else => {
                // Echo back the message for testing
                try conn.sendMessage(message);
            },
        }
    }
};

/// Test the mock server
const testing = std.testing;

test "mock server basic functionality" {
    const allocator = testing.allocator;
    
    // Create and start the server
    var server = try MockServer.init(allocator, .{
        .port = 0, // Random port
        .host = "127.0.0.1",
    });
    defer server.deinit();
    
    try server.start();
    defer server.stop() catch {};
    
    // Connect to the server
    const client = try net.tcpConnectToAddress(server.server.listen_address);
    defer client.close();
    
    // Send a ping message
    const ping = Message{
        .message_type = .ping,
        .ping = .{
            .timestamp = std.time.milliTimestamp(),
        },
    };
    
    // Serialize and send the message
    var send_buffer = std.ArrayList(u8).init(allocator);
    defer send_buffer.deinit();
    
    try ping.serialize(send_buffer.writer());
    try client.writeAll(send_buffer.items);
    
    // Read the response
    var len_buf: [4]u8 = undefined;
    _ = try client.readAll(&len_buf);
    const msg_len = std.mem.readIntBig(u32, &len_buf);
    
    var msg_buf = try allocator.alloc(u8, msg_len);
    defer allocator.free(msg_buf);
    _ = try client.readAll(msg_buf);
    
    // Deserialize the response
    const pong = try Message.deserialize(msg_buf);
    try testing.expectEqual(MessageType.pong, pong.message_type);
    try testing.expectEqual(ping.ping.timestamp, pong.pong.timestamp);
}
