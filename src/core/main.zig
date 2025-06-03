const std = @import("std");
const glimmer = @import("glimmer");
const neural = @import("neural");
const starweave = @import("starweave");

pub fn main() !void {
    // Initialize the general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize STARWEAVE protocol
    const protocol_config = starweave.StarweaveProtocol.Config{
        .max_message_size = 1024,
        .timeout_ms = 1000,
        .retry_count = 3,
    };
    var protocol = try starweave.StarweaveProtocol.init(allocator, protocol_config);
    defer protocol.deinit();

    // Initialize Neural Bridge
    const bridge_config = neural.NeuralBridge.PathwayConfig{
        .max_connections = 100,
        .quantum_threshold = 0.5,
        .learning_rate = 0.01,
    };
    var bridge = try neural.NeuralBridge.init(allocator, bridge_config);
    defer bridge.deinit();

    // Initialize neural pathways
    try bridge.initPathways();

    // Test GLIMMER color system
    const colors = glimmer.GlimmerColors;
    const transition = try colors.createTransition(colors.primary, colors.secondary, 3);
    defer allocator.free(transition);

    // Process initial quantum state
    const initial_state = try bridge.getQuantumState(0);
    const state_str = try std.fmt.allocPrint(
        allocator,
        "{{ amplitude: {d}, phase: {d}, energy: {d} }}",
        .{ initial_state.amplitude, initial_state.phase, initial_state.energy }
    );
    defer allocator.free(state_str);

    try protocol.processQuantumState(state_str);

    // Print welcome message
    std.debug.print("✨ MAYA initialized successfully!\n", .{});
    std.debug.print("GLIMMER colors: {s} -> {s}\n", .{ transition[0], transition[2] });
    std.debug.print("Initial quantum state: {s}\n", .{state_str});
}

test "MAYA core" {
    // Add core tests here
    try std.testing.expect(true);
} 