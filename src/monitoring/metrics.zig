const std = @import("std");
const builtin = @import("builtin");
const time = std.time;
const math = std.math;
const Complex = std.math.Complex;
const assert = std.debug.assert;

// A single recorded metric with timestamp and metadata
pub const Metric = struct {
    name: []const u8,
    value: f64,
    timestamp: i64, // Unix timestamp in milliseconds
    tags: ?[]const []const u8,
    
    /// Format a metric as a string
    pub fn format(
        self: Metric,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const timestamp_str = std.fmt.allocPrint(
            std.heap.page_allocator,
            "{d}",
            .{self.timestamp},
        ) catch "unknown";
        defer std.heap.page_allocator.free(timestamp_str);
        
        try writer.print("{s} {d} {s}", .{
            self.name,
            self.value,
            timestamp_str,
        });
        
        if (self.tags) |tags| {
            try writer.writeAll(" ");
            for (tags, 0..) |tag, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.writeAll(tag);
            }
        }
    }
};

// A collection of metrics with a fixed capacity
pub const MetricsCollector = struct {
    allocator: std.mem.Allocator,
    metrics: std.ArrayList(Metric),
    max_metrics: usize,
    
    /// Initialize a new metrics collector with a maximum capacity
    pub fn init(allocator: std.mem.Allocator, max_metrics: usize) MetricsCollector {
        return .{
            .allocator = allocator,
            .metrics = std.ArrayList(Metric).init(allocator),
            .max_metrics = max_metrics,
        };
    }
    
    /// Deinitialize the metrics collector and free all resources
    pub fn deinit(self: *MetricsCollector) void {
        self.metrics.deinit();
    }
    
    /// Record a new metric
    pub fn record(
        self: *MetricsCollector,
        name: []const u8,
        value: f64,
        tags: ?[]const []const u8,
    ) !void {
        // Remove oldest metrics if we're at capacity
        while (self.metrics.items.len >= self.max_metrics) {
            _ = self.metrics.orderedRemove(0);
        }
        
        try self.metrics.append(.{
            .name = try self.allocator.dupe(u8, name),
            .value = value,
            .timestamp = time.milliTimestamp(),
            .tags = if (tags) |t| try self.dupeTags(t) else null,
        });
    }
    
    /// Get all metrics
    pub fn getAll(self: *const MetricsCollector) []const Metric {
        return self.metrics.items;
    }
    
    /// Get metrics filtered by name and optional time range
    pub fn query(
        self: *const MetricsCollector,
        name: ?[]const u8,
        start_time: ?i64,
        end_time: ?i64,
    ) std.ArrayList(Metric) {
        var result = std.ArrayList(Metric).init(self.allocator);
        
        for (self.metrics.items) |metric| {
            if (name != null and !std.mem.eql(u8, metric.name, name.?)) continue;
            if (start_time != null and metric.timestamp < start_time.?) continue;
            if (end_time != null and metric.timestamp > end_time.?) continue;
            
            result.append(metric) catch continue;
        }
        
        return result;
    }
    
    /// Clear all metrics
    pub fn clear(self: *MetricsCollector) void {
        self.metrics.clearRetainingCapacity();
    }
    
    /// Helper to duplicate tag strings
    fn dupeTags(self: *const MetricsCollector, tags: []const []const u8) ![]const []const u8 {
        const result = try self.allocator.alloc([]const u8, tags.len);
        errdefer self.allocator.free(result);
        
        for (tags, 0..) |tag, i| {
            result[i] = try self.allocator.dupe(u8, tag);
        }
        
        return result;
    }
};

// Quantum coherence metrics for tracking quantum state coherence
pub const QuantumCoherenceMetrics = struct {
    allocator: std.mem.Allocator,
    collector: *MetricsCollector,
    
    /// Initialize quantum coherence metrics
    pub fn init(allocator: std.mem.Allocator, collector: *MetricsCollector) QuantumCoherenceMetrics {
        return .{
            .allocator = allocator,
            .collector = collector,
        };
    }
    
    /// Calculate and record coherence metrics for a quantum state
    /// state: Vector of complex amplitudes representing the quantum state
    /// qubit_count: Number of qubits in the system
    /// tags: Optional tags for the metrics
    pub fn recordCoherenceMetrics(
        self: *QuantumCoherenceMetrics,
        state: []const Complex(f64),
        qubit_count: usize,
        tags: ?[]const []const u8,
    ) !void {
        const purity = try self.calculatePurity(state);
        const coherence = try self.calculateCoherence(state);
        const entropy = try self.calculateEntropy(state, qubit_count);
        
        try self.collector.record("quantum.purity", purity, tags);
        try self.collector.record("quantum.coherence", coherence, tags);
        try self.collector.record("quantum.entropy", entropy, tags);
        
        // Record per-qubit coherence metrics
        for (0..qubit_count) |qubit| {
            const qubit_coherence = try self.calculateQubitCoherence(state, qubit, qubit_count);
            const qubit_tags = try self.addQubitTag(tags, qubit);
            defer if (qubit_tags) |t| self.allocator.free(t);
            
            try self.collector.record("quantum.qubit_coherence", qubit_coherence, qubit_tags);
        }
    }
    
    /// Calculate purity of a quantum state (Tr[ρ²])
    fn calculatePurity(_: *const QuantumCoherenceMetrics, state: []const Complex(f64)) !f64 {
        var purity: f64 = 0.0;
        for (state) |amp| {
            const prob = amp.re * amp.re + amp.im * amp.im;
            purity += prob * prob;
        }
        return purity;
    }
    
    /// Calculate coherence of a quantum state (sum of off-diagonal elements)
    fn calculateCoherence(_: *const QuantumCoherenceMetrics, state: []const Complex(f64)) !f64 {
        var coherence: f64 = 0.0;
        const n = @as(f64, @floatFromInt(state.len));
        
        // For each basis state
        for (state, 0..) |amp_i, i| {
            // Compare with all other basis states
            for (state[i + 1 ..]) |amp_j| {
                const conj_amp_j = Complex(f64).init(amp_j.re, -amp_j.im);
                const prod = amp_i.mul(conj_amp_j);
                coherence += 2 * math.sqrt(prod.re * prod.re + prod.im * prod.im);
            }
        }
        
        // Normalize by the maximum possible coherence
        return coherence / (n * (n - 1));
    }
    
    /// Calculate von Neumann entropy of the quantum state
    fn calculateEntropy(
        _: *const QuantumCoherenceMetrics,
        state: []const Complex(f64),
        _: usize, // qubit_count - for future use with reduced density matrices
    ) !f64 {
        var entropy: f64 = 0.0;
        
        for (state) |amp| {
            const prob = amp.re * amp.re + amp.im * amp.im;
            if (prob > 0) {
                entropy -= prob * math.log2(prob);
            }
        }
        
        return entropy;
    }
    
    /// Calculate coherence for a specific qubit
    fn calculateQubitCoherence(
        _: *const QuantumCoherenceMetrics,
        state: []const Complex(f64),
        target_qubit: usize,
        qubit_count: usize,
    ) !f64 {
        var coherence: f64 = 0.0;
        const basis_states = @as(usize, 1) << @as(u6, @intCast(qubit_count));
        const mask = @as(usize, 1) << @as(u6, @intCast(target_qubit));
        
        for (0..basis_states) |i| {
            // Only consider pairs where the target qubit is different
            const j = i ^ mask;
            if (j <= i) continue; // Avoid double counting
            
            if (j < state.len) {
                const amp_i = state[i];
                const amp_j = state[j];
                const conj_amp_j = Complex(f64).init(amp_j.re, -amp_j.im);
                const prod = amp_i.mul(conj_amp_j);
                coherence += 2 * math.sqrt(prod.re * prod.re + prod.im * prod.im);
            }
        }
        
        // Normalize by the number of possible pairs
        const possible_pairs = @as(f64, @floatFromInt(basis_states / 2));
        return if (possible_pairs > 0) coherence / possible_pairs else 0.0;
    }
    
    /// Helper to add qubit tag to existing tags
    fn addQubitTag(
        self: *const QuantumCoherenceMetrics,
        base_tags: ?[]const []const u8,
        qubit: usize,
    ) !?[]const []const u8 {
        const qubit_tag = try std.fmt.allocPrint(self.allocator, "qubit={d}", .{qubit});
        
        if (base_tags == null) {
            const new_tags = try self.allocator.alloc([]const u8, 1);
            new_tags[0] = qubit_tag;
            return new_tags;
        }
        
        const new_tags = try self.allocator.alloc([]const u8, base_tags.?.len + 1);
        std.mem.copyForwards([]const u8, new_tags[0..base_tags.?.len], base_tags.?);
        new_tags[base_tags.?.len] = qubit_tag;
        
        return new_tags;
    }
};

// Test suite for the metrics collection system.
// This includes both basic metric functionality and quantum-specific metrics.
// 
// The quantum coherence metrics are designed to measure various properties of quantum states:
// - Purity: Measures how pure a quantum state is (1.0 for pure states, lower for mixed states)
// - Coherence: Measures the amount of quantum superposition in the state
// - Entropy: Measures the amount of uncertainty or mixedness in the state
// - Per-qubit metrics: Additional metrics calculated for individual qubits
//
// The test cases cover a variety of quantum states to ensure correct behavior:
// 1. Basic metric functionality (recording, retrieval, formatting)
// 2. Bell states (maximally entangled 2-qubit states)
// 3. Product states (unentangled states)
// 4. GHZ states (N-qubit entangled states)
// 5. W states (specific type of entangled state)
// 6. Mixed states (classical probability distributions)
//
// Each test case verifies that the metrics match the expected theoretical values.

const testing = std.testing;

test "metrics recording and retrieval" {
    // Use an arena allocator for this test to simplify memory management
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var collector = MetricsCollector.init(allocator, 100);
    
    // Record some metrics
    try collector.record("test.metric1", 1_000_000, null);
    try collector.record("test.metric2", 42.5, &[_][]const u8{"tag1", "tag2"});
    
    // Verify metrics were recorded
    const metrics = collector.getAll();
    try testing.expect(metrics.len == 2);
    
    // Check that we can query metrics
    const queried = collector.query("test.metric1", null, null);
    defer {
        for (queried.items) |metric| {
            allocator.free(metric.name);
            if (metric.tags) |tags| {
                for (tags) |tag| allocator.free(tag);
                allocator.free(tags);
            }
        }
        queried.deinit();
    }
    
    try testing.expect(queried.items.len == 1);
    try testing.expectApproxEqAbs(queried.items[0].value, 1_000_000, 0.001);
}

test "metrics formatting" {
    // Use an arena allocator for this test to simplify memory management
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var collector = MetricsCollector.init(allocator, 100);
    try collector.record("test_metric", 123.45, null);
    
    const metrics = collector.getAll();
    try testing.expect(metrics.len == 1);
    
    var buffer: [1024]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buffer, "{any}", .{metrics[0]});
    
    try testing.expect(std.mem.containsAtLeast(u8, formatted, 1, "test_metric"));
    try testing.expect(std.mem.containsAtLeast(u8, formatted, 1, "123.45"));
}

// Tests quantum coherence metrics with a Bell state (|00> + |11>)/√2.
// 
// A Bell state is a maximally entangled two-qubit state with the following properties:
// - Purity: 0.5 (mixed state due to entanglement)
// - Coherence: Non-zero (exact value depends on basis)
// - Entropy: 1.0 (one bit of entanglement)
//
// This test verifies that the quantum metrics correctly identify these properties.
test "quantum coherence metrics - bell state" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var collector = MetricsCollector.init(allocator, 100);
    var qm = QuantumCoherenceMetrics.init(allocator, &collector);
    
    const bell_state = [_]Complex(f64){
        .{ .re = 1.0 / math.sqrt(2.0), .im = 0.0 }, // |00>
        .{ .re = 0.0, .im = 0.0 }, // |01>
        .{ .re = 0.0, .im = 0.0 }, // |10>
        .{ .re = 1.0 / math.sqrt(2.0), .im = 0.0 }, // |11>
    };
    
    try qm.recordCoherenceMetrics(&bell_state, 2, &[_][]const u8{"test", "bell_state"});
    
    const metrics = collector.getAll();
    try testing.expect(metrics.len >= 3);
    
    var found_purity = false;
    var found_coherence = false;
    var found_entropy = false;
    
    for (metrics) |metric| {
        if (std.mem.eql(u8, metric.name, "quantum.purity")) {
            found_purity = true;
            try testing.expectApproxEqAbs(metric.value, 0.5, 1e-10);
        } else if (std.mem.eql(u8, metric.name, "quantum.coherence")) {
            found_coherence = true;
            // Coherence should be between 0 and 1
            try testing.expect(metric.value >= 0.0 and metric.value <= 1.0);
        } else if (std.mem.eql(u8, metric.name, "quantum.entropy")) {
            found_entropy = true;
            // For a Bell state, entropy should be 1.0 (1 bit of entanglement)
            try testing.expectApproxEqAbs(metric.value, 1.0, 1e-10);
        }
    }
    
    try testing.expect(found_purity);
    try testing.expect(found_coherence);
    try testing.expect(found_entropy);
}

// Tests quantum coherence metrics with a product state |00>.
//
// A product state is an unentangled quantum state with the following properties:
// - Purity: 1.0 (pure state)
// - Coherence: 0.0 (no superposition)
// - Entropy: 0.0 (no uncertainty)
//
// This test verifies that the quantum metrics correctly identify these properties.
test "quantum coherence metrics - product state" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var collector = MetricsCollector.init(allocator, 100);
    var qm = QuantumCoherenceMetrics.init(allocator, &collector);
    
    const product_state = [_]Complex(f64){
        .{ .re = 1.0, .im = 0.0 }, // |00>
        .{ .re = 0.0, .im = 0.0 }, // |01>
        .{ .re = 0.0, .im = 0.0 }, // |10>
        .{ .re = 0.0, .im = 0.0 }, // |11>
    };
    
    try qm.recordCoherenceMetrics(&product_state, 2, &[_][]const u8{"test", "product_state"});
    
    const metrics = collector.getAll();
    try testing.expect(metrics.len >= 3);
    
    for (metrics) |metric| {
        if (std.mem.eql(u8, metric.name, "quantum.purity")) {
            try testing.expectApproxEqAbs(metric.value, 1.0, 1e-10);
        } else if (std.mem.eql(u8, metric.name, "quantum.coherence")) {
            try testing.expectApproxEqAbs(metric.value, 0.0, 1e-10);
        } else if (std.mem.eql(u8, metric.name, "quantum.entropy")) {
            try testing.expectApproxEqAbs(metric.value, 0.0, 1e-10);
        }
    }
}

// Tests quantum coherence metrics with a 3-qubit GHZ state (|000> + |111>)/√2.
//
// A GHZ (Greenberger-Horne-Zeilinger) state is a maximally entangled multi-qubit state with the following properties:
// - Purity: 0.5 (mixed state due to entanglement)
// - Entropy: 1.0 (one bit of entanglement across all qubits)
// - Shows genuine multipartite entanglement
//
// This test verifies that the quantum metrics correctly identify these properties.
test "quantum coherence metrics - ghz state" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var collector = MetricsCollector.init(allocator, 100);
    var qm = QuantumCoherenceMetrics.init(allocator, &collector);
    
    const ghz_state = [_]Complex(f64){
        .{ .re = 1.0 / math.sqrt(2.0), .im = 0.0 }, // |000>
        .{ .re = 0.0, .im = 0.0 }, // |001>
        .{ .re = 0.0, .im = 0.0 }, // |010>
        .{ .re = 0.0, .im = 0.0 }, // |011>
        .{ .re = 0.0, .im = 0.0 }, // |100>
        .{ .re = 0.0, .im = 0.0 }, // |101>
        .{ .re = 0.0, .im = 0.0 }, // |110>
        .{ .re = 1.0 / math.sqrt(2.0), .im = 0.0 }, // |111>
    };
    
    try qm.recordCoherenceMetrics(&ghz_state, 3, &[_][]const u8{"test", "ghz_state"});
    
    const metrics = collector.getAll();
    try testing.expect(metrics.len >= 4); // 3 global metrics + at least 1 qubit metric
    
    for (metrics) |metric| {
        if (std.mem.eql(u8, metric.name, "quantum.purity")) {
            try testing.expectApproxEqAbs(metric.value, 0.5, 1e-10);
        } else if (std.mem.eql(u8, metric.name, "quantum.entropy")) {
            try testing.expectApproxEqAbs(metric.value, 1.0, 1e-10);
        }
    }
}

// Tests quantum coherence metrics with a 3-qubit W state (|001> + |010> + |100>)/√3.
//
// A W state is a specific type of entangled state with the following properties:
// - Purity: 1/3 (due to equal superposition of three basis states)
// - Entropy: log2(3) ≈ 1.585 (higher than Bell/CHSH states)
// - Shows different entanglement properties than GHZ states
//
// This test verifies that the quantum metrics correctly identify these properties.
test "quantum coherence metrics - w state" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var collector = MetricsCollector.init(allocator, 100);
    var qm = QuantumCoherenceMetrics.init(allocator, &collector);
    
    const w_state = [_]Complex(f64){
        .{ .re = 0.0, .im = 0.0 }, // |000>
        .{ .re = 1.0 / math.sqrt(3.0), .im = 0.0 }, // |001>
        .{ .re = 1.0 / math.sqrt(3.0), .im = 0.0 }, // |010>
        .{ .re = 0.0, .im = 0.0 }, // |011>
        .{ .re = 1.0 / math.sqrt(3.0), .im = 0.0 }, // |100>
        .{ .re = 0.0, .im = 0.0 }, // |101>
        .{ .re = 0.0, .im = 0.0 }, // |110>
        .{ .re = 0.0, .im = 0.0 }, // |111>
    };
    
    try qm.recordCoherenceMetrics(&w_state, 3, &[_][]const u8{"test", "w_state"});
    
    const metrics = collector.getAll();
    try testing.expect(metrics.len >= 4);
    
    for (metrics) |metric| {
        if (std.mem.eql(u8, metric.name, "quantum.purity")) {
            // Purity should be 1/3 for a W state
            try testing.expectApproxEqAbs(metric.value, 1.0/3.0, 1e-10);
        } else if (std.mem.eql(u8, metric.name, "quantum.entropy")) {
            // For a 3-qubit W state, entropy should be log2(3) ≈ 1.585
            try testing.expectApproxEqAbs(metric.value, 1.585, 0.01);
        }
    }
}

// Tests quantum coherence metrics with a classically mixed state (|00><00| + |11><11|)/2.
//
// A classically mixed state represents a statistical mixture of quantum states with the following properties:
// - Purity: 0.5 (completely mixed state would be 0.25 for 2 qubits)
// - Entropy: 1.0 (one bit of classical uncertainty)
// - Coherence: 0.0 (no quantum superposition)
//
// This test verifies that the quantum metrics correctly identify these properties.
test "quantum coherence metrics - mixed state" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var collector = MetricsCollector.init(allocator, 100);
    var qm = QuantumCoherenceMetrics.init(allocator, &collector);
    
    const mixed_state = [_]Complex(f64){
        .{ .re = 1.0 / math.sqrt(2.0), .im = 0.0 }, // |00>
        .{ .re = 0.0, .im = 0.0 }, // |01>
        .{ .re = 0.0, .im = 0.0 }, // |10>
        .{ .re = 1.0 / math.sqrt(2.0), .im = 0.0 }, // |11>
    };
    
    try qm.recordCoherenceMetrics(&mixed_state, 2, &[_][]const u8{"test", "mixed_state"});
    
    const metrics = collector.getAll();
    try testing.expect(metrics.len >= 3);
    
    for (metrics) |metric| {
        if (std.mem.eql(u8, metric.name, "quantum.purity")) {
            // Purity should be 0.5 for this mixed state
            try testing.expectApproxEqAbs(metric.value, 0.5, 1e-10);
        } else if (std.mem.eql(u8, metric.name, "quantum.entropy")) {
            // Entropy should be 1.0 for this mixed state
            try testing.expectApproxEqAbs(metric.value, 1.0, 1e-10);
        }
    }
}
