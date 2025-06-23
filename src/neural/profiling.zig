//! Performance profiling and metrics collection for MAYA
//! This module provides tools for measuring and analyzing performance characteristics
//! of the neural pattern processing system.

const std = @import("std");
const builtin = @import("builtin");
const time = std.time;
const Thread = std.Thread;

/// A single timing measurement
pub const Timer = struct {
    name: []const u8,
    start: i128,
    end: ?i128 = null,
    parent: ?*Timer = null,
    children: std.ArrayListUnmanaged(*Timer) = .{},
    allocator: std.mem.Allocator,

    /// Start a new timer with the given name
    pub fn start(allocator: std.mem.Allocator, name: []const u8) !*Timer {
        const timer = try allocator.create(Timer);
        timer.* = .{
            .name = name,
            .start = time.nanoTimestamp(),
            .allocator = allocator,
        };
        return timer;
    }

    /// Stop the timer
    pub fn stop(self: *Timer) void {
        self.end = time.nanoTimestamp();
    }

    /// Get the duration in nanoseconds
    pub fn duration(self: Timer) i128 {
        const end = self.end orelse time.nanoTimestamp();
        return end - self.start;
    }

    /// Get the duration in milliseconds
    pub fn durationMs(self: Timer) f64 {
        return @as(f64, @floatFromInt(self.duration())) / 1_000_000.0;
    }

    /// Add a child timer
    pub fn addChild(self: *Timer, child: *Timer) !void {
        child.parent = self;
        try self.children.append(self.allocator, child);
    }

    /// Create and start a new child timer
    pub fn startChild(self: *Timer, name: []const u8) !*Timer {
        const child = try Timer.start(self.allocator, name);
        try self.addChild(child);
        return child;
    }

    /// Free all resources associated with this timer and its children
    pub fn deinit(self: *Timer) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }
};

/// A simple scope-based timer that automatically records duration when it goes out of scope
pub const ScopeTimer = struct {
    timer: *Timer,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !@This() {
        return .{
            .timer = try Timer.start(allocator, name),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.timer.stop();
        self.allocator.destroy(self.timer);
    }
};

/// Global profiler state
var profiler: ?Profiler = null;
var profiler_mutex: Thread.Mutex = .{};

/// A profiler that collects timing information
pub const Profiler = struct {
    allocator: std.mem.Allocator,
    root_timer: *Timer,
    current_timer: *Timer,

    /// Initialize a new profiler
    pub fn init(allocator: std.mem.Allocator) !*@This() {
        const self = try allocator.create(@This());
        self.allocator = allocator;
        self.root_timer = try Timer.start(allocator, "root");
        self.current_timer = self.root_timer;
        return self;
    }

    /// Start a new timing section
    pub fn beginSection(self: *@This(), name: []const u8) !void {
        const timer = try self.current_timer.startChild(name);
        self.current_timer = timer;
    }

    /// End the current timing section
    pub fn endSection(self: *@This()) void {
        if (self.current_timer.parent) |parent| {
            self.current_timer.stop();
            self.current_timer = parent;
        }
    }

    /// Print a summary of all timings
    pub fn printSummary(self: *const @This(), writer: anytype) !void {
        try writer.print("\n=== Performance Summary ===\n", .{});
        try self.printTimer(writer, self.root_timer, 0);
        try writer.print("==========================\n\n", .{});
    }

    fn printTimer(self: *const @This(), writer: anytype, timer: *const Timer, level: usize) !void {
        // Print indentation
        for (0..level) |_| try writer.writeAll("  ");
        
        // Print timer info
        try writer.print("{s}: {d:.3}ms", .{ timer.name, timer.durationMs() });
        
        // Print percentage of parent if available
        if (timer.parent) |parent| {
            const percentage = (@as(f64, @floatFromInt(timer.duration())) / 
                             @as(f64, @floatFromInt(parent.duration()))) * 100.0;
            try writer.print(" ({d:.1}%)", .{percentage});
        }
        
        try writer.writeAll("\n");
        
        // Print children
        for (timer.children.items) |child| {
            try self.printTimer(writer, child, level + 1);
        }
    }

    /// Free all resources
    pub fn deinit(self: *@This()) void {
        self.root_timer.deinit();
        self.allocator.destroy(self.root_timer);
        self.allocator.destroy(self);
    }
};

/// Initialize the global profiler
pub fn initProfiler(allocator: std.mem.Allocator) !void {
    profiler_mutex.lock();
    defer profiler_mutex.unlock();
    
    if (profiler == null) {
        profiler = Profiler.init(allocator) catch |err| {
            std.debug.print("Failed to initialize profiler: {}\n", .{err});
            return error.ProfilerInitFailed;
        };
    }
}

/// Begin a profiling section
pub fn beginSection(name: []const u8) void {
    profiler_mutex.lock();
    defer profiler_mutex.unlock();
    
    if (profiler) |*p| {
        p.beginSection(name) catch |err| {
            std.debug.print("Failed to begin section '{}': {}\n", .{name, err});
        };
    }
}

/// End the current profiling section
pub fn endSection() void {
    profiler_mutex.lock();
    defer profiler_mutex.unlock();
    
    if (profiler) |*p| {
        p.endSection();
    }
}

/// Print the profiling summary
pub fn printSummary(writer: anytype) !void {
    profiler_mutex.lock();
    defer profiler_mutex.unlock();
    
    if (profiler) |*p| {
        try p.printSummary(writer);
    }
}

/// Deinitialize the global profiler
pub fn deinitProfiler() void {
    profiler_mutex.lock();
    defer profiler_mutex.unlock();
    
    if (profiler) |*p| {
        p.deinit();
        profiler = null;
    }
}

/// A scope-based profiler section
pub const ProfileSection = struct {
    pub fn init(name: []const u8) @This() {
        beginSection(name);
        return .{};
    }

    pub fn deinit(self: *@This()) void {
        _ = self; // Unused
        endSection();
    }
};

// Compile-time check to enable/disable profiling
pub const enabled = @import("build_options").enable_profiling;

// Test the profiling system
test "profiling" {
    if (!enabled) return error.SkipZigTest;
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    try initProfiler(arena.allocator());
    
    // Simple timing test
    {
        var timer = try Timer.start(arena.allocator(), "test_timer");
        std.time.sleep(10_000_000); // 10ms
        timer.stop();
        
        const duration = timer.duration();
        try std.testing.expect(duration >= 10_000_000);
    }
    
    // Scope timer test
    {
        var scope_timer = try ScopeTimer.init(arena.allocator(), "scope_timer");
        defer scope_timer.deinit();
        std.time.sleep(5_000_000); // 5ms
    }
    
    // Section test
    {
        beginSection("test_section");
        defer endSection();
        std.time.sleep(2_000_000); // 2ms
    }
    
    // Print summary
    try printSummary(std.io.getStdErr().writer());
}
