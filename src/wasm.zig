const std = @import("std");
const glimmer = @import("glimmer");
const neural = @import("neural");
const starweave = @import("starweave");
const colors = @import("colors");

// Define initial and maximum buffer sizes
const INITIAL_BUFFER_SIZE = 1024;
const MAX_BUFFER_SIZE = 1024 * 1024; // 1MB max
const BUFFER_POOL_SIZE = 8; // Number of buffers in the pool

// Error codes
pub const ErrorCode = enum(u32) {
    Success = 0,
    BufferTooSmall = 1,
    InvalidInput = 2,
    MemoryAllocationFailed = 3,
    PatternError = 4,
    BufferValidationError = 5,
};

// Buffer pool structure
const Buffer = struct {
    data: []u8,
    length: usize,
    in_use: bool,
    is_valid: bool,
};

// Global state
var is_initialized = false;
var allocator: std.mem.Allocator = undefined;
var buffer_pool: [BUFFER_POOL_SIZE]Buffer = undefined;
var current_buffer_index: usize = 0;
var result_memory: []u8 = undefined;  // Fixed memory for results
var result_length: usize = 0;  // Track actual data length
var result_valid: bool = false;  // Track if result is valid
var last_error: ErrorCode = ErrorCode.Success;  // Track last error

// Error buffer
var error_buffer: [1024]u8 = undefined;
var error_buffer_len: usize = 0;

// Create a static zero byte array for null returns
const zero_bytes = [_]u8{0};

// GLIMMER pattern state
var current_pattern: ?glimmer.GlimmerPattern = null;
var pattern_buffer: []u8 = undefined;

fn get_next_buffer() ?*Buffer {
    var i: usize = 0;
    while (i < BUFFER_POOL_SIZE) : (i += 1) {
        const idx = (current_buffer_index + i) % BUFFER_POOL_SIZE;
        if (!buffer_pool[idx].in_use) {
            current_buffer_index = idx;
            return &buffer_pool[idx];
        }
    }
    return null;
}

fn resize_buffer(buffer: *Buffer, new_size: usize) !void {
    if (new_size > MAX_BUFFER_SIZE) {
        return error.BufferTooLarge;
    }
    
    const new_data = try allocator.alloc(u8, new_size);
    if (buffer.data.len > 0) {
        const copy_len = @min(buffer.length, new_size);
        @memcpy(new_data[0..copy_len], buffer.data[0..copy_len]);
        allocator.free(buffer.data);
    }
    buffer.data = new_data;
    buffer.is_valid = true;
}

fn set_error(msg: []const u8) void {
    const max_len = @min(msg.len, error_buffer.len - 1);
    @memcpy(error_buffer[0..max_len], msg[0..max_len]);
    error_buffer[max_len] = 0;
    error_buffer_len = max_len;
}

export fn getLastErrorMessage() [*]const u8 {
    return &error_buffer;
}

export fn getLastErrorMessageLen() usize {
    return error_buffer_len;
}

export fn init() u32 {
    if (is_initialized) {
        return @intFromEnum(ErrorCode.Success);
    }
    
    // Initialize the allocator
    allocator = std.heap.page_allocator;
    
    // Initialize buffer pool
    for (&buffer_pool) |*buffer| {
        buffer.data = allocator.alloc(u8, INITIAL_BUFFER_SIZE) catch {
            return @intFromEnum(ErrorCode.MemoryAllocationFailed);
        };
        buffer.length = 0;
        buffer.in_use = false;
        buffer.is_valid = true;
    }
    
    // Allocate pattern buffer
    pattern_buffer = allocator.alloc(u8, INITIAL_BUFFER_SIZE) catch {
        // Clean up buffer pool
        for (&buffer_pool) |*buffer| {
            if (buffer.data.len > 0) {
                allocator.free(buffer.data);
            }
        }
        return @intFromEnum(ErrorCode.MemoryAllocationFailed);
    };
    
    // Allocate fixed result memory
    result_memory = allocator.alloc(u8, MAX_BUFFER_SIZE) catch {
        // Clean up other buffers
        for (&buffer_pool) |*buffer| {
            if (buffer.data.len > 0) {
                allocator.free(buffer.data);
            }
        }
        if (pattern_buffer.len > 0) {
            allocator.free(pattern_buffer);
        }
        return @intFromEnum(ErrorCode.MemoryAllocationFailed);
    };
    
    // Clear the pattern buffer
    @memset(pattern_buffer, 0);
    
    is_initialized = true;
    result_valid = false;
    last_error = ErrorCode.Success;
    return @intFromEnum(ErrorCode.Success);
}

export fn process(input_ptr: [*]const u8, input_len: usize) ErrorCode {
    // Clear any previous error message
    error_buffer_len = 0;
    last_error = ErrorCode.Success;
    
    // Validate input
    if (input_len == 0) {
        set_error("[process] Empty input");
        last_error = ErrorCode.InvalidInput;
        return ErrorCode.InvalidInput;
    }
    
    if (input_len > MAX_BUFFER_SIZE) {
        set_error("[process] Input too large");
        last_error = ErrorCode.BufferTooSmall;
        return ErrorCode.BufferTooSmall;
    }
    
    // Get next available buffer
    const buffer = get_next_buffer() orelse {
        set_error("[process] No available buffers");
        last_error = ErrorCode.BufferTooSmall;
        return ErrorCode.BufferTooSmall;
    };
    
    // Ensure buffer is large enough
    if (buffer.data.len < input_len) {
        const new_size = @max(input_len, buffer.data.len * 2);
        resize_buffer(buffer, new_size) catch {
            buffer.in_use = false;
            buffer.is_valid = false;
            set_error("[process] Buffer resize failed");
            last_error = ErrorCode.BufferTooSmall;
            return ErrorCode.BufferTooSmall;
        };
    }
    
    // Create input slice
    const input_slice = input_ptr[0..input_len];
    
    // Check if this is a GLIMMER pattern
    const is_glimmer_pattern = std.mem.indexOf(u8, input_slice, "@pattern_meta@") != null;
    
    // Process based on type
    if (is_glimmer_pattern) {
        // GLIMMER pattern support
        const pattern = glimmer.parsePattern(input_slice) catch {
            buffer.in_use = false;
            buffer.is_valid = false;
            set_error("[process] Pattern parse error");
            last_error = ErrorCode.PatternError;
            return ErrorCode.PatternError;
        };
        
        if (pattern == null) {
            // Not a valid pattern, but we'll handle it gracefully
            @memcpy(buffer.data[0..input_len], input_slice);
            buffer.length = input_len;
            buffer.in_use = true;
            buffer.is_valid = true;
            
            // Copy to result memory and update length
            @memcpy(result_memory[0..input_len], buffer.data[0..input_len]);
            result_length = input_len;
            result_valid = true;
            
            return ErrorCode.Success;
        }
        
        // Apply pattern transformation
        const transformed = glimmer.applyPattern(pattern.?, input_slice, allocator) catch {
            buffer.in_use = false;
            buffer.is_valid = false;
            set_error("[process] Pattern apply error");
            last_error = ErrorCode.PatternError;
            return ErrorCode.PatternError;
        };
        
        if (transformed == null) {
            buffer.in_use = false;
            buffer.is_valid = false;
            set_error("[process] Pattern transformation failed");
            last_error = ErrorCode.PatternError;
            return ErrorCode.PatternError;
        }
        
        // Ensure buffer is large enough for transformed data
        if (buffer.data.len < transformed.?.len) {
            resize_buffer(buffer, transformed.?.len) catch {
                buffer.in_use = false;
                buffer.is_valid = false;
                set_error("[process] Buffer resize failed");
                last_error = ErrorCode.BufferTooSmall;
                return ErrorCode.BufferTooSmall;
            };
        }
        
        // Copy transformed data to buffer
        @memcpy(buffer.data[0..transformed.?.len], transformed.?);
        buffer.length = transformed.?.len;
        buffer.in_use = true;
        buffer.is_valid = true;
        
        // Copy to result memory and update length
        @memcpy(result_memory[0..transformed.?.len], transformed.?);
        result_length = transformed.?.len;
        result_valid = true;
        
        // Free transformed data
        allocator.free(transformed.?);
        
        return ErrorCode.Success;
    } else {
        // Non-pattern input - just copy it
        @memcpy(buffer.data[0..input_len], input_slice);
        buffer.length = input_len;
        buffer.in_use = true;
        buffer.is_valid = true;
        
        // Copy to result memory and update length
        @memcpy(result_memory[0..input_len], buffer.data[0..input_len]);
        result_length = input_len;
        result_valid = true;
        
        return ErrorCode.Success;
    }
}

export fn getResult() [*]const u8 {
    if (!is_initialized or !result_valid) {
        return &zero_bytes;
    }
    return result_memory.ptr;
}

// Export the buffer size for JavaScript
export fn getBufferSize() usize {
    if (!is_initialized) {
        return 0;
    }
    return result_memory.len;
}

// Export the current length
export fn getLength() usize {
    if (!is_initialized or !result_valid) {
        return 0;
    }
    return result_length;
}

// Export the buffer directly for debugging
export fn getBuffer() [*]const u8 {
    if (!is_initialized or !result_valid) {
        return &zero_bytes;
    }
    return result_memory.ptr;
}

// Get the last error code
export fn getLastError() u32 {
    return @intFromEnum(last_error);
}

// Release the current buffer
export fn releaseBuffer() void {
    if (!is_initialized) {
        return;
    }
    
    const buffer = &buffer_pool[current_buffer_index];
    buffer.in_use = false;
    buffer.length = 0;
    buffer.is_valid = true;
    result_valid = false;
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

// Cleanup function to free memory
export fn cleanup() void {
    if (is_initialized) {
        // Free all buffers in the pool
        for (&buffer_pool) |*buffer| {
            if (buffer.data.len > 0) {
                allocator.free(buffer.data);
                buffer.data = undefined;
            }
        }
        
        // Free pattern buffer
        if (pattern_buffer.len > 0) {
            allocator.free(pattern_buffer);
            pattern_buffer = undefined;
        }
        
        // Free result memory
        if (result_memory.len > 0) {
            allocator.free(result_memory);
            result_memory = undefined;
        }
        
        current_pattern = null;
        is_initialized = false;
        result_valid = false;
        last_error = ErrorCode.Success;
    }
} 