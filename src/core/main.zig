const std = @import("std");
const glimmer = @import("glimmer");
const neural = @import("neural");
const starweave = @import("starweave");

pub fn main() !void {
    // Initialize the general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Initialize GLIMMER
    try glimmer.init();
    defer glimmer.deinit();

    // Initialize neural bridge
    try neural.init();
    defer neural.deinit();

    // Initialize STARWEAVE protocol
    try starweave.init();
    defer starweave.deinit();

    // Main program loop
    while (true) {
        // Process GLIMMER patterns
        try glimmer.processPatterns();

        // Process neural network
        try neural.process();

        // Process STARWEAVE protocol
        try starweave.process();

        // Sleep to prevent CPU hogging
        std.time.sleep(16 * std.time.ns_per_ms);
    }
}

test "basic functionality" {
    // Test GLIMMER initialization
    try glimmer.init();
    defer glimmer.deinit();

    // Test neural bridge initialization
    try neural.init();
    defer neural.deinit();

    // Test STARWEAVE protocol initialization
    try starweave.init();
    defer starweave.deinit();
} 