// src/starweave/protocol.zig
const std = @import("std");
const builtin = @import("builtin");

/// Core message types for Starweave protocol
pub const MessageType = enum(u8) {
    // Control messages
    handshake = 0x01,
    ping = 0x02,
    pong = 0x03,
    
    // Data messages
    data = 0x10,
    stream_start = 0x11,
    stream_chunk = 0x12,
    stream_end = 0x13,
    
    // Error messages
    error = 0xFF,
};

/// Protocol error set
pub const ProtocolError = error {
    InvalidMessage,
    ConnectionClosed,
    Timeout,
    InvalidHandshake,
    BufferTooSmall,
    InvalidChecksum,
};

/// Protocol version
pub const VERSION = 1;

/// Maximum message size (1MB)
pub const MAX_MESSAGE_SIZE = 1024 * 1024;

/// Message header structure
pub const MessageHeader = packed struct {
    msg_type: MessageType,
    flags: u8,
    length: u16,
    checksum: u32,

    pub fn init(msg_type: MessageType, length: usize) MessageHeader {
        return .{
            .msg_type = msg_type,
            .flags = 0,
            .length = @truncate(length),
            .checksum = 0, // Will be calculated later
        };
    }

    pub fn calculateChecksum(self: *MessageHeader, data: []const u8) u32 {
        // Simple checksum for now, can be replaced with a more robust one
        var sum: u32 = 0;
        for (data) |byte| {
            sum +%= byte;
        }
        return sum;
    }

    pub fn validate(self: MessageHeader, data: []const u8) bool {
        return self.checksum == self.calculateChecksum(data);
    }
};

/// Handshake message
pub const Handshake = struct {
    version: u8,
    node_id: [32]u8,
    capabilities: u64,

    pub fn init(node_id: [32]u8) Handshake {
        return .{
            .version = VERSION,
            .node_id = node_id,
            .capabilities = 0, // Set capabilities as needed
        };
    }
};

/// Message wrapper
pub const Message = union(MessageType) {
    handshake: Handshake,
    ping: void,
    pong: void,
    data: []const u8,
    stream_start: struct { id: u64, name: []const u8 },
    stream_chunk: struct { id: u64, data: []const u8 },
    stream_end: struct { id: u64, success: bool },
    error: []const u8,

    /// Create a new message from raw bytes
    pub fn fromBytes(data: []const u8) !Message {
        if (data.len < @sizeOf(MessageHeader)) {
            return error.InvalidMessage;
        }

        const header = @ptrCast(*const MessageHeader, data.ptr);
        if (!header.validate(data[@sizeOf(MessageHeader)..])) {
            return error.InvalidChecksum;
        }

        // TODO: Parse message body based on header.msg_type
        _ = header; // Temporary to avoid unused variable warning
        return error.NotImplemented;
    }

    /// Convert message to bytes
    pub fn toBytes(self: Message, allocator: std.mem.Allocator) ![]const u8 {
        // TODO: Implement message serialization
        _ = self;
        _ = allocator;
        return error.NotImplemented;
    }
};

/// Connection abstraction for protocol communication
pub const Connection = struct {
    stream: std.net.Stream,
    buffer: []u8,
    pos: usize = 0,

    pub fn init(stream: std.net.Stream, buffer: []u8) Connection {
        return .{
            .stream = stream,
            .buffer = buffer,
        };
    }

    /// Read a complete message from the connection
    pub fn readMessage(self: *Connection) !Message {
        // Read header
        const header_size = @sizeOf(MessageHeader);
        try self.readExactly(self.buffer[0..header_size]);
        
        const header = @ptrCast(*MessageHeader, self.buffer.ptr);
        if (header.length > self.buffer.len - header_size) {
            return error.MessageTooLarge;
        }

        // Read message body
        const body_start = header_size;
        const body_end = body_start + header.length;
        try self.readExactly(self.buffer[body_start..body_end]);

        // Validate checksum
        if (!header.validate(self.buffer[body_start..body_end])) {
            return error.InvalidChecksum;
        }

        return Message.fromBytes(self.buffer[0..body_end]);
    }

    /// Write a message to the connection
    pub fn writeMessage(self: *Connection, message: Message) !void {
        const bytes = try message.toBytes(std.heap.page_allocator);
        defer std.heap.page_allocator.free(bytes);
        _ = try self.stream.write(bytes);
    }

    fn readExactly(self: *Connection, buf: []u8) !void {
        var total_read: usize = 0;
        while (total_read < buf.len) {
            const read = try self.stream.read(buf[total_read..]);
            if (read == 0) {
                return error.ConnectionClosed;
            }
            total_read += read;
        }
    }
};

// Simple test for the protocol
test "protocol basics" {
    const testing = std.testing;
    
    // Test header checksum
    var header = MessageHeader.init(.ping, 0);
    try testing.expect(header.validate(""));
    
    // Test handshake
    var node_id = [_]u8{0} ** 32;
    const handshake = Handshake.init(node_id);
    try testing.expect(handshake.version == VERSION);
}