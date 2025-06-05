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
    EmptyMessageContent,
    InvalidQuantumAmplitude,
    InvalidQuantumPhase,
    InvalidQuantumEnergy,
    InvalidQuantumResonance,
    InvalidQuantumCoherence,
    InvalidNeuralAmplitude,
    InvalidNeuralFrequency,
    InvalidNeuralPhase,
    InvalidPatternIntensity,
    InvalidPatternFrequency,
    InvalidPatternPhase,
    InvalidSourceTarget,
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
    visualization_enabled: bool,
    recovery_state: ?RecoveryState,

    /// Error recovery state
    const RecoveryState = struct {
        retry_count: u32,
        last_error: ?ValidationError,
        recovery_timeout: i64,
    };

    /// Initialize the protocol
    pub fn init(alloc: std.mem.Allocator, context: *anyopaque) !Self {
        return Self{
            .allocator = alloc,
            .message_queue = MessageQueue.init(alloc, 1000),
            .handlers = std.AutoHashMap(MessageType, MessageHandler).init(alloc),
            .context = context,
            .visualization_enabled = false,
            .recovery_state = null,
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

    /// Validates the basic structure of a message
    fn validateMessageStructure(self: *Self, msg: Message) !void {
        _ = self; // Mark self as used to avoid unused parameter warning

        // Check if message type is valid
        if (msg.msg_type == .quantum_state) {
            if (msg.data.quantum_state.amplitude < 0.0 or msg.data.quantum_state.amplitude > 1.0) {
                return ValidationError.InvalidQuantumAmplitude;
            }
        } else if (msg.msg_type == .neural_activity) {
            if (msg.data.neural_activity < 0.0 or msg.data.neural_activity > 1.0) {
                return ValidationError.InvalidNeuralAmplitude;
            }
        } else if (msg.msg_type == .pattern_update) {
            if (msg.data.pattern_update.intensity < 0.0 or msg.data.pattern_update.intensity > 1.0) {
                return ValidationError.InvalidPatternIntensity;
            }
        }

        // Check if source and target are valid
        if (msg.source.len == 0 or msg.target.len == 0) {
            return ValidationError.InvalidSourceTarget;
        }

        // Check if timestamp is valid
        if (msg.timestamp <= 0) {
            return ValidationError.InvalidTimestamp;
        }
    }

    /// Enable or disable visualization
    pub fn setVisualizationEnabled(self: *Self, enabled: bool) void {
        self.visualization_enabled = enabled;
    }

    /// Specialized handler for quantum state messages
    fn handleQuantumState(self: *Self, msg: Message) !void {
        const ContextType = struct {
            neural_bridge: *neural.NeuralBridge,
            pattern: glimmer.GlimmerPattern,
        };
        const context = @as(*ContextType, @alignCast(@ptrCast(self.context)));

        // Update neural bridge with quantum state
        try context.neural_bridge.updateQuantumState(
            0, // Default index
            msg.data.quantum_state.amplitude,
            msg.data.quantum_state.phase
        );

        // Process activity and detect patterns
        try context.neural_bridge.processActivity(
            msg.data.quantum_state.amplitude,
            0.1 // Default delta time
        );

        // Update visualization if needed
        if (self.visualization_enabled) {
            try self.updateVisualization(msg);
        }
    }

    /// Specialized handler for neural activity messages
    fn handleNeuralActivity(self: *Self, msg: Message) !void {
        const ContextType = struct {
            neural_bridge: *neural.NeuralBridge,
            pattern: glimmer.GlimmerPattern,
        };
        const context = @as(*ContextType, @alignCast(@ptrCast(self.context)));

        // Process neural activity (includes pattern detection and memory updates)
        try context.neural_bridge.processActivity(msg.data.neural_activity, 0.1);

        // Update visualization if needed
        if (self.visualization_enabled) {
            try self.updateVisualization(msg);
        }
    }

    /// Specialized handler for pattern update messages
    fn handlePatternUpdate(self: *Self, msg: Message) !void {
        const ContextType = struct {
            neural_bridge: *neural.NeuralBridge,
            pattern: glimmer.GlimmerPattern,
        };
        const context = @as(*ContextType, @alignCast(@ptrCast(self.context)));

        // Update pattern with transition
        var new_pattern = glimmer.GlimmerPattern.init(.{
            .pattern_type = msg.data.pattern_update.pattern_type,
            .base_color = msg.data.pattern_update.base_color,
            .intensity = msg.data.pattern_update.intensity,
            .frequency = msg.data.pattern_update.frequency,
            .phase = msg.data.pattern_update.phase,
        });

        // Create smooth transition
        new_pattern.transition = .{
            .target_config = .{
                .pattern_type = msg.data.pattern_update.pattern_type,
                .base_color = msg.data.pattern_update.base_color,
                .intensity = msg.data.pattern_update.intensity,
                .frequency = msg.data.pattern_update.frequency,
                .phase = msg.data.pattern_update.phase,
            },
            .duration = 0.5, // Half second transition
            .elapsed = 0.0,
            .easing = .neural_flow,
        };

        // Update pattern
        context.pattern = new_pattern;

        // Process pattern activity in neural bridge
        try context.neural_bridge.processActivity(
            msg.data.pattern_update.intensity,
            0.1 // Default delta time
        );

        // Share pattern memory with neural bridge
        if (context.neural_bridge.visualization) |*viz| {
            // Create activity pattern from glimmer pattern
            const activity_pattern = neural.NeuralBridge.ActivityPattern{
                .pattern_type = switch (msg.data.pattern_update.pattern_type) {
                    .quantum_wave => .quantum_surge,
                    .neural_flow => .neural_cascade,
                    .cosmic_sparkle => .cosmic_ripple,
                    .stellar_pulse => .stellar_pulse,
                },
                .confidence = msg.data.pattern_update.intensity,
                .last_seen = 0.0, // Will be updated by neural bridge
                .duration = 0.5, // Match transition duration
                .intensity = msg.data.pattern_update.intensity,
                .frequency = msg.data.pattern_update.frequency,
                .phase = msg.data.pattern_update.phase,
            };

            // Update visualization with pattern
            try viz.update(
                msg.data.pattern_update.intensity,
                activity_pattern,
                &context.neural_bridge.quantum_states.items
            );
        }

        // Update visualization if needed
        if (self.visualization_enabled) {
            try self.updateVisualization(msg);
        }
    }

    /// Attempts to recover from an error
    fn attemptRecovery(self: *Self, err: ValidationError) !void {
        // Initialize recovery state if needed
        if (self.recovery_state == null) {
            self.recovery_state = RecoveryState{
                .retry_count = 0,
                .last_error = err,
                .recovery_timeout = std.time.milliTimestamp() + 5000, // 5 second timeout
            };
        }

        const state = &self.recovery_state.?;

        // Check if we've exceeded retry limit
        if (state.retry_count >= 3) {
            return error.MaxRetriesExceeded;
        }

        // Check if we've exceeded timeout
        if (std.time.milliTimestamp() > state.recovery_timeout) {
            return error.RecoveryTimeout;
        }

        // Increment retry count
        state.retry_count += 1;

        // Attempt recovery based on error type
        switch (err) {
            .InvalidQuantumAmplitude, .InvalidQuantumPhase, .InvalidQuantumEnergy,
            .InvalidQuantumResonance, .InvalidQuantumCoherence => {
                // Reset quantum state
                try self.resetQuantumState();
            },
            .InvalidNeuralAmplitude => {
                // Reset neural activity
                try self.resetNeuralActivity();
            },
            .InvalidPatternIntensity, .InvalidPatternFrequency, .InvalidPatternPhase => {
                // Reset pattern
                try self.resetPattern();
            },
            else => {
                // For other errors, just log and continue
                std.log.err("Unhandled error during recovery: {}", .{err});
            },
        }
    }

    /// Resets quantum state to default values
    fn resetQuantumState(self: *Self) !void {
        const ContextType = struct {
            neural_bridge: *neural.NeuralBridge,
            pattern: glimmer.GlimmerPattern,
        };
        const context = @as(*ContextType, @ptrCast(self.context));

        try context.neural_bridge.resetQuantumState();
    }

    /// Resets neural activity to default values
    fn resetNeuralActivity(self: *Self) !void {
        const ContextType = struct {
            neural_bridge: *neural.NeuralBridge,
            pattern: glimmer.GlimmerPattern,
        };
        const context = @as(*ContextType, @ptrCast(self.context));

        try context.neural_bridge.resetActivity();
    }

    /// Resets pattern to default values
    fn resetPattern(self: *Self) !void {
        const ContextType = struct {
            neural_bridge: *neural.NeuralBridge,
            pattern: glimmer.GlimmerPattern,
        };
        const context = @as(*ContextType, @ptrCast(self.context));

        context.pattern = glimmer.GlimmerPattern.default();
        try context.neural_bridge.synchronizePattern(context.pattern);
    }

    /// Updates visualization with message data
    fn updateVisualization(self: *Self, msg: Message) !void {
        const ContextType = struct {
            neural_bridge: *neural.NeuralBridge,
            pattern: glimmer.GlimmerPattern,
        };
        const context = @as(*ContextType, @alignCast(@ptrCast(self.context)));

        if (context.neural_bridge.visualization) |*viz| {
            switch (msg.msg_type) {
                .quantum_state => {
                    try viz.update(
                        msg.data.quantum_state.amplitude,
                        null,
                        &[_]neural.QuantumState{msg.data.quantum_state}
                    );
                },
                .neural_activity => {
                    try viz.update(
                        msg.data.neural_activity,
                        null,
                        context.neural_bridge.quantum_states.items
                    );
                },
                .pattern_update => {
                    try viz.update(
                        context.neural_bridge.current_activity,
                        null,
                        context.neural_bridge.quantum_states.items
                    );
                },
                else => {},
            }
        }
    }

    /// Enhanced message validation with quantum and neural checks
    fn validateMessage(self: *Self, msg: Message) !void {
        // Basic structure validation
        try self.validateMessageStructure(msg);

        // Quantum coherence check
        if (msg.msg_type == .quantum_state) {
            if (msg.data.quantum_state.coherence < 0.0 or msg.data.quantum_state.coherence > 1.0) {
                return error.InvalidQuantumCoherence;
            }
            if (msg.data.quantum_state.amplitude < 0.0) {
                return error.InvalidQuantumAmplitude;
            }
        }

        // Neural resonance check
        if (msg.msg_type == .neural_activity) {
            if (msg.data.neural_activity < 0.0 or msg.data.neural_activity > 1.0) {
                return error.InvalidNeuralActivity;
            }
        }

        // Pattern stability check
        if (msg.msg_type == .pattern_update) {
            if (msg.data.pattern_update.intensity < 0.0 or msg.data.pattern_update.intensity > 1.0) {
                return error.InvalidPatternIntensity;
            }
        }
    }

    /// Process a message with enhanced error recovery
    pub fn processMessage(self: *Self, msg: Message) !void {
        // Create a mutable copy of the message for recovery
        var mutable_msg = msg;

        // Validate message
        self.validateMessage(mutable_msg) catch |err| {
            // Log error and attempt recovery
            std.log.err("Message validation failed: {s}", .{@errorName(err)});
            
            // Attempt to recover based on error type
            switch (err) {
                error.InvalidQuantumCoherence => {
                    // Try to normalize coherence
                    if (mutable_msg.msg_type == .quantum_state) {
                        mutable_msg.data.quantum_state.coherence = @max(0.0, @min(1.0, mutable_msg.data.quantum_state.coherence));
                    }
                },
                error.InvalidNeuralActivity => {
                    // Try to normalize activity
                    if (mutable_msg.msg_type == .neural_activity) {
                        mutable_msg.data.neural_activity = @max(0.0, @min(1.0, mutable_msg.data.neural_activity));
                    }
                },
                error.InvalidPatternIntensity => {
                    // Try to normalize intensity
                    if (mutable_msg.msg_type == .pattern_update) {
                        mutable_msg.data.pattern_update.intensity = @max(0.0, @min(1.0, mutable_msg.data.pattern_update.intensity));
                    }
                },
                else => return err, // Re-throw other errors
            }
        };

        // Process the message
        if (self.handlers.get(mutable_msg.msg_type)) |handler| {
            try handler(self, mutable_msg);
        } else {
            return error.UnknownMessageType;
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

    /// Creates and validates a message
    pub fn createMessage(self: *Self, msg_type: MessageType, content: []const u8) !Message {
        const msg = Message{
            .msg_type = msg_type,
            .timestamp = std.time.milliTimestamp(),
            .data = switch (msg_type) {
                .quantum_state => blk: {
                    const quantum_state = try std.json.parseFromSlice(neural.QuantumState, self.allocator, content, .{});
                    defer quantum_state.deinit();
                    break :blk .{ .quantum_state = quantum_state.value };
                },
                .neural_activity => blk: {
                    const activity = try std.fmt.parseFloat(f32, content);
                    break :blk .{ .neural_activity = activity };
                },
                .pattern_update => blk: {
                    const pattern = try std.json.parseFromSlice(glimmer.GlimmerPattern, self.allocator, content, .{});
                    defer pattern.deinit();
                    break :blk .{ .pattern_update = pattern.value };
                },
                else => return error.UnsupportedMessageType,
            },
            .priority = 1,
            .source = try self.allocator.dupe(u8, "test"),
            .target = try self.allocator.dupe(u8, "test"),
        };

        // Validate the message before returning
        try self.validateMessage(msg);

        return msg;
    }
};

var protocol: ?StarweaveProtocol = null;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn init() !void {
    if (protocol != null) return;
    
    // Create global context
    const global_context = try gpa.allocator().create(struct {
        neural_bridge: *neural.NeuralBridge,
        pattern: glimmer.GlimmerPattern,
    });
    defer gpa.allocator().destroy(global_context);

    // Create neural bridge first
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
    defer neural_bridge.deinit();

    global_context.* = .{
        .neural_bridge = &neural_bridge,
        .pattern = glimmer.GlimmerPattern.init(.{
            .pattern_type = .quantum_wave,
            .base_color = glimmer.colors.GlimmerColors.primary,
            .intensity = 0.5,
            .frequency = 1.0,
            .phase = 0.0,
        }),
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
    defer test_protocol.?.deinit();

    // Test message creation
    const test_message = try test_protocol.?.createMessage(.quantum_state, 
        \\{"amplitude": 0.5, "phase": 0.0, "energy": 0.25, "resonance": 0.5, "coherence": 0.8}
    );
    try std.testing.expectEqual(StarweaveProtocol.MessageType.quantum_state, test_message.msg_type);
    try std.testing.expectEqual(@as(f32, 0.5), test_message.data.quantum_state.amplitude);
    try std.testing.expectEqual(@as(f32, 0.0), test_message.data.quantum_state.phase);
    try std.testing.expectEqual(@as(f32, 0.25), test_message.data.quantum_state.energy);
    try std.testing.expectEqual(@as(f32, 0.5), test_message.data.quantum_state.resonance);
    try std.testing.expectEqual(@as(f32, 0.8), test_message.data.quantum_state.coherence);
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