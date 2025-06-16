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

// Error messages
var last_error_message: [256]u8 = undefined;
var last_error_message_len: usize = 0;

fn set_error_message(msg: []const u8) void {
    last_error_message_len = @min(msg.len, last_error_message.len);
    @memcpy(last_error_message[0..last_error_message_len], msg[0..last_error_message_len]);
    if (last_error_message_len < last_error_message.len) {
        last_error_message[last_error_message_len] = 0;
    }
}

export fn getLastErrorMessage() [*]const u8 {
    return &last_error_message;
}

export fn getLastErrorMessageLen() usize {
    return last_error_message_len;
}

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

export fn process(input_ptr: [*]const u8, input_len: usize) ErrorCode {
    // Clear any previous error message
    error_buffer_len = 0;
    
    // Validate input
    if (input_len == 0) {
        set_error("[process] Empty input");
        return ErrorCode.InvalidInput;
    }
    
    // Create input slice
    const input_slice = input_ptr[0..input_len];
    
    // Check if this is a GLIMMER pattern
    const is_glimmer_pattern = std.mem.indexOf(u8, input_slice, "@pattern_meta@") != null;
    
    // Process based on type
    if (is_glimmer_pattern) {
        // GLIMMER pattern support
        const pattern = glimmer.parsePattern(input_slice) catch |err| {
            set_error("[process] Pattern parse error");
            return ErrorCode.PatternError;
        };
        
        if (pattern == null) {
            // Not a valid pattern, but we'll handle it gracefully
            const result = try allocator.alloc(u8, input_len);
            @memcpy(result, input_slice);
            if (current_buffer) |buf| {
                allocator.free(buf);
            }
            current_buffer = result;
            current_length = input_len;
            return ErrorCode.Success;
        }
        
        // Apply pattern transformation
        const transformed = glimmer.applyPattern(pattern.?, input_slice, allocator) catch |err| {
            set_error("[process] Pattern apply error");
            return ErrorCode.PatternError;
        };
        
        if (transformed == null) {
            set_error("[process] Pattern transformation failed");
            return ErrorCode.PatternError;
        }
        
        // Free old buffer if it exists
        if (current_buffer) |buf| {
            allocator.free(buf);
        }
        
        // Update current buffer
        current_buffer = transformed;
        current_length = transformed.?.len;
        
        return ErrorCode.Success;
    } else {
        // Non-pattern input - just copy it
        const result = try allocator.alloc(u8, input_len);
        @memcpy(result, input_slice);
        
        // Free old buffer if it exists
        if (current_buffer) |buf| {
            allocator.free(buf);
        }
        
        // Update current buffer
        current_buffer = result;
        current_length = input_len;
        
        return ErrorCode.Success;
    }
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