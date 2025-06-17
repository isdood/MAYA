const std = @import("std");
const net = std.net;
const json = std.json;
const Pattern = @import("../glm/pattern.zig").Pattern;

pub const StarweaveClient = struct {
    allocator: std.mem.Allocator,
    stream: ?net.Stream,
    connected: bool,
    
    pub fn init(allocator: std.mem.Allocator) StarweaveClient {
        return .{
            .allocator = allocator,
            .stream = null,
            .connected = false,
        };
    }
    
    pub fn deinit(self: *StarweaveClient) void {
        if (self.stream) |*stream| {
            stream.close();
        }
    }
    
    pub fn connect(self: *StarweaveClient, host: []const u8, port: u16) !void {
        const addr = try net.Address.resolveIp(host, port);
        self.stream = try net.tcpConnectToAddress(addr);
        self.connected = true;
    }
    
    pub fn disconnect(self: *StarweaveClient) void {
        if (self.stream) |*stream| {
            stream.close();
            self.stream = null;
        }
        self.connected = false;
    }
    
    pub fn sendPattern(self: *StarweaveClient, pattern: *const Pattern) !void {
        if (self.stream == null or !self.connected) {
            return error.NotConnected;
        }
        
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();
        
        try pattern.toJson(buffer.writer());
        _ = try self.stream.?.write(buffer.items);
    }
    
    pub fn receiveAck(self: *StarweaveClient) !bool {
        if (self.stream == null or !self.connected) {
            return error.NotConnected;
        }
        
        var buffer: [1024]u8 = undefined;
        const len = try self.stream.?.read(&buffer);
        
        if (len == 0) {
            return false;
        }
        
        const response = buffer[0..len];
        return std.mem.eql(u8, response, "ACK");
    }
};

test "starweave client initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var client = StarweaveClient.init(arena.allocator());
    defer client.deinit();
    
    try std.testing.expect(!client.connected);
}

// Note: Integration tests requiring actual server connection would be in a separate test file
// that's only run when explicitly requested, as it requires a running STARWEAVE server
