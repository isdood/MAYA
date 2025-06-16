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
        // Copy input to our buffer
        @memcpy(buffer[0..input_len], input_ptr[0..input_len]);
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