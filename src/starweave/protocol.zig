const std = @import("std");
const neural = @import("../neural/bridge.zig");
const glimmer = @import("../glimmer/patterns.zig");

/// Error severity levels for protocol messages
pub const ErrorSeverity = enum {
    info,
    warning,
    err,
    critical
};

/// STARWEAVE Protocol for quantum-neural communication
pub const StarweaveProtocol = struct {
    const Self = @This();

    /// Message types for quantum-neural communication
    pub const MessageType = enum {
        quantum_state,
        neural_activity,
        pattern_update,
        system_status,
        error_report,
    };

    /// Protocol message structure
    pub const Message = struct {
        msg_type: MessageType,
        timestamp: f64,
        data: union(enum) {
            quantum_state: neural.QuantumState,
            neural_activity: f64,
            pattern_update: glimmer.GlimmerPattern,
            system_status: SystemStatus,
            error_report: ErrorReport,
        },
        priority: u8,
        source: []const u8,
        target: []const u8,

        pub const SystemStatus = struct {
            quantum_coherence: f64,
            neural_resonance: f64,
            pattern_stability: f64,
            system_health: f64,
        };

        pub const ErrorReport = struct {
            error_code: u32,
            error_message: []const u8,
            severity: ErrorSeverity,
            context: []const u8,
        };
    };

    /// Message queue for handling protocol messages
    pub const MessageQueue = struct {
        messages: std.ArrayList(Message),
        max_size: usize,
        allocator: std.mem.Allocator,

        pub fn init(alloc: std.mem.Allocator, max_size: usize) MessageQueue {
            return MessageQueue{
                .messages = std.ArrayList(Message).init(alloc),
                .max_size = max_size,
                .allocator = alloc,
            };
        }

        pub fn deinit(self: *MessageQueue) void {
            self.messages.deinit();
        }

        pub fn enqueue(self: *MessageQueue, message: Message) !void {
            if (self.messages.items.len >= self.max_size) {
                return error.QueueFull;
            }
            try self.messages.append(message);
        }

        pub fn dequeue(self: *MessageQueue) ?Message {
            if (self.messages.items.len == 0) return null;
            return self.messages.orderedRemove(0);
        }
    };

    allocator: std.mem.Allocator,
    message_queue: MessageQueue,
    handlers: std.AutoHashMap(MessageType, MessageHandler),
    initialized: bool,

    /// Message handler function type
    pub const MessageHandler = fn (message: Message) anyerror!void;

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .allocator = alloc,
            .message_queue = MessageQueue.init(alloc, 1000),
            .handlers = std.AutoHashMap(MessageType, MessageHandler).init(alloc),
            .initialized = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.message_queue.deinit();
        self.handlers.deinit();
        self.initialized = false;
    }

    /// Register a message handler for a specific message type
    pub fn registerHandler(self: *Self, msg_type: MessageType, handler: MessageHandler) !void {
        try self.handlers.put(msg_type, handler);
    }

    /// Process a message through the appropriate handler
    pub fn processMessage(self: *Self, message: Message) !void {
        if (self.handlers.get(message.msg_type)) |handler| {
            try handler(message);
        } else {
            return error.NoHandlerRegistered;
        }
    }

    /// Send a message through the protocol
    pub fn sendMessage(self: *Self, message: Message) !void {
        try self.message_queue.enqueue(message);
    }

    /// Process all queued messages
    pub fn processQueue(self: *Self) !void {
        while (self.message_queue.dequeue()) |message| {
            try self.processMessage(message);
        }
    }

    /// Create a quantum state message
    pub fn createQuantumStateMessage(
        self: *Self,
        state: neural.QuantumState,
        source: []const u8,
        target: []const u8,
    ) !Message {
        return Message{
            .msg_type = .quantum_state,
            .timestamp = @as(f64, @floatFromInt(std.time.timestamp())),
            .data = .{ .quantum_state = state },
            .priority = 1,
            .source = source,
            .target = target,
        };
    }

    /// Create a neural activity message
    pub fn createNeuralActivityMessage(
        self: *Self,
        activity: f64,
        source: []const u8,
        target: []const u8,
    ) !Message {
        return Message{
            .msg_type = .neural_activity,
            .timestamp = @as(f64, @floatFromInt(std.time.timestamp())),
            .data = .{ .neural_activity = activity },
            .priority = 2,
            .source = source,
            .target = target,
        };
    }

    /// Create a pattern update message
    pub fn createPatternUpdateMessage(
        self: *Self,
        pattern: glimmer.GlimmerPattern,
        source: []const u8,
        target: []const u8,
    ) !Message {
        return Message{
            .msg_type = .pattern_update,
            .timestamp = @as(f64, @floatFromInt(std.time.timestamp())),
            .data = .{ .pattern_update = pattern },
            .priority = 3,
            .source = source,
            .target = target,
        };
    }
};

var protocol: ?StarweaveProtocol = null;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn init() !void {
    if (protocol != null) return;
    protocol = StarweaveProtocol.init(gpa.allocator());
    protocol.?.initialized = true;
}

pub fn deinit() void {
    if (protocol) |*p| {
        p.deinit();
        protocol = null;
    }
    _ = gpa.deinit();
}

pub fn process() !void {
    if (protocol == null) return error.NotInitialized;
    try protocol.?.processQueue();
}

test "StarweaveProtocol" {
    const test_allocator = std.testing.allocator;
    var test_protocol = StarweaveProtocol.init(test_allocator);
    defer test_protocol.deinit();

    // Test message creation and processing
    const message = try test_protocol.createNeuralActivityMessage(
        0.5,
        "neural_bridge",
        "pattern_system",
    );
    try test_protocol.sendMessage(message);
    try test_protocol.processQueue();
}

test "MessageQueue" {
    const test_allocator = std.testing.allocator;
    var queue = StarweaveProtocol.MessageQueue.init(test_allocator, 10);
    defer queue.deinit();

    const message = StarweaveProtocol.Message{
        .msg_type = .system_status,
        .timestamp = 0.0,
        .data = .{
            .system_status = .{
                .quantum_coherence = 0.8,
                .neural_resonance = 0.7,
                .pattern_stability = 0.9,
                .system_health = 1.0,
            },
        },
        .priority = 1,
        .source = "test",
        .target = "test",
    };

    try queue.enqueue(message);
    const dequeued = queue.dequeue();
    try std.testing.expect(dequeued != null);
    try std.testing.expect(dequeued.?.msg_type == .system_status);
} 