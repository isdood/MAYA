const std = @import("std");
const glimmer = @import("glimmer");
const neural = @import("neural");
const starweave = @import("starweave");

// Define a fixed buffer size
const BUFFER_SIZE = 1024;

// Create a static buffer for our data
var buffer: [BUFFER_SIZE]u8 = undefined;
var buffer_len: usize = 0;

export fn init() void {
    buffer_len = 0;
    // Clear the buffer
    @memset(&buffer, 0);
}

export fn process(input_ptr: [*]const u8, input_len: usize) void {
    if (input_len <= BUFFER_SIZE) {
        // Clear the buffer first
        @memset(&buffer, 0);
        
        // Copy input to our buffer
        var i: usize = 0;
        while (i < input_len) : (i += 1) {
            buffer[i] = input_ptr[i];
        }
        buffer_len = input_len;
    }
}

export fn getResult() [*]const u8 {
    return &buffer;
}

// Export the buffer size for JavaScript
export fn getBufferSize() usize {
    return BUFFER_SIZE;
}

// Export the current length
export fn getLength() usize {
    return buffer_len;
}

// Export the buffer directly for debugging
export fn getBuffer() [*]const u8 {
    return &buffer;
} 