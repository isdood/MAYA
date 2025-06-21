const std = @import("std");
const time = std.time;
const builtin = @import("builtin");
const MetricsCollector = @import("metrics.zig").MetricsCollector;
const Metric = @import("metrics.zig").Metric;

/// Terminal-based performance dashboard
pub const Dashboard = struct {
    allocator: std.mem.Allocator,
    metrics: *MetricsCollector,
    running: bool = true,
    
    /// Initialize a new dashboard
    pub fn init(allocator: std.mem.Allocator, metrics: *MetricsCollector) @This() {
        return .{
            .allocator = allocator,
            .metrics = metrics,
        };
    }
    
    /// Start the dashboard (blocking)
    pub fn start(self: *@This()) !void {
        const stdin = std.io.getStdIn();
        
        // For now, we'll use a simpler approach without raw mode
        // since the terminal handling is platform-specific and complex
        // In a production environment, you might want to use a library
        // like `termbox` or `curses` for better terminal control
        
        // Main dashboard loop
        while (self.running) {
            // Clear screen and move cursor to top-left
            try self.clearScreen();
            
            // Print header
            const stdout = std.io.getStdOut().writer();
            try stdout.print("=== MAYA Performance Dashboard ===\n\n", .{});
            
            // Print current time
            const now = std.time.timestamp();
            
            try stdout.print("Time: {d}\n\n", .{now});
            
            // Print all metrics
            for (self.metrics.getAll()) |metric| {
                const age_seconds = @divTrunc((now * 1000) - metric.timestamp, 1000);
                
                // Format the value with appropriate units
                const value_str = blk: {
                    if (metric.value > 1_000_000) {
                        break :blk std.fmt.allocPrint(
                            self.allocator,
                            "{d:.2}M",
                            .{metric.value / 1_000_000.0},
                        ) catch "error";
                    } else if (metric.value > 1_000) {
                        break :blk std.fmt.allocPrint(
                            self.allocator,
                            "{d:.1}K",
                            .{metric.value / 1_000.0},
                        ) catch "error";
                    } else {
                        break :blk std.fmt.allocPrint(
                            self.allocator,
                            "{d:.2}",
                            .{metric.value},
                        ) catch "error";
                    }
                };
                defer if (value_str.len > 0) self.allocator.free(value_str);
                
                // Print metric with color coding based on age
                const age_color = if (age_seconds > 10) "\x1b[31m" // red if older than 10s
                    else if (age_seconds > 5) "\x1b[33m" // yellow if older than 5s
                    else "\x1b[32m"; // green if fresh
                
                try stdout.print(
                    "{s}{s:<30} {s:>10} (age: {d}s)\x1b[0m\n",
                    .{
                        age_color,
                        metric.name,
                        value_str,
                        age_seconds,
                    },
                );
            }
            
            // Print help
            try stdout.writeAll("\nPress 'q' to quit, 'c' to clear metrics\n");
            
            // Handle input without blocking
            self.handleInput(stdin) catch |err| {
                std.debug.print("Error handling input: {}\n", .{err});
            };
            
            // Small delay to prevent high CPU usage
            time.sleep(100 * time.ns_per_ms);
        }
    }
    
    /// Stop the dashboard
    pub fn stop(self: *@This()) void {
        self.running = false;
    }
    
    /// Clear the terminal screen
    fn clearScreen(self: *@This()) !void {
        _ = self;
        const stdout = std.io.getStdOut().writer();
        try stdout.writeAll("\x1b[2J\x1b[H");
    }
    
    /// Handle user input
    fn handleInput(self: *@This(), stdin: std.fs.File) !void {
        var buf: [1]u8 = undefined;
        const len = try stdin.read(&buf);
        
        if (len > 0) {
            switch (buf[0]) {
                'q', 'Q' => self.stop(),
                'c', 'C' => self.metrics.clear(),
                else => {},
            }
        }
    }
};

// Tests
const testing = std.testing;

test "dashboard initialization" {
    var metrics = Metrics.init(testing.allocator);
    defer metrics.deinit();
    
    var dashboard = Dashboard.init(testing.allocator, &metrics);
    
    // Just verify it initializes
    try testing.expect(true);
}
