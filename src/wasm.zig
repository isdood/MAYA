const std = @import("std");
const glimmer = @import("glimmer");
const neural = @import("neural");
const starweave = @import("starweave");

// Define initial and maximum buffer sizes
const INITIAL_BUFFER_SIZE = 1024;
const MAX_BUFFER_SIZE = 1024 * 1024; // 1MB max

// Error codes
const ErrorCode = enum(u32) {
    Success = 0,
    BufferTooSmall = 1,
    InvalidInput = 2,
    MemoryAllocationFailed = 3,
    PatternError = 4,
};

// Create a dynamic buffer for our data
var buffer: []u8 = undefined;
var buffer_len: usize = 0;
var allocator: std.mem.Allocator = undefined;
var is_initialized: bool = false;

// Create a static zero byte array for null returns
const zero_bytes = [_]u8{0};

// GLIMMER pattern state
var current_pattern: ?glimmer.GlimmerPattern = null;
var pattern_buffer: []u8 = undefined;

export fn init() u32 {
    if (is_initialized) {
        return @intFromEnum(ErrorCode.Success);
    }
    
    // Initialize the allocator
    allocator = std.heap.page_allocator;
    
    // Allocate initial buffer
    buffer = allocator.alloc(u8, INITIAL_BUFFER_SIZE) catch {
        return @intFromEnum(ErrorCode.MemoryAllocationFailed);
    };
    
    // Allocate pattern buffer
    pattern_buffer = allocator.alloc(u8, INITIAL_BUFFER_SIZE) catch {
        allocator.free(buffer);
        return @intFromEnum(ErrorCode.MemoryAllocationFailed);
    };
    
    buffer_len = 0;
    // Clear the buffers
    @memset(buffer, 0);
    @memset(pattern_buffer, 0);
    
    is_initialized = true;
    return @intFromEnum(ErrorCode.Success);
}

export fn process(input_ptr: [*]const u8, input_len: usize) u32 {
    if (!is_initialized) {
        return @intFromEnum(ErrorCode.InvalidInput);
    }
    
    if (input_len == 0) {
        return @intFromEnum(ErrorCode.InvalidInput);
    }
    
    // Check if we need to resize the buffer
    if (input_len > buffer.len) {
        if (input_len > MAX_BUFFER_SIZE) {
            return @intFromEnum(ErrorCode.BufferTooSmall);
        }
        
        // Allocate new buffer
        const new_buffer = allocator.alloc(u8, input_len) catch {
            return @intFromEnum(ErrorCode.MemoryAllocationFailed);
        };
        
        // Copy old data if any
        if (buffer_len > 0) {
            @memcpy(new_buffer[0..buffer_len], buffer[0..buffer_len]);
        }
        
        // Free old buffer
        allocator.free(buffer);
        buffer = new_buffer;
    }
    
    // Clear the buffer first
    @memset(buffer, 0);
    
    // Copy input to our buffer
    @memcpy(buffer[0..input_len], input_ptr[0..input_len]);
    buffer_len = input_len;
    
    // Try to process as a GLIMMER pattern
    if (glimmer.parsePattern(buffer[0..buffer_len])) |pattern| {
        current_pattern = pattern;
        
        // Apply pattern transformation
        if (glimmer.applyPattern(pattern.?, pattern_buffer, allocator)) |transformed| {
            // Copy transformed data back to main buffer
            if (transformed.?.len > buffer.len) {
                const new_buffer = allocator.alloc(u8, transformed.?.len) catch {
                    return @intFromEnum(ErrorCode.MemoryAllocationFailed);
                };
                allocator.free(buffer);
                buffer = new_buffer;
            }
            @memcpy(buffer[0..transformed.?.len], transformed.?);
            buffer_len = transformed.?.len;
        } else |_| {
            return @intFromEnum(ErrorCode.PatternError);
        }
    } else |_| {
        // Not a GLIMMER pattern, process as normal text
        current_pattern = null;
    }
    
    return @intFromEnum(ErrorCode.Success);
}

export fn getResult() [*]const u8 {
    if (!is_initialized or buffer_len == 0) {
        return &zero_bytes;
    }
    return buffer.ptr;
}

// Export the buffer size for JavaScript
export fn getBufferSize() usize {
    if (!is_initialized) {
        return 0;
    }
    return buffer.len;
}

// Export the current length
export fn getLength() usize {
    if (!is_initialized) {
        return 0;
    }
    return buffer_len;
}

// Export the buffer directly for debugging
export fn getBuffer() [*]const u8 {
    if (!is_initialized) {
        return &zero_bytes;
    }
    return buffer.ptr;
}

// Export pattern information
export fn getPatternType() u32 {
    if (current_pattern) |pattern| {
        return @intFromEnum(pattern.pattern_type);
    }
    return 0;
}

export fn getPatternIntensity() f32 {
    if (current_pattern) |pattern| {
        return pattern.intensity;
    }
    return 0.0;
}

// Export the last error code
var last_error: ErrorCode = .Success;
export fn getLastError() u32 {
    return @intFromEnum(last_error);
}

// Cleanup function to free memory
export fn cleanup() void {
    if (is_initialized) {
        if (buffer.len > 0) {
            allocator.free(buffer);
            buffer = undefined;
        }
        if (pattern_buffer.len > 0) {
            allocator.free(pattern_buffer);
            pattern_buffer = undefined;
        }
        buffer_len = 0;
        current_pattern = null;
        is_initialized = false;
    }
} 