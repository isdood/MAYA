const std = @import("std");
const neural = @import("neural");
const glimmer = @import("glimmer");

/// Error severity levels for protocol messages
pub const ErrorSeverity = enum {
    info,
    warning,
    err,
    critical
};

/// Validation errors for protocol messages
pub const ValidationError = error{
    InvalidTimestamp,
    InvalidPriority,
    InvalidSource,
    InvalidTarget,
    InvalidQuantumState,
    InvalidNeuralActivity,
    InvalidPattern,
    InvalidSystemStatus,
    InvalidErrorReport,
    QuantumCoherenceViolation,
    NeuralResonanceMismatch,
    PatternStabilityError,
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

        /// Validate the message structure and content
        pub fn validate(self: *const Message) ValidationError!void {
            // Validate timestamp
            if (self.timestamp < 0 or self.timestamp > @as(f64, @floatFromInt(std.time.timestamp()))) {
                return ValidationError.InvalidTimestamp;
            }

            // Validate priority
            if (self.priority == 0 or self.priority > 10) {
                return ValidationError.InvalidPriority;
            }

            // Validate source and target
            if (self.source.len == 0 or self.target.len == 0) {
                return ValidationError.InvalidSource;
            }

            // Validate message type specific content
            switch (self.msg_type) {
                .quantum_state => try self.validateQuantumState(),
                .neural_activity => try self.validateNeuralActivity(),
                .pattern_update => try self.validatePattern(),
                .system_status => try self.validateSystemStatus(),
                .error_report => try self.validateErrorReport(),
            }
        }

        /// Validate quantum state message
        fn validateQuantumState(self: *const Message) ValidationError!void {
            const state = self.data.quantum_state;
            
            // Check amplitude range
            if (state.amplitude < 0 or state.amplitude > 1.0) {
                return ValidationError.InvalidQuantumState;
            }

            // Check phase range
            if (state.phase < -std.math.pi or state.phase > std.math.pi) {
                return ValidationError.InvalidQuantumState;
            }

            // Check energy consistency
            const expected_energy = state.amplitude * state.amplitude;
            if (@abs(state.energy - expected_energy) > 0.001) {
                return ValidationError.QuantumCoherenceViolation;
            }

            // Check resonance and coherence
            if (state.resonance < 0 or state.resonance > 1.0) {
                return ValidationError.NeuralResonanceMismatch;
            }
            if (state.coherence < 0 or state.coherence > 1.0) {
                return ValidationError.PatternStabilityError;
            }
        }

        /// Validate neural activity message
        fn validateNeuralActivity(self: *const Message) ValidationError!void {
            const activity = self.data.neural_activity;
            
            // Check activity range
            if (activity < 0 or activity > 1.0) {
                return ValidationError.InvalidNeuralActivity;
            }
        }

        /// Validate pattern update message
        fn validatePattern(self: *const Message) ValidationError!void {
            const pattern = self.data.pattern_update;
            
            // Validate pattern properties
            if (pattern.intensity < 0 or pattern.intensity > 1.0) {
                return ValidationError.InvalidPattern;
            }

            if (pattern.frequency < 0) {
                return ValidationError.InvalidPattern;
            }

            if (pattern.phase < -std.math.pi or pattern.phase > std.math.pi) {
                return ValidationError.InvalidPattern;
            }
        }

        /// Validate system status message
        fn validateSystemStatus(self: *const Message) ValidationError!void {
            const status = self.data.system_status;
            
            // Check all metrics are in valid range
            if (status.quantum_coherence < 0 or status.quantum_coherence > 1.0) {
                return ValidationError.InvalidSystemStatus;
            }
            if (status.neural_resonance < 0 or status.neural_resonance > 1.0) {
                return ValidationError.InvalidSystemStatus;
            }
            if (status.pattern_stability < 0 or status.pattern_stability > 1.0) {
                return ValidationError.InvalidSystemStatus;
            }
            if (status.system_health < 0 or status.system_health > 1.0) {
                return ValidationError.InvalidSystemStatus;
            }
        }

        /// Validate error report message
        fn validateErrorReport(self: *const Message) ValidationError!void {
            const report = self.data.error_report;
            
            // Check error message
            if (report.error_message.len == 0) {
                return ValidationError.InvalidErrorReport;
            }

            // Check context
            if (report.context.len == 0) {
                return ValidationError.InvalidErrorReport;
            }
        }
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

    /// Message handler type
    pub const MessageHandler = *const fn(*anyopaque, Message) anyerror!void;

    /// Protocol state
    allocator: std.mem.Allocator,
    message_queue: MessageQueue,
    handlers: std.AutoHashMap(MessageType, MessageHandler),
    context: *anyopaque,

    /// Initialize the protocol
    pub fn init(allocator: std.mem.Allocator, context: *anyopaque) !Self {
        return Self{
            .allocator = allocator,
            .message_queue = try MessageQueue.init(allocator),
            .handlers = std.AutoHashMap(MessageType, MessageHandler).init(allocator),
            .context = context,
        };
    }

    /// Deinitialize the protocol
    pub fn deinit(self: *Self) void {
        self.message_queue.deinit();
        self.handlers.deinit();
    }

    /// Register a message handler
    pub fn registerHandler(
        self: *Self,
        msg_type: MessageType,
        handler: MessageHandler,
    ) !void {
        try self.handlers.put(msg_type, handler);
    }

    /// Process a message through the appropriate handler
    pub fn processMessage(self: *Self, message: Message) !void {
        // Validate message before processing
        try message.validate();

        if (self.handlers.get(message.msg_type)) |handler| {
            try handler(self.context, message);
        } else {
            return error.NoHandlerRegistered;
        }
    }

    /// Process all messages in the queue
    pub fn processQueue(self: *Self) !void {
        while (self.message_queue.dequeue()) |message| {
            try self.processMessage(message);
        }
    }

    /// Send a message through the protocol
    pub fn sendMessage(self: *Self, message: Message) !void {
        // Validate message before sending
        try message.validate();
        try self.message_queue.enqueue(message);
    }

    /// Create a quantum state message
    pub fn createQuantumStateMessage(
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
    
    // Create global context
    var neural_bridge = try neural.NeuralBridge.init(gpa.allocator(), .{
        .max_connections = 100,
        .quantum_threshold = 0.5,
        .learning_rate = 0.01,
        .resonance_decay = 0.95,
        .coherence_threshold = 0.7,
        .normalization_factor = 1.0,
        .pattern_memory_size = 100,
        .visualization_resolution = 1000,
    });
    
    // Create a pattern for testing
    const pattern = glimmer.GlimmerPattern.init(.{
        .pattern_type = .quantum_wave,
        .base_color = glimmer.colors.GlimmerColors.primary,
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    });
    
    const global_context = try gpa.allocator().create(struct {
        neural_bridge: *neural.NeuralBridge,
        pattern: glimmer.GlimmerPattern,
    });
    global_context.* = .{
        .neural_bridge = &neural_bridge,
        .pattern = pattern,
    };
    
    protocol = try StarweaveProtocol.init(gpa.allocator(), global_context);
}

pub fn deinit() void {
    if (protocol) |*p| {
        p.deinit();
    }
    protocol = null;
    _ = gpa.deinit();
}

pub fn process() !void {
    if (protocol == null) return error.NotInitialized;
    try protocol.?.processQueue();
}

test "StarweaveProtocol" {
    const test_allocator = std.testing.allocator;
    
    // Create test context
    var neural_bridge = try neural.NeuralBridge.init(test_allocator, .{
        .max_connections = 100,
        .quantum_threshold = 0.5,
        .learning_rate = 0.01,
        .resonance_decay = 0.95,
        .coherence_threshold = 0.7,
        .normalization_factor = 1.0,
        .pattern_memory_size = 100,
        .visualization_resolution = 1000,
    });
    defer neural_bridge.deinit();
    
    // Create a pattern for testing
    const pattern = glimmer.GlimmerPattern.init(.{
        .pattern_type = .quantum_wave,
        .base_color = glimmer.colors.GlimmerColors.primary,
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    });
    
    const test_context = try test_allocator.create(struct {
        neural_bridge: *neural.NeuralBridge,
        pattern: glimmer.GlimmerPattern,
    });
    test_context.* = .{
        .neural_bridge = &neural_bridge,
        .pattern = pattern,
    };
    defer test_allocator.destroy(test_context);
    
    var test_protocol = try StarweaveProtocol.init(test_allocator, test_context);
    defer test_protocol.deinit();

    // Test message creation
    const quantum_state = try test_protocol.createQuantumStateMessage(
        .{
            .amplitude = 0.5,
            .phase = 0.0,
            .energy = 0.25,
            .resonance = 0.5,
            .coherence = 0.8,
        },
        "test_source",
        "test_target",
    );

    // Test message sending
    try test_protocol.sendMessage(quantum_state);

    // Test message processing
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

test "MessageValidation" {
    const test_allocator = std.testing.allocator;
    
    // Create test context
    var neural_bridge = try neural.NeuralBridge.init(test_allocator, .{
        .max_connections = 100,
        .quantum_threshold = 0.5,
        .learning_rate = 0.01,
        .resonance_decay = 0.95,
        .coherence_threshold = 0.7,
        .normalization_factor = 1.0,
        .pattern_memory_size = 100,
        .visualization_resolution = 1000,
    });
    defer neural_bridge.deinit();
    
    // Create a pattern for testing
    const pattern = glimmer.GlimmerPattern.init(.{
        .pattern_type = .quantum_wave,
        .base_color = glimmer.colors.GlimmerColors.primary,
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    });
    
    const test_context = try test_allocator.create(struct {
        neural_bridge: *neural.NeuralBridge,
        pattern: glimmer.GlimmerPattern,
    });
    test_context.* = .{
        .neural_bridge = &neural_bridge,
        .pattern = pattern,
    };
    defer test_allocator.destroy(test_context);
    
    var test_protocol = try StarweaveProtocol.init(test_allocator, test_context);
    defer test_protocol.deinit();

    // Test valid quantum state message
    const valid_state = try test_protocol.createQuantumStateMessage(
        .{
            .amplitude = 0.5,
            .phase = 0.0,
            .energy = 0.25,
            .resonance = 0.5,
            .coherence = 0.8,
        },
        "neural_bridge",
        "pattern_system",
    );
    try valid_state.validate();

    // Test invalid quantum state message
    const invalid_state = try test_protocol.createQuantumStateMessage(
        .{
            .amplitude = 1.5, // Invalid amplitude
            .phase = 0.0,
            .energy = 0.25,
            .resonance = 0.5,
            .coherence = 0.8,
        },
        "neural_bridge",
        "pattern_system",
    );
    try std.testing.expectError(ValidationError.InvalidQuantumState, invalid_state.validate());

    // Test valid neural activity message
    const valid_activity = try test_protocol.createNeuralActivityMessage(
        0.5,
        "neural_bridge",
        "pattern_system",
    );
    try valid_activity.validate();

    // Test invalid neural activity message
    const invalid_activity = try test_protocol.createNeuralActivityMessage(
        1.5, // Invalid activity
        "neural_bridge",
        "pattern_system",
    );
    try std.testing.expectError(ValidationError.InvalidNeuralActivity, invalid_activity.validate());
} 