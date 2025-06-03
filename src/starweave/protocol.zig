const std = @import("std");

/// STARWEAVE protocol adapter for ecosystem integration
pub const StarweaveProtocol = struct {
    const Self = @This();

    /// Protocol message types
    pub const MessageType = enum {
        quantum_state,
        neural_pattern,
        visual_feedback,
        system_status,
    };

    /// Protocol message structure
    pub const Message = struct {
        msg_type: MessageType,
        payload: []const u8,
        timestamp: i64,
    };

    /// Protocol configuration
    pub const Config = struct {
        max_message_size: usize,
        timeout_ms: u32,
        retry_count: u32,
    };

    allocator: std.mem.Allocator,
    config: Config,
    message_queue: std.ArrayList(Message),

    pub fn init(allocator: std.mem.Allocator, config: Config) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .message_queue = std.ArrayList(Message).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.message_queue.items) |msg| {
            self.allocator.free(msg.payload);
        }
        self.message_queue.deinit();
    }

    /// Send a message through the STARWEAVE protocol
    pub fn sendMessage(self: *Self, msg_type: MessageType, payload: []const u8) !void {
        if (payload.len > self.config.max_message_size) {
            return error.PayloadTooLarge;
        }

        const timestamp = std.time.milliTimestamp();
        const message = Message{
            .msg_type = msg_type,
            .payload = try self.allocator.dupe(u8, payload),
            .timestamp = timestamp,
        };

        try self.message_queue.append(message);
    }

    /// Receive a message from the STARWEAVE protocol
    pub fn receiveMessage(self: *Self) !?Message {
        if (self.message_queue.items.len == 0) {
            return null;
        }

        const message = self.message_queue.orderedRemove(0);
        return message;
    }

    /// Process a quantum state message
    pub fn processQuantumState(self: *Self, state_data: []const u8) !void {
        try self.sendMessage(.quantum_state, state_data);
    }

    /// Process a neural pattern message
    pub fn processNeuralPattern(self: *Self, pattern_data: []const u8) !void {
        try self.sendMessage(.neural_pattern, pattern_data);
    }
};

test "Starweave Protocol" {
    const allocator = std.testing.allocator;
    const config = StarweaveProtocol.Config{
        .max_message_size = 1024,
        .timeout_ms = 1000,
        .retry_count = 3,
    };

    var protocol = try StarweaveProtocol.init(allocator, config);
    defer protocol.deinit();

    // Test message sending
    const test_payload = "test quantum state";
    try protocol.sendMessage(.quantum_state, test_payload);

    // Test message receiving
    const received = try protocol.receiveMessage();
    try std.testing.expect(received != null);
    if (received) |msg| {
        try std.testing.expectEqual(StarweaveProtocol.MessageType.quantum_state, msg.msg_type);
        try std.testing.expectEqualStrings(test_payload, msg.payload);
        defer allocator.free(msg.payload);
    }
} 