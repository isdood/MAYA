const std = @import("std");

test "hello world" {
    std.debug.print("Hello, world!\n", .{});
    try std.testing.expect(true);
}
