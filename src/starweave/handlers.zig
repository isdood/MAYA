const std = @import("std");
const neural = @import("neural");
const glimmer = @import("glimmer");
const protocol = @import("protocol.zig");

/// Handler context for managing state and resources
pub const HandlerContext = struct {
    allocator: std.mem.Allocator,
    neural_bridge: *neural.NeuralBridge,
    pattern_system: *glimmer.PatternSystem,
    last_quantum_state: ?neural.QuantumState,
    last_neural_activity: ?f64,
    last_pattern: ?glimmer.GlimmerPattern,
    system_status: protocol.Message.SystemStatus,
    error_count: u32,
    warning_count: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        neural_bridge: *neural.NeuralBridge,
        pattern_system: *glimmer.PatternSystem,
    ) !HandlerContext {
        return HandlerContext{
            .allocator = allocator,
            .neural_bridge = neural_bridge,
            .pattern_system = pattern_system,
            .last_quantum_state = null,
            .last_neural_activity = null,
            .last_pattern = null,
            .system_status = .{
                .quantum_coherence = 1.0,
                .neural_resonance = 1.0,
                .pattern_stability = 1.0,
                .system_health = 1.0,
            },
            .error_count = 0,
            .warning_count = 0,
        };
    }

    pub fn deinit(self: *HandlerContext) void {
        if (self.last_pattern) |pattern| {
            pattern.deinit();
        }
    }
};

/// Handler for quantum state messages
pub fn handleQuantumState(ctx: *anyopaque, message: protocol.Message) !void {
    const handler_ctx = @ptrCast(*HandlerContext, ctx);
    const state = message.data.quantum_state;
    
    // Update neural bridge with new quantum state
    try handler_ctx.neural_bridge.updateQuantumState(state);
    
    // Store last quantum state
    handler_ctx.last_quantum_state = state;
    
    // Update system status
    handler_ctx.system_status.quantum_coherence = state.coherence;
    
    // Check for quantum coherence violations
    if (state.coherence < 0.5) {
        try logWarning(handler_ctx, "Low quantum coherence detected", .{});
    }
}

/// Handler for neural activity messages
pub fn handleNeuralActivity(ctx: *anyopaque, message: protocol.Message) !void {
    const handler_ctx = @ptrCast(*HandlerContext, ctx);
    const activity = message.data.neural_activity;
    
    // Process neural activity
    const processed_activity = try handler_ctx.neural_bridge.processActivity(activity);
    
    // Store last neural activity
    handler_ctx.last_neural_activity = processed_activity;
    
    // Update system status
    handler_ctx.system_status.neural_resonance = processed_activity;
    
    // Check for neural resonance issues
    if (processed_activity < 0.3) {
        try logWarning(handler_ctx, "Low neural resonance detected", .{});
    }
}

/// Handler for pattern update messages
pub fn handlePatternUpdate(ctx: *anyopaque, message: protocol.Message) !void {
    const handler_ctx = @ptrCast(*HandlerContext, ctx);
    const pattern = message.data.pattern_update;
    
    // Update pattern system
    try handler_ctx.pattern_system.updatePattern(pattern);
    
    // Store last pattern
    if (handler_ctx.last_pattern) |last| {
        last.deinit();
    }
    handler_ctx.last_pattern = try pattern.clone(handler_ctx.allocator);
    
    // Update system status
    handler_ctx.system_status.pattern_stability = pattern.stability;
    
    // Check for pattern stability issues
    if (pattern.stability < 0.5) {
        try logWarning(handler_ctx, "Low pattern stability detected", .{});
    }
}

/// Handler for system status messages
pub fn handleSystemStatus(ctx: *anyopaque, message: protocol.Message) !void {
    const handler_ctx = @ptrCast(*HandlerContext, ctx);
    const status = message.data.system_status;
    
    // Update system status
    handler_ctx.system_status = status;
    
    // Check for system health issues
    if (status.system_health < 0.7) {
        try logWarning(handler_ctx, "System health below threshold", .{});
    }
}

/// Handler for error report messages
pub fn handleErrorReport(ctx: *anyopaque, message: protocol.Message) !void {
    const handler_ctx = @ptrCast(*HandlerContext, ctx);
    const report = message.data.error_report;
    
    // Log error based on severity
    switch (report.severity) {
        .info => try logInfo(handler_ctx, report.error_message, .{}),
        .warning => {
            handler_ctx.warning_count += 1;
            try logWarning(handler_ctx, report.error_message, .{});
        },
        .err, .critical => {
            handler_ctx.error_count += 1;
            try logError(handler_ctx, report.error_message, .{});
        },
    }
    
    // Update system health based on error severity
    if (report.severity == .critical) {
        handler_ctx.system_status.system_health *= 0.9;
    }
}

/// Register all handlers with the protocol
pub fn registerHandlers(protocol: *protocol.StarweaveProtocol, ctx: *HandlerContext) !void {
    try protocol.registerHandler(.quantum_state, handleQuantumState);
    try protocol.registerHandler(.neural_activity, handleNeuralActivity);
    try protocol.registerHandler(.pattern_update, handlePatternUpdate);
    try protocol.registerHandler(.system_status, handleSystemStatus);
    try protocol.registerHandler(.error_report, handleErrorReport);
}

/// Logging functions
fn logInfo(ctx: *HandlerContext, comptime fmt: []const u8, args: anytype) !void {
    std.log.info(fmt, args);
}

fn logWarning(ctx: *HandlerContext, comptime fmt: []const u8, args: anytype) !void {
    std.log.warn(fmt, args);
}

fn logError(ctx: *HandlerContext, comptime fmt: []const u8, args: anytype) !void {
    std.log.err(fmt, args);
}

// Tests
test "HandlerContext" {
    const test_allocator = std.testing.allocator;
    var neural_bridge = try neural.NeuralBridge.init(test_allocator);
    defer neural_bridge.deinit();
    
    var pattern_system = try glimmer.PatternSystem.init(test_allocator);
    defer pattern_system.deinit();
    
    var ctx = try HandlerContext.init(test_allocator, &neural_bridge, &pattern_system);
    defer ctx.deinit();
    
    // Test initial state
    try std.testing.expect(ctx.last_quantum_state == null);
    try std.testing.expect(ctx.last_neural_activity == null);
    try std.testing.expect(ctx.last_pattern == null);
    try std.testing.expect(ctx.error_count == 0);
    try std.testing.expect(ctx.warning_count == 0);
}

test "MessageHandlers" {
    const test_allocator = std.testing.allocator;
    var neural_bridge = try neural.NeuralBridge.init(test_allocator);
    defer neural_bridge.deinit();
    
    var pattern_system = try glimmer.PatternSystem.init(test_allocator);
    defer pattern_system.deinit();
    
    var ctx = try HandlerContext.init(test_allocator, &neural_bridge, &pattern_system);
    defer ctx.deinit();
    
    // Test quantum state handler
    const quantum_state = protocol.Message{
        .msg_type = .quantum_state,
        .timestamp = @as(f64, @floatFromInt(std.time.timestamp())),
        .data = .{
            .quantum_state = .{
                .amplitude = 0.5,
                .phase = 0.0,
                .energy = 0.25,
                .resonance = 0.5,
                .coherence = 0.8,
            },
        },
        .priority = 5,
        .source = "test",
        .target = "test",
    };
    try handleQuantumState(&ctx, quantum_state);
    try std.testing.expect(ctx.last_quantum_state != null);
    
    // Test neural activity handler
    const neural_activity = protocol.Message{
        .msg_type = .neural_activity,
        .timestamp = @as(f64, @floatFromInt(std.time.timestamp())),
        .data = .{ .neural_activity = 0.5 },
        .priority = 5,
        .source = "test",
        .target = "test",
    };
    try handleNeuralActivity(&ctx, neural_activity);
    try std.testing.expect(ctx.last_neural_activity != null);
} 