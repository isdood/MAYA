@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 13:30:48",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/starweave/retry.zig",
    "type": "zig",
    "hash": "1ab3259b225f8b17639fee3ea868394733d8af8c"
  }
}
@pattern_meta@

const std = @import("std");
const time = std.time;
const math = std.math;
const Allocator = std.mem.Allocator;

/// Retry configuration for operations that might fail temporarily
pub const RetryConfig = struct {
    /// Maximum number of retry attempts (0 means no retry)
    max_attempts: u32 = 3,
    
    /// Initial delay between retries in nanoseconds
    initial_delay_ns: u64 = 100 * time.ns_per_ms,
    
    /// Maximum delay between retries in nanoseconds
    max_delay_ns: u64 = 10 * time.ns_per_s,
    
    /// Exponential backoff factor (e.g., 2.0 for exponential backoff)
    backoff_factor: f64 = 2.0,
    
    /// Jitter factor (0.0 to 1.0) to add randomness to delays
    jitter_factor: f64 = 0.1,
    
    /// Timeout for the entire operation (0 for no timeout)
    timeout_ns: u64 = 0,
    
    /// Function to determine if an error is retryable
    is_retryable: ?*const fn(anyerror) bool = null,
};

/// Result of a retry operation
pub fn RetryResult(comptime T: type) type {
    return struct {
        value: T,
        attempts: u32,
        total_delay_ns: u64,
    };
}

/// Retry a function until it succeeds or the maximum attempts are reached
pub fn withRetry(
    comptime F: type,
    config: RetryConfig,
    context: anytype,
    func: F,
) !RetryResult(@typeInfo(@TypeOf(@field(F, "function"))).Fn.return_type.?) {
    const ReturnType = @typeInfo(@TypeOf(@field(F, "function"))).Fn.return_type.?;
    
    var attempt: u32 = 0;
    var total_delay: u64 = 0;
    const start_time = time.nanoTimestamp();
    
    while (true) {
        attempt += 1;
        
        // Check if we've exceeded the timeout
        if (config.timeout_ns > 0) {
            const elapsed = @as(u64, @intCast(@max(0, time.nanoTimestamp() - start_time)));
            if (elapsed >= config.timeout_ns) {
                return error.Timeout;
            }
        }
        
        // Execute the function
        const result = func(context);
        
        // If successful, return the result
        if (result) |value| {
            return RetryResult(ReturnType){
                .value = value,
                .attempts = attempt,
                .total_delay_ns = total_delay,
            };
        } else |err| {
            // Check if we should retry
            if (attempt >= config.max_attempts) {
                return error.MaxRetriesExceeded;
            }
            
            // Check if error is retryable
            if (config.is_retryable) |is_retryable| {
                if (!is_retryable(err)) {
                    return err;
                }
            }
            
            // Calculate delay with exponential backoff and jitter
            const base_delay = @as(u64, @intFromFloat(
                @min(
                    @as(f64, @floatFromInt(config.max_delay_ns)),
                    @as(f64, @floatFromInt(config.initial_delay_ns)) * 
                        std.math.pow(f64, config.backoff_factor, @as(f64, @floatFromInt(attempt - 1)))
                )
            ));
            
            // Add jitter
            const jitter_range = @as(u64, @intFromFloat(
                @as(f64, @floatFromInt(base_delay)) * config.jitter_factor
            ));
            const jitter = if (jitter_range > 0) 
                std.crypto.random.intRangeAtMost(u64, 0, jitter_range) 
            else 0;
            
            const delay = base_delay + jitter;
            
            // Sleep for the calculated delay
            time.sleep(delay);
            total_delay += delay;
        }
    }
}

/// Default retry configuration for network operations
pub const defaultNetworkRetryConfig = RetryConfig{
    .max_attempts = 5,
    .initial_delay_ns = 100 * time.ns_per_ms,
    .max_delay_ns = 5 * time.ns_per_s,
    .backoff_factor = 2.0,
    .jitter_factor = 0.2,
    .timeout_ns = 30 * time.ns_per_s,
};

/// Default retry configuration for database operations
pub const defaultDatabaseRetryConfig = RetryConfig{
    .max_attempts = 3,
    .initial_delay_ns = 50 * time.ns_per_ms,
    .max_delay_ns = 2 * time.ns_per_s,
    .backoff_factor = 1.5,
    .jitter_factor = 0.1,
    .timeout_ns = 10 * time.ns_per_s,
};

test "retry with success on first attempt" {
    var counter: u32 = 0;
    
    const result = try withRetry(
        @TypeOf(struct {
            fn f(_: *u32) anyerror!u32 { return 42; }
        }.f),
        .{},
        &counter,
        struct {
            fn f(ctx: *u32) anyerror!u32 {
                _ = ctx;
                return 42;
            }
        }.f,
    );
    
    try std.testing.expectEqual(@as(u32, 42), result.value);
    try std.testing.expectEqual(@as(u32, 1), result.attempts);
    try std.testing.expectEqual(@as(u64, 0), result.total_delay_ns);
}

test "retry with eventual success" {
    var counter: u32 = 0;
    
    const result = try withRetry(
        @TypeOf(struct {
            fn f(_: *u32) u32 { return 0; }
        }.f),
        .{ .max_attempts = 3, .initial_delay_ns = 1, .max_delay_ns = 10 },
        &counter,
        struct {
            fn f(ctx: *u32) anyerror!u32 {
                ctx.* += 1;
                if (ctx.* < 3) return error.TempFailure;
                return 42;
            }
        }.f,
    );
    
    try std.testing.expectEqual(@as(u32, 42), result.value);
    try std.testing.expectEqual(@as(u32, 3), result.attempts);
    try std.testing.expect(result.total_delay_ns > 0);
}

test "retry with max attempts exceeded" {
    var counter: u32 = 0;
    
    const result = withRetry(
        @TypeOf(struct {
            fn f(_: *u32) u32 { return 0; }
        }.f),
        .{ .max_attempts = 3, .initial_delay_ns = 1 },
        &counter,
        struct {
            fn f(_: *u32) anyerror!u32 {
                return error.PersistentFailure;
            }
        }.f,
    );
    
    try std.testing.expectError(error.MaxRetriesExceeded, result);
}

test "retry with timeout" {
    var counter: u32 = 0;
    
    const result = withRetry(
        @TypeOf(struct {
            fn f(_: *u32) u32 { return 0; }
        }.f),
        .{ 
            .max_attempts = 100,
            .initial_delay_ns = 10 * time.ns_per_ms,
            .timeout_ns = 1 * time.ns_per_ms,
        },
        &counter,
        struct {
            fn f(_: *u32) anyerror!u32 {
                return error.TempFailure;
            }
        }.f,
    );
    
    try std.testing.expectError(error.Timeout, result);
}
