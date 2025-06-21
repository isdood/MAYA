const std = @import("std");

// Mock QuantumProcessor
pub const MockQuantumProcessor = struct {
    pub const QuantumState = struct {
        pub fn measure(self: *@This(), _: u8) bool {
            _ = self;
            return true; // Always return true for testing
        }
    };

    pub fn init(_: std.mem.Allocator, _: struct {}) !@This() {
        return .{};
    }

    pub fn deinit(_: *@This()) void {}

    pub fn createState(_: *@This()) !*QuantumState {
        return &(QuantumState{});
    }
};

// Mock VisualProcessor
pub const MockVisualProcessor = struct {
    pub fn init(_: std.mem.Allocator, _: struct {}) !@This() {
        return .{};
    }

    pub fn deinit(_: *@This()) void {}

    pub fn processPattern(_: *@This(), _: []const u8) !f64 {
        return 0.95; // Return high confidence for testing
    }
};

// Mock NeuralProcessor
pub const MockNeuralProcessor = struct {
    pub fn init(_: std.mem.Allocator, _: struct {}) !@This() {
        return .{};
    }

    pub fn deinit(_: *@This()) void {}

    pub fn analyzePattern(_: *@This(), _: []const u8) !f64 {
        return 0.9; // Return high confidence for testing
    }
};
