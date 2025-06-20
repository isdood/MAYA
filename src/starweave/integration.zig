
const std = @import("std");
const protocol = @import("./protocol.zig");
const neural = @import("../neural/bridge.zig");
const glimmer = @import("../glimmer/patterns.zig");

/// Integration layer between STARWEAVE and Neural Bridge
pub const StarweaveIntegration = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    protocol: *protocol.StarweaveProtocol,
    bridge: *neural.NeuralBridge,
    initialized: bool,

    pub fn init(
        alloc: std.mem.Allocator,
        proto: *protocol.StarweaveProtocol,
        bridge: *neural.NeuralBridge,
    ) Self {
        return Self{
            .allocator = alloc,
            .protocol = proto,
            .bridge = bridge,
            .initialized = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.initialized = false;
    }

    /// Initialize the integration layer
    pub fn setup(self: *Self) !void {
        // Register message handlers
        try self.protocol.registerHandler(.quantum_state, handleQuantumState);
        try self.protocol.registerHandler(.neural_activity, handleNeuralActivity);
        try self.protocol.registerHandler(.pattern_update, handlePatternUpdate);
        try self.protocol.registerHandler(.system_status, handleSystemStatus);
        try self.protocol.registerHandler(.error_report, handleErrorReport);

        self.initialized = true;
    }

    /// Handle quantum state messages
    fn handleQuantumState(message: protocol.Message) !void {
        if (message.data != .quantum_state) return error.InvalidMessageType;
        const state = message.data.quantum_state;
        // Process quantum state update
        _ = state;
    }

    /// Handle neural activity messages
    fn handleNeuralActivity(message: protocol.Message) !void {
        if (message.data != .neural_activity) return error.InvalidMessageType;
        const activity = message.data.neural_activity;
        // Process neural activity update
        _ = activity;
    }

    /// Handle pattern update messages
    fn handlePatternUpdate(message: protocol.Message) !void {
        if (message.data != .pattern_update) return error.InvalidMessageType;
        const pattern = message.data.pattern_update;
        // Process pattern update
        _ = pattern;
    }

    /// Handle system status messages
    fn handleSystemStatus(message: protocol.Message) !void {
        if (message.data != .system_status) return error.InvalidMessageType;
        const status = message.data.system_status;
        // Process system status update
        _ = status;
    }

    /// Handle error report messages
    fn handleErrorReport(message: protocol.Message) !void {
        if (message.data != .error_report) return error.InvalidMessageType;
        const report = message.data.error_report;
        // Process error report
        _ = report;
    }

    /// Send quantum state update
    pub fn sendQuantumState(self: *Self, state: neural.QuantumState) !void {
        const message = try self.protocol.createQuantumStateMessage(
            state,
            "neural_bridge",
            "starweave",
        );
        try self.protocol.sendMessage(message);
    }

    /// Send neural activity update
    pub fn sendNeuralActivity(self: *Self, activity: f64) !void {
        const message = try self.protocol.createNeuralActivityMessage(
            activity,
            "neural_bridge",
            "starweave",
        );
        try self.protocol.sendMessage(message);
    }

    /// Send pattern update
    pub fn sendPatternUpdate(self: *Self, pattern: glimmer.GlimmerPattern) !void {
        const message = try self.protocol.createPatternUpdateMessage(
            pattern,
            "neural_bridge",
            "starweave",
        );
        try self.protocol.sendMessage(message);
    }

    /// Process updates from the neural bridge
    pub fn processBridgeUpdates(self: *Self) !void {
        // Get current activity
        const activity = self.bridge.getCurrentActivity();
        try self.sendNeuralActivity(activity);

        // Get activity patterns
        const patterns = self.bridge.getActivityPatterns();
        for (patterns) |pattern| {
            // Convert activity pattern to glimmer pattern
            const glimmer_pattern = glimmer.GlimmerPattern{
                .pattern_type = switch (pattern.pattern_type) {
                    .quantum_surge => .quantum_wave,
                    .neural_cascade => .neural_flow,
                    .cosmic_ripple => .cosmic_sparkle,
                    .stellar_pulse => .stellar_pulse,
                },
                .intensity = pattern.confidence,
                .frequency = 1.0 / pattern.duration,
                .phase = 0.0,
                .base_color = glimmer.GlimmerColors.primary,
                .state = .active,
            };
            try self.sendPatternUpdate(glimmer_pattern);
        }

        // Process protocol messages
        try self.protocol.processQueue();
    }
};

var integration: ?StarweaveIntegration = null;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn init() !void {
    if (integration != null) return;
    const proto = try protocol.init();
    const bridge = try neural.init();
    integration = StarweaveIntegration.init(gpa.allocator(), &proto, &bridge);
    try integration.?.setup();
}

pub fn deinit() void {
    if (integration) |*i| {
        i.deinit();
        integration = null;
    }
    _ = gpa.deinit();
}

pub fn process() !void {
    if (integration == null) return error.NotInitialized;
    try integration.?.processBridgeUpdates();
}

test "StarweaveIntegration" {
    const test_allocator = std.testing.allocator;
    var test_protocol = protocol.StarweaveProtocol.init(test_allocator);
    defer test_protocol.deinit();

    var test_bridge = neural.NeuralBridge.init(test_allocator, .{});
    defer test_bridge.deinit();

    var test_integration = StarweaveIntegration.init(
        test_allocator,
        &test_protocol,
        &test_bridge,
    );
    defer test_integration.deinit();

    try test_integration.setup();
    try test_integration.processBridgeUpdates();
} 
