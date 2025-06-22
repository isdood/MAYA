// src/starweave/protocol.zig

//! # 🌌 STARWEAVE Protocol
//!
//! The neural fabric that weaves together the GLIMMER ecosystem, enabling seamless communication
//! between DREAMWEAVE components, Crystal Matrix nodes, and the Quantum Bridge.
//!
//! ## Core Principles
//! - **Bi-directional Flow**: Messages can flow in any direction, with built-in support for
//!   forward, backward, and bidirectional communication patterns.
//! - **Self-Healing**: Automatic error detection and recovery mechanisms.
//! - **Quantum-Resilient**: Designed with post-quantum cryptography in mind.
//!
//! ## Integration with GLIMMER
//! - Extends DREAMWEAVE's flow patterns to network communication
//! - Powers the Crystal Matrix's distributed computation
//! - Enables Quantum Bridge's cross-paradigm operations

const std = @import("std");
const builtin = @import("builtin");

/// Core message types for the STARWEAVE protocol
/// Aligns with DREAMWEAVE's flow patterns and GLIMMER's architecture
pub const MessageType = enum(u8) {
    // Control messages (0x00-0x0F)
    handshake = 0x01,    // Initial connection handshake
    ping = 0x02,         // Connection keep-alive
    pong = 0x03,         // Response to ping
    flow_control = 0x04, // Flow control commands
    
    // Data messages (0x10-0x2F)
    data = 0x10,         // Generic data payload
    stream_start = 0x11, // Start of a data stream
    stream_chunk = 0x12, // Chunk of stream data
    stream_end = 0x13,   // End of stream marker
    
    // Quantum operations (0x30-0x4F)
    quantum_compute = 0x30,  // Quantum circuit execution
    quantum_result = 0x31,   // Result from quantum computation
    quantum_error = 0x3F,    // Quantum-specific errors
    
    // Matrix operations (0x50-0x6F)
    matrix_op = 0x50,    // Crystal Matrix operation
    matrix_result = 0x51, // Result from matrix operation
    
    // Error messages (0xF0-0xFF)
    error_message = 0xFF,        // Generic error
};

/// Protocol error set with GLIMMER-specific variants
pub const ProtocolError = error {
    // Connection errors
    ConnectionClosed,
    Timeout,
    ConnectionRefused,
    
    // Protocol errors
    InvalidMessage,
    InvalidHandshake,
    InvalidChecksum,
    InvalidSignature,
    VersionMismatch,
    
    // Resource errors
    BufferTooSmall,
    MemoryAllocationFailed,
    ResourceExhausted,
    
    // Quantum-specific errors
    QubitAllocationFailed,
    QuantumDecoherence,
    GateNotSupported,
    
    // Matrix operation errors
    MatrixDimensionMismatch,
    SingularMatrix,
    ConvergenceFailed,
    
    // Other errors
    NotImplemented,
    MessageTooLarge,
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

    pub fn calculateChecksum(data: []const u8) u32 {
        // Simple checksum for now, can be replaced with a more robust one
        var sum: u32 = 0;
        for (data) |byte| {
            sum +%= byte;
        }
        return sum;
    }

    pub fn validate(self: MessageHeader, data: []const u8) bool {
        return self.checksum == calculateChecksum(data);
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

/// Message wrapper with support for GLIMMER operations
pub const Message = union(MessageType) {
    // Control messages
    handshake: Handshake,
    ping: void,
    pong: void,
    flow_control: struct {
        window_size: u32,
        rate_limit: u32,
    },
    
    // Data messages
    data: []const u8,
    stream_start: struct { 
        id: u64, 
        name: []const u8,
        content_type: []const u8 = "application/octet-stream",
    },
    stream_chunk: struct { 
        id: u64, 
        data: []const u8,
        sequence: u64,
    },
    stream_end: struct { 
        id: u64, 
        success: bool,
        metadata: ?[]const u8 = null,
    },
    
    // GLIMMER-specific messages
    quantum_compute: struct {
        circuit: []const u8,  // Quantum circuit in OpenQASM format
        qubits: u16,         // Number of qubits required
        shots: u32,          // Number of measurement shots
        options: ?[]const u8 = null, // JSON string with additional options
    },
    
    quantum_result: struct {
        measurements: []const u8, // Measurement results
        probabilities: []const f64, // Measurement probabilities
        execution_time: u64,     // Execution time in nanoseconds
    },
    
    matrix_op: struct {
        operation: enum { multiply, add, eigen, svd },
        matrices: []const []const f64, // Flattened matrices
        dimensions: []const usize,     // Dimensions of each matrix
    },
    
    matrix_result: struct {
        result: []const f64,    // Flattened result matrix
        dimensions: []const usize,
    },
    
    // Error message with additional context
    error_message: struct {
        code: u32,
        message: []const u8,
        details: ?[]const u8 = null,
    },

    /// Create a new message from raw bytes
    pub fn fromBytes(data: []const u8) !Message {
        if (data.len < @sizeOf(MessageHeader)) {
            return error.InvalidMessage;
        }

        const header: *const MessageHeader = @ptrCast(data.ptr);
        if (!header.validate(data[@sizeOf(MessageHeader)..])) {
            return error.InvalidChecksum;
        }

        // TODO: Parse message body based on header.msg_type
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
        
        const header: *MessageHeader = @ptrCast(self.buffer.ptr);
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

/// Main Protocol type that provides the public API for the STARWEAVE protocol
pub const Protocol = struct {
    /// Initialize the protocol
    pub fn init() !void {
        // Initialize any protocol resources here
        return;
    }

    /// Create a new connection with the given stream and buffer
    pub fn createConnection(stream: std.net.Stream, buffer: []u8) Connection {
        return Connection.init(stream, buffer);
    }
};

// Tests for the protocol
const testing = std.testing;

test "GLIMMER protocol integration" {
    // Test quantum computation message
    _ = Message{
        .quantum_compute = .{
            .circuit = "H 0\nCNOT 0 1\nMEASURE 0 [0]",
            .qubits = 2,
            .shots = 1000,
        }
    };
    
    // Test matrix operation
    _ = Message{
        .matrix_op = .{
            .operation = .multiply,
            .matrices = &[_][]const f64 {
                &[_]f64{1, 2, 3, 4}, // First matrix
                &[_]f64{5, 6, 7, 8}, // Second matrix
            },
            .dimensions = &[_]usize{2, 2, 2, 2}, // 2x2 * 2x2
        }
    };
    
    // Test error handling
    _ = Message{
        .error_message = .{
            .code = 42,
            .message = "Quantum decoherence detected",
            .details = "Qubit 3 lost coherence after 42ns",
        }
    };
    
    // Basic protocol tests
    const node_id = [_]u8{0} ** 32;
    const handshake = Handshake.init(&node_id);
    try testing.expect(handshake.version == VERSION);
    
    var header = MessageHeader.init(.ping, 0);
    try testing.expect(header.validate(""));
}

test "message serialization roundtrip" {
    // TODO: Implement comprehensive serialization/deserialization tests
    // This will test that messages can be serialized and deserialized correctly
}