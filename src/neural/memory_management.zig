
const std = @import("std");
const Pattern = @import("pattern.zig").Pattern;
const PatternMetrics = @import("pattern_metrics.zig").PatternMetrics;

/// Memory pool configuration
pub const MemoryPoolConfig = struct {
    initial_size: usize = 1024 * 1024, // 1MB
    max_size: usize = 1024 * 1024 * 1024, // 1GB
    block_size: usize = 4096, // 4KB
    growth_factor: f64 = 1.5,
    shrink_factor: f64 = 0.75,
    min_blocks: usize = 4,
    max_blocks: usize = 1024 * 1024, // 1M blocks
};

/// Memory block
pub const MemoryBlock = struct {
    data: []u8,
    is_used: bool,
    size: usize,
    last_access: i64,
    access_count: u32,

    pub fn init(data: []u8) MemoryBlock {
        return MemoryBlock{
            .data = data,
            .is_used = false,
            .size = data.len,
            .last_access = std.time.milliTimestamp(),
            .access_count = 0,
        };
    }

    pub fn deinit(self: *MemoryBlock) void {
        self.data = undefined;
        self.is_used = false;
        self.size = 0;
        self.last_access = 0;
        self.access_count = 0;
    }
};

/// Memory pool for efficient pattern storage
pub const MemoryPool = struct {
    // Memory configuration
    config: MemoryPoolConfig,
    allocator: std.mem.Allocator,

    // Memory blocks
    blocks: std.ArrayList(MemoryBlock),
    total_size: usize,
    used_size: usize,

    // Memory metrics
    allocation_count: u64,
    deallocation_count: u64,
    fragmentation: f64,
    hit_count: u64,
    miss_count: u64,

    pub fn init(allocator: std.mem.Allocator) !*MemoryPool {
        var pool = try allocator.create(MemoryPool);
        pool.* = MemoryPool{
            .config = MemoryPoolConfig{},
            .allocator = allocator,
            .blocks = std.ArrayList(MemoryBlock).init(allocator),
            .total_size = 0,
            .used_size = 0,
            .allocation_count = 0,
            .deallocation_count = 0,
            .fragmentation = 0.0,
            .hit_count = 0,
            .miss_count = 0,
        };

        // Initialize initial blocks
        try pool.initializeBlocks();
        return pool;
    }

    pub fn deinit(self: *MemoryPool) void {
        // Free all blocks
        for (self.blocks.items) |*block| {
            self.allocator.free(block.data);
            block.deinit();
        }
        self.blocks.deinit();
        self.allocator.destroy(self);
    }

    /// Initialize memory blocks
    fn initializeBlocks(self: *MemoryPool) !void {
        const num_blocks = @divTrunc(self.config.initial_size, self.config.block_size);
        try self.blocks.ensureTotalCapacity(num_blocks);

        var i: usize = 0;
        while (i < num_blocks) : (i += 1) {
            const block_data = try self.allocator.alloc(u8, self.config.block_size);
            try self.blocks.append(MemoryBlock.init(block_data));
        }

        self.total_size = self.config.initial_size;
    }

    /// Allocate memory for pattern
    pub fn allocate(self: *MemoryPool, size: usize) ![]u8 {
        if (size > self.config.block_size) {
            return error.BlockSizeExceeded;
        }

        // Try to find free block
        for (self.blocks.items) |*block| {
            if (!block.is_used and block.size >= size) {
                block.is_used = true;
                block.last_access = std.time.milliTimestamp();
                block.access_count += 1;
                self.used_size += size;
                self.allocation_count += 1;
                self.hit_count += 1;
                return block.data[0..size];
            }
        }

        // No free block found, try to grow pool
        if (self.total_size < self.config.max_size) {
            try self.growPool();
            return try self.allocate(size);
        }

        // Try to defragment
        try self.defragment();
        return try self.allocate(size);
    }

    /// Free pattern memory
    pub fn free(self: *MemoryPool, memory: []u8) void {
        for (self.blocks.items) |*block| {
            if (std.mem.eql(u8, block.data, memory)) {
                block.is_used = false;
                self.used_size -= memory.len;
                self.deallocation_count += 1;
                return;
            }
        }
    }

    /// Grow memory pool
    fn growPool(self: *MemoryPool) !void {
        const new_size = @floatToInt(usize, @intToFloat(f64, self.total_size) * self.config.growth_factor);
        const num_new_blocks = @divTrunc(new_size - self.total_size, self.config.block_size);

        if (self.blocks.items.len + num_new_blocks > self.config.max_blocks) {
            return error.MaxBlocksExceeded;
        }

        var i: usize = 0;
        while (i < num_new_blocks) : (i += 1) {
            const block_data = try self.allocator.alloc(u8, self.config.block_size);
            try self.blocks.append(MemoryBlock.init(block_data));
        }

        self.total_size = new_size;
    }

    /// Shrink memory pool
    fn shrinkPool(self: *MemoryPool) !void {
        const new_size = @floatToInt(usize, @intToFloat(f64, self.total_size) * self.config.shrink_factor);
        const num_blocks_to_remove = @divTrunc(self.total_size - new_size, self.config.block_size);

        if (self.blocks.items.len - num_blocks_to_remove < self.config.min_blocks) {
            return error.MinBlocksExceeded;
        }

        var i: usize = 0;
        while (i < num_blocks_to_remove) : (i += 1) {
            const block = self.blocks.pop();
            self.allocator.free(block.data);
            block.deinit();
        }

        self.total_size = new_size;
    }

    /// Defragment memory pool
    fn defragment(self: *MemoryPool) !void {
        // Sort blocks by last access time
        std.sort.sort(MemoryBlock, self.blocks.items, {}, struct {
            fn lessThan(_: void, a: MemoryBlock, b: MemoryBlock) bool {
                return a.last_access < b.last_access;
            }
        }.lessThan);

        // Calculate fragmentation
        var free_blocks: usize = 0;
        var total_free_size: usize = 0;
        for (self.blocks.items) |block| {
            if (!block.is_used) {
                free_blocks += 1;
                total_free_size += block.size;
            }
        }

        self.fragmentation = if (self.total_size > 0)
            @intToFloat(f64, total_free_size) / @intToFloat(f64, self.total_size)
        else
            0.0;

        // Shrink pool if fragmentation is high
        if (self.fragmentation > 0.5) {
            try self.shrinkPool();
        }
    }

    /// Get memory statistics
    pub fn getStatistics(self: *MemoryPool) MemoryStatistics {
        return MemoryStatistics{
            .total_size = self.total_size,
            .used_size = self.used_size,
            .free_size = self.total_size - self.used_size,
            .block_count = self.blocks.items.len,
            .allocation_count = self.allocation_count,
            .deallocation_count = self.deallocation_count,
            .fragmentation = self.fragmentation,
            .hit_count = self.hit_count,
            .miss_count = self.miss_count,
            .hit_ratio = if (self.hit_count + self.miss_count > 0)
                @intToFloat(f64, self.hit_count) / @intToFloat(f64, self.hit_count + self.miss_count)
            else
                0.0,
        };
    }
};

/// Memory statistics
pub const MemoryStatistics = struct {
    total_size: usize,
    used_size: usize,
    free_size: usize,
    block_count: usize,
    allocation_count: u64,
    deallocation_count: u64,
    fragmentation: f64,
    hit_count: u64,
    miss_count: u64,
    hit_ratio: f64,
};

// Tests
test "memory pool initialization" {
    const allocator = std.testing.allocator;
    var pool = try MemoryPool.init(allocator);
    defer pool.deinit();

    try std.testing.expect(pool.total_size == pool.config.initial_size);
    try std.testing.expect(pool.used_size == 0);
    try std.testing.expect(pool.blocks.items.len == @divTrunc(pool.config.initial_size, pool.config.block_size));
}

test "memory allocation" {
    const allocator = std.testing.allocator;
    var pool = try MemoryPool.init(allocator);
    defer pool.deinit();

    const memory = try pool.allocate(1024);
    try std.testing.expect(memory.len == 1024);
    try std.testing.expect(pool.used_size == 1024);
    try std.testing.expect(pool.allocation_count == 1);

    pool.free(memory);
    try std.testing.expect(pool.used_size == 0);
    try std.testing.expect(pool.deallocation_count == 1);
}

test "memory statistics" {
    const allocator = std.testing.allocator;
    var pool = try MemoryPool.init(allocator);
    defer pool.deinit();

    const stats = pool.getStatistics();
    try std.testing.expect(stats.total_size == pool.config.initial_size);
    try std.testing.expect(stats.used_size == 0);
    try std.testing.expect(stats.free_size == pool.config.initial_size);
    try std.testing.expect(stats.block_count == @divTrunc(pool.config.initial_size, pool.config.block_size));
    try std.testing.expect(stats.allocation_count == 0);
    try std.testing.expect(stats.deallocation_count == 0);
    try std.testing.expect(stats.fragmentation == 0.0);
    try std.testing.expect(stats.hit_count == 0);
    try std.testing.expect(stats.miss_count == 0);
    try std.testing.expect(stats.hit_ratio == 0.0);
} 
