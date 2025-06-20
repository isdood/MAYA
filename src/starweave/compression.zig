
const std = @import("std");
const Allocator = std.mem.Allocator;
const deflate = std.compress.deflate;
const gzip = std.compress.gzip;
const zstd = std.compress.zstandard;

pub const CompressionAlgorithm = enum {
    none,
    deflate,
    gzip,
    zstd,
};

pub const CompressionLevel = enum(i3) {
    // Common compression levels
    none = 0,
    fast = 1,
    default = 3,
    best_speed = 6,
    best_compression = 9,
    ultra = 12,
};

pub const CompressionStream = union(CompressionAlgorithm) {
    none: struct {
        writer: std.io.Writer(void, error{Error}, writeNoOp),
        
        fn writeNoOp(context: void, bytes: []const u8) error{Error}!usize {
            _ = context;
            return bytes.len;
        }
    },
    deflate: deflate.Compress(Allocator, std.io.Writer(void, error{Error}, std.os.write)),
    gzip: gzip.Compress(Allocator, std.io.Writer(void, error{Error}, std.os.write)),
    zstd: zstd.CompressStream(Allocator, std.io.Writer(void, error{Error}, std.os.write)),
    
    pub fn writer(self: *CompressionStream) std.io.Writer(*CompressionStream, error{Error}, write) {
        return .{ .context = self };
    }
    
    pub fn write(self: *CompressionStream, bytes: []const u8) error{Error}!usize {
        return switch (self.*) {
            .none => |*none| none.writer().write(bytes),
            .deflate => |*d| d.writer().write(bytes),
            .gzip => |*g| g.writer().write(bytes),
            .zstd => |*z| z.writer().write(bytes),
        };
    }
    
    pub fn finish(self: *CompressionStream) !void {
        switch (self.*) {
            .none => {},
            .deflate => |*d| try d.finish(),
            .gzip => |*g| try g.finish(),
            .zstd => |*z| try z.finish(),
        }
    }
    
    pub fn deinit(self: *CompressionStream) void {
        switch (self.*) {
            .none => {},
            .deflate => |*d| d.deinit(),
            .gzip => |*g| g.deinit(),
            .zstd => |*z| z.deinit(),
        }
    }
};

pub const DecompressionStream = union(CompressionAlgorithm) {
    none: struct {
        reader: std.io.Reader(void, error{Error}, readNoOp),
        
        fn readNoOp(context: void, buffer: []u8) error{Error}!usize {
            _ = buffer; // Mark as used
            _ = context;
            return 0; // EOF
        }
    },
    deflate: deflate.Decompress(Allocator, std.io.Reader(void, error{Error}, std.os.read)),
    gzip: gzip.Decompress(Allocator, std.io.Reader(void, error{Error}, std.os.read)),
    zstd: zstd.DecompressStream(Allocator, std.io.Reader(void, error{Error}, std.os.read)),
    
    pub fn reader(self: *DecompressionStream) std.io.Reader(*DecompressionStream, error{Error}, read) {
        return .{ .context = self };
    }
    
    pub fn read(self: *DecompressionStream, buffer: []u8) error{Error}!usize {
        return switch (self.*) {
            .none => |*none| none.reader().read(buffer),
            .deflate => |*d| d.reader().read(buffer),
            .gzip => |*g| g.reader().read(buffer),
            .zstd => |*z| z.reader().read(buffer),
        };
    }
    
    pub fn deinit(self: *DecompressionStream) void {
        switch (self.*) {
            .none => {},
            .deflate => |*d| d.deinit(),
            .gzip => |*g| g.deinit(),
            .zstd => |*z| z.deinit(),
        }
    }
};

pub fn initCompressor(
    allocator: Allocator,
    algorithm: CompressionAlgorithm,
    level: CompressionLevel,
    dest: std.io.Writer(void, error{Error}, std.os.write),
) !CompressionStream {
    return switch (algorithm) {
        .none => CompressionStream{
            .none = .{
                .writer = .{ .context = {} },
            },
        },
        .deflate => CompressionStream{
            .deflate = try deflate.compress(allocator, dest, .{
                .level = @intFromEnum(level),
            }),
        },
        .gzip => CompressionStream{
            .gzip = try gzip.compress(allocator, dest, .{
                .level = @intFromEnum(level),
            }),
        },
        .zstd => CompressionStream{
            .zstd = try zstd.compressStream(allocator, dest, .{
                .level = @intFromEnum(level),
            }),
        },
    };
}

pub fn initDecompressor(
    allocator: Allocator,
    algorithm: CompressionAlgorithm,
    source: std.io.Reader(void, error{Error}, std.os.read),
) !DecompressionStream {
    return switch (algorithm) {
        .none => DecompressionStream{
            .none = .{
                .reader = .{ .context = {} },
            },
        },
        .deflate => DecompressionStream{
            .deflate = try deflate.decompress(allocator, source),
        },
        .gzip => DecompressionStream{
            .gzip = try gzip.decompress(allocator, source),
        },
        .zstd => DecompressionStream{
            .zstd = try zstd.decompressStream(allocator, source),
        },
    };
}

test "compression roundtrip" {
    const allocator = std.testing.allocator;
    const test_data = "Hello, this is a test string for compression!";
    
    inline for (@typeInfo(CompressionAlgorithm).Enum.fields) |field| {
        const algo = @field(CompressionAlgorithm, field.name);
        
        // Skip none for this test
        if (algo == .none) continue;
        
        // Compress
        var compressed = std.ArrayList(u8).init(allocator);
        defer compressed.deinit();
        
        var compressor = try initCompressor(
            allocator,
            algo,
            .default,
            compressed.writer(),
        );
        defer compressor.deinit();
        
        _ = try compressor.write(test_data);
        try compressor.finish();
        
        // Decompress
        var decompressed = std.ArrayList(u8).init(allocator);
        defer decompressed.deinit();
        
        var decompressor = try initDecompressor(
            allocator,
            algo,
            std.io.fixedBufferStream(compressed.items).reader(),
        );
        defer decompressor.deinit();
        
        try decompressed.writer().print("{}", .{decompressor.reader()});
        
        // Verify
        try std.testing.expectEqualStrings(test_data, decompressed.items);
    }
}
