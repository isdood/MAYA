
const std = @import("std");
const net = std.net;
const json = std.json;
const time = std.time;
const crypto = std.crypto;
const base64 = std.base64;
const Allocator = std.mem.Allocator;

const Pattern = @import("../glm/pattern.zig").Pattern;
const AuthManager = @import("auth.zig").AuthManager;
const MessageQueue = @import("queue.zig").MessageQueue;
const RetryConfig = @import("retry.zig").RetryConfig;
const withRetry = @import("retry.zig").withRetry;
const TlsConfig = @import("tls.zig").TlsConfig;
const TlsStream = @import("tls.zig").TlsStream;
const CompressionAlgorithm = @import("compression.zig").CompressionAlgorithm;
const CompressionLevel = @import("compression.zig").CompressionLevel;
const CompressionStream = @import("compression.zig").CompressionStream;
const DecompressionStream = @import("compression.zig").DecompressionStream;

const default_retry_config = RetryConfig{
    .max_attempts = 3,
    .initial_delay_ns = 100 * time.ns_per_ms,
    .max_delay_ns = 5 * time.ns_per_s,
    .backoff_factor = 2.0,
    .jitter_factor = 0.2,
    .timeout_ns = 10 * time.ns_per_s,
};

const Message = struct {
    id: u64,
    data: []const u8,
    callback: ?*const fn(bool, []const u8) void,
    retries: u32 = 0,
    timestamp: i64,
};

const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    authenticating,
    ready,
    disconnecting,
    errored,  // Changed from 'error' to 'errored' to avoid keyword conflict
};

pub const StarweaveClient = struct {
    allocator: Allocator,
    host: []const u8,
    port: u16,
    auth: ?AuthManager,
    state: ConnectionState = .disconnected,
    
    // Connection
    stream: union(enum) {
        plain: net.Stream,
        tls: *TlsStream,
    },
    reader: union(enum) {
        plain: net.Stream.Reader,
        decompress: *DecompressionStream,
    },
    writer: union(enum) {
        plain: net.Stream.Writer,
        compress: *CompressionStream,
    },
    tls_config: ?TlsConfig = null,
    compression: struct {
        algorithm: CompressionAlgorithm = .none,
        level: CompressionLevel = .default,
    } = .{},
    is_connected: bool = false,
    
    // Message handling
    message_queue: MessageQueue(Message),
    next_message_id: std.atomic.Atomic(u64) = std.atomic.Atomic(u64).init(1),
    
    // Threading
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    worker_thread: ?std.Thread = null,
    should_stop: bool = false,
    
    // Callbacks
    on_connect: ?*const fn(*StarweaveClient) void = null,
    on_disconnect: ?*const fn(*StarweaveClient) void = null,
    on_error: ?*const fn(*StarweaveClient, anyerror) void = null,
    
    pub const Config = struct {
        host: []const u8,
        port: u16,
        auth_token: ?[]const u8 = null,
        queue_capacity: usize = 1000,
        
        // TLS configuration
        tls: ?struct {
            ca_cert_path: ?[]const u8 = null,
            client_cert_path: ?[]const u8 = null,
            client_key_path: ?[]const u8 = null,
            verify_certificate: bool = true,
            verify_hostname: bool = true,
        } = null,
        
        // Compression configuration
        compression: struct {
            algorithm: CompressionAlgorithm = .none,
            level: CompressionLevel = .default,
        } = .{},
        
        // Callbacks
        on_connect: ?*const fn(*StarweaveClient) void = null,
        on_disconnect: ?*const fn(*StarweaveClient) void = null,
        on_error: ?*const fn(*StarweaveClient, anyerror) void = null,
    };
    
    pub fn init(allocator: Allocator, config: Config) !*StarweaveClient {
        const self = try allocator.create(StarweaveClient);
        
        self.* = .{
            .allocator = allocator,
            .host = try allocator.dupe(u8, config.host),
            .port = config.port,
            .auth = if (config.auth_token) |token| 
                AuthManager.init(allocator, .{ .token = token }) 
            else null,
            .message_queue = try MessageQueue(Message).init(allocator, config.queue_capacity),
            .on_connect = config.on_connect,
            .on_disconnect = config.on_disconnect,
            .on_error = config.on_error,
            // Initialize with placeholder values that will be replaced in connect()
            .stream = undefined,
            .reader = undefined,
            .writer = undefined,
        };
        
        // Set up TLS configuration if enabled
        if (config.tls) |tls_config| {
            self.tls_config = .{
                .ca_cert_path = if (tls_config.ca_cert_path) |path| 
                    try allocator.dupe(u8, path) else null,
                .client_cert_path = if (tls_config.client_cert_path) |path| 
                    try allocator.dupe(u8, path) else null,
                .client_key_path = if (tls_config.client_key_path) |path| 
                    try allocator.dupe(u8, path) else null,
                .verify_certificate = tls_config.verify_certificate,
                .verify_hostname = tls_config.verify_hostname,
            };
        }
        
        // Set up compression
        self.compression = .{
            .algorithm = config.compression.algorithm,
            .level = config.compression.level,
        };
        
        return self;
    }
    
    pub fn deinit(self: *StarweaveClient) void {
        self.disconnect();
        
        // Stop worker thread if running
        if (self.worker_thread) |*thread| {
            self.should_stop = true;
            self.cond.signal();
            thread.join();
            self.worker_thread = null;
        }
        
        // Clean up resources
        if (self.auth) |*auth| {
            auth.deinit();
        }
        
        self.allocator.free(self.host);
        self.message_queue.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn connect(self: *StarweaveClient) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.state != .disconnected) {
            return error.AlreadyConnected;
        }
        
        self.state = .connecting;
        
        // Start worker thread if not already running
        if (self.worker_thread == null) {
            self.should_stop = false;
            self.worker_thread = try std.Thread.spawn(.{}, workerThread, .{self});
        }
        
        // Signal worker to start connection
        self.cond.signal();
    }
    
    pub fn disconnect(self: *StarweaveClient) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.state == .disconnected or self.state == .disconnecting) {
            return;
        }
        
        self.state = .disconnecting;
        self.is_connected = false;
        
        // Clean up compression streams
        switch (self.writer) {
            .compress => |*c| {
                c.deinit();
                self.allocator.destroy(c);
            },
            .plain => {},
        }
        
        switch (self.reader) {
            .decompress => |*d| {
                d.deinit();
                self.allocator.destroy(d);
            },
            .plain => {},
        }
        
        // Close the connection
        switch (self.stream) {
            .tls => |*tls| {
                tls.close();
                self.allocator.destroy(tls);
            },
            .plain => |stream| {
                stream.close();
            },
        }
        
        // Clean up TLS config
        if (self.tls_config) |*tls_config| {
            if (tls_config.ca_cert_path) |path| self.allocator.free(path);
            if (tls_config.client_cert_path) |path| self.allocator.free(path);
            if (tls_config.client_key_path) |path| self.allocator.free(path);
        }
        
        self.state = .disconnected;
        
        // Notify listeners
        if (self.on_disconnect) |callback| {
            callback(self);
        }
    }
    
    pub fn sendPattern(self: *StarweaveClient, pattern: *const Pattern) !void {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        try pattern.toJson(buffer.writer());
        
        const message = Message{
            .id = self.next_message_id.fetchAdd(1, .SeqCst),
            .data = try self.allocator.dupe(u8, buffer.items),
            .callback = null,
            .timestamp = std.time.timestamp(),
        };
        
        defer self.allocator.free(message.data);
        
        try self.message_queue.enqueue(message);
    }
    
    pub fn sendPatternWithCallback(
        self: *StarweaveClient,
        pattern: *const Pattern,
        callback: *const fn(bool, []const u8) void,
    ) !void {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        try pattern.toJson(buffer.writer());
        
        const message = Message{
            .id = self.next_message_id.fetchAdd(1, .SeqCst),
            .data = try self.allocator.dupe(u8, buffer.items),
            .callback = callback,
            .timestamp = std.time.timestamp(),
        };
        
        defer self.allocator.free(message.data);
        
        try self.message_queue.enqueue(message);
    }
    
    fn workerThread(self: *StarweaveClient) void {
        while (!self.should_stop) {
            self.mutex.lock();
            
            // Wait for connection request or shutdown
            while (!self.should_stop and self.state != .connecting) {
                self.cond.wait(&self.mutex);
            }
            
            if (self.should_stop) {
                self.mutex.unlock();
                break;
            }
            
            // Connect to server
            self.connectInternal() catch |err| {
                if (self.on_error) |callback| {
                    callback(self, err);
                }
                self.state = .errored;
                self.mutex.unlock();
                std.time.sleep(1 * time.ns_per_s); // Backoff before retry
                continue;
            };
            
            self.mutex.unlock();
            
            // Process messages
            self.processMessages() catch |err| {
                if (self.on_error) {
                    self.on_error.?(self, err);
                }
            };
        }
    }
    
    fn connectInternal(self: *StarweaveClient) !void {
        self.state = .connecting;
        
        // Resolve address and connect
        const addr = try net.Address.resolveIp(self.host, self.port);
        const tcp_stream = try net.tcpConnectToAddress(addr);
        
        // Set up TLS if configured
        if (self.tls_config) |tls_config| {
            var tls_stream = try self.allocator.create(TlsStream);
            tls_stream.* = try TlsStream.initTlsClient(
                self.allocator,
                tcp_stream,
                self.host,
                tls_config,
            );
            self.stream = .{ .tls = tls_stream };
            
            // Set up reader/writer with TLS
            self.reader = .{ .plain = tls_stream.reader() };
            self.writer = .{ .plain = tls_stream.writer() };
        } else {
            // No TLS, use plain TCP
            self.stream = .{ .plain = tcp_stream };
            self.reader = .{ .plain = tcp_stream.reader() };
            self.writer = .{ .plain = tcp_stream.writer() };
        }
        
        // Set up compression if enabled
        if (self.compression.algorithm != .none) {
            const compress = try self.allocator.create(CompressionStream);
            compress.* = try CompressionStream.initCompressor(
                self.allocator,
                self.compression.algorithm,
                self.compression.level,
                switch (self.writer) {
                    .plain => |w| w,
                    .compress => unreachable, // Shouldn't happen
                },
            );
            self.writer = .{ .compress = compress };
            
            const decompress = try self.allocator.create(DecompressionStream);
            decompress.* = try DecompressionStream.initDecompressor(
                self.allocator,
                self.compression.algorithm,
                switch (self.reader) {
                    .plain => |r| r,
                    .decompress => unreachable, // Shouldn't happen
                },
            );
            self.reader = .{ .decompress = decompress };
        }
        
        // Authenticate if needed
        if (self.auth) |*auth| {
            self.state = .authenticating;
            try self.authenticate(auth);
        }
        
        self.state = .connected;
        self.is_connected = true;
        
        // Notify listeners
        if (self.on_connect) |callback| {
            callback(self);
        }
    }
    
    fn authenticate(self: *StarweaveClient, auth: *AuthManager) !void {
        const auth_header = try auth.getAuthHeader();
        defer self.allocator.free(auth_header);
        
        // Send authentication message
        const auth_msg = try std.fmt.allocPrint(
            self.allocator,
            "AUTH {s}\r\n",
            .{auth_header},
        );
        defer self.allocator.free(auth_msg);
        
        _ = try self.writer.?.writeAll(auth_msg);
        
        // Read response
        var response: [1024]u8 = undefined;
        const len = try self.reader.?.read(&response);
        
        if (len < 3 or !std.mem.eql(u8, response[0..3], "OK ")) {
            return error.AuthenticationFailed;
        }
    }
    
    fn processMessages(self: *StarweaveClient) !void {
        while (self.state == .connected and !self.should_stop) {
            // Get next message with timeout
            const message = self.message_queue.tryDequeue() orelse {
                // Small sleep to prevent busy waiting
                std.time.sleep(10 * time.ns_per_ms);
                continue;
            };
            
            // Send message with retry
            const result = withRetry(
                @TypeOf(sendMessage),
                default_retry_config,
                .{ self, message },
                sendMessage,
            );
            
            // Handle result
            if (result) |_| {
                if (message.callback) |callback| {
                    callback(true, "Message sent successfully");
                }
            } else |err| {
                if (message.callback) |callback| {
                    const err_msg = std.fmt.allocPrint(
                        self.allocator,
                        "Failed to send message: {}",
                        .{err},
                    ) catch "Unknown error";
                    
                    callback(false, err_msg);
                    
                    if (self.allocator.free(err_msg)) {
                        // Handle potential error if needed
                    }
                }
                
                // Disconnect on error to trigger reconnection
                self.disconnect();
                return;
            }
        }
    }
    
    fn sendMessage(ctx: struct {
        self: *StarweaveClient,
        message: Message,
    }) !void {
        const writer = switch (ctx.self.writer) {
            .plain => |w| w,
            .compress => |c| c.writer(),
        };
        
        _ = try writer.writeAll(ctx.message.data);
        _ = try writer.writeAll("\r\n");
        
        // If using compression, flush the stream
        if (ctx.self.writer == .compress) {
            try ctx.self.writer.compress.finish();
        }
        
        // Read acknowledgment
        var ack_buf: [1024]u8 = undefined;
        const reader = switch (ctx.self.reader) {
            .plain => |r| r,
            .decompress => |d| d.reader(),
        };
        
        const len = try reader.read(&ack_buf);
        
        if (len < 3 or !std.mem.eql(u8, ack_buf[0..3], "OK ")) {
            return error.AckFailed;
        }
    }
};

test "starweave client initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const config = StarweaveClient.Config{
        .host = "localhost",
        .port = 4242,
        .auth_token = "test_token",
    };
    
    var client = try StarweaveClient.init(arena.allocator(), config);
    defer client.deinit();
    
    try std.testing.expectEqual(.disconnected, client.state);
}

test "message queue functionality" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const config = StarweaveClient.Config{
        .host = "localhost",
        .port = 4242,
    };
    
    var client = try StarweaveClient.init(arena.allocator(), config);
    defer client.deinit();
    
    // Test message queue
    const message = Message{
        .id = 1,
        .data = "test",
        .callback = null,
        .timestamp = std.time.timestamp(),
    };
    
    try client.message_queue.enqueue(message);
    const dequeued = try client.message_queue.dequeue();
    
    try std.testing.expectEqual(message.id, dequeued.id);
    try std.testing.expectEqualStrings(message.data, dequeued.data);
}

// Note: Integration tests requiring actual server connection would be in a separate test file
// that's only run when explicitly requested, as it requires a running STARWEAVE server
