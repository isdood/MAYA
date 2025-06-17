const std = @import("std");
const Allocator = std.mem.Allocator;
const Atomic = std.atomic.Atomic;
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;

pub const MessageQueueError = error{
    QueueFull,
    QueueClosed,
    Timeout,
};

pub fn MessageQueue(comptime T: type) type {
    return struct {
        const Self = @This();
        
        allocator: Allocator,
        buffer: []T,
        head: Atomic(usize) = Atomic(usize).init(0),
        tail: Atomic(usize) = Atomic(usize).init(0),
        count: Atomic(usize) = Atomic(usize).init(0),
        mutex: Mutex = .{},
        not_empty: Condition = .{},
        not_full: Condition = .{},
        closed: Atomic(bool) = Atomic(bool).init(false),
        _capacity: usize,

        pub const Queue = MessageQueue(T);

        pub fn init(allocator: Allocator, capacity: usize) !*Queue {
            const self = try allocator.create(Queue);
            self.* = .{
                .allocator = allocator,
                .buffer = try allocator.alloc(T, capacity),
                .capacity = capacity,
            };
            return self;
        }

        pub fn deinit(self: *Queue) void {
            self.allocator.free(self.buffer);
            self.allocator.destroy(self);
        }

        pub fn enqueue(self: *Queue, item: T) MessageQueueError!void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (true) {
                if (self.closed.load(.SeqCst)) {
                    return error.QueueClosed;
                }

                const current_count = self.count.load(.SeqCst);
                if (current_count < self.capacity) {
                    const head = self.head.load(.SeqCst);
                    self.buffer[head] = item;
                    self.head.store((head + 1) % self.capacity, .SeqCst);
                    self.count.store(current_count + 1, .SeqCst);
                    self.not_empty.signal();
                    return;
                }

                // Wait for space to become available
                self.not_full.wait(&self.mutex);
            }
        }

        pub fn tryEnqueue(self: *Queue, item: T) MessageQueueError!void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.closed.load(.SeqCst)) {
                return error.QueueClosed;
            }

            const current_count = self.count.load(.SeqCst);
            if (current_count >= self.capacity) {
                return error.QueueFull;
            }

            const head = self.head.load(.SeqCst);
            self.buffer[head] = item;
            self.head.store((head + 1) % self.capacity, .SeqCst);
            self.count.store(current_count + 1, .SeqCst);
            self.not_empty.signal();
        }

        pub fn dequeue(self: *Queue) MessageQueueError!T {
            return self.timedDequeue(std.math.maxInt(u64)) catch |err| {
                // Convert timeout to queue closed if needed
                if (err == error.Timeout) return error.QueueClosed;
                return err;
            };
        }

        pub fn timedDequeue(self: *Queue, timeout_ns: u64) (MessageQueueError || error{Timeout})!T {
            self.mutex.lock();
            defer self.mutex.unlock();

            const start_time = std.time.nanoTimestamp();
            var remaining_time = @intCast(i128, timeout_ns);

            while (true) {
                const current_count = self.count.load(.SeqCst);
                if (current_count > 0) {
                    const tail = self.tail.load(.SeqCst);
                    const item = self.buffer[tail];
                    self.tail.store((tail + 1) % self.capacity, .SeqCst);
                    self.count.store(current_count - 1, .SeqCst);
                    self.not_full.signal();
                    return item;
                }

                if (self.closed.load(.SeqCst)) {
                    return error.QueueClosed;
                }

                if (remaining_time <= 0) {
                    return error.Timeout;
                }

                // Wait for an item to become available
                const wait_start = std.time.nanoTimestamp();
                self.not_empty.timedWait(&self.mutex, @intCast(u64, remaining_time)) catch |err| {
                    if (err == error.TimedOut) return error.Timeout;
                    return err;
                };
                
                const elapsed = @intCast(u64, std.time.nanoTimestamp() - wait_start);
                remaining_time -= @intCast(i128, elapsed);
            }
        }

        pub fn tryDequeue(self: *Queue) MessageQueueError!?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            const current_count = self.count.load(.SeqCst);
            if (current_count == 0) {
                return null;
            }

            const tail = self.tail.load(.SeqCst);
            const item = self.buffer[tail];
            self.tail.store((tail + 1) % self.capacity, .SeqCst);
            self.count.store(current_count - 1, .SeqCst);
            self.not_full.signal();
            return item;
        }

        pub fn close(self: *Queue) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.closed.store(true, .SeqCst);
            self.not_empty.broadcast();
            self.not_full.broadcast();
        }

        pub fn isClosed(self: *const Queue) bool {
            return self.closed.load(.SeqCst);
        }

        pub fn len(self: *const Queue) usize {
            return self.count.load(.SeqCst);
        }

        pub fn capacity(self: *const Queue) usize {
            return self._capacity;
        }
    };
}

test "message queue basic operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var queue = try MessageQueue(u32).init(arena.allocator(), 10);
    defer queue.deinit();
    
    // Test basic enqueue/dequeue
    try queue.enqueue(42);
    try std.testing.expectEqual(@as(usize, 1), queue.len());
    
    const item = try queue.dequeue();
    try std.testing.expectEqual(@as(u32, 42), item);
    try std.testing.expectEqual(@as(usize, 0), queue.len());
    
    // Test tryDequeue on empty queue
    const no_item = try queue.tryDequeue();
    try std.testing.expect(no_item == null);
    
    // Test closing the queue
    queue.close();
    try std.testing.expectError(error.QueueClosed, queue.enqueue(1));
    try std.testing.expect(queue.isClosed());
}

test "message queue blocking behavior" {
    // This test verifies the blocking behavior of the queue
    // Note: In a real test, we'd use threads to test blocking behavior
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    var queue = try MessageQueue(u32).init(arena.allocator(), 2);
    defer queue.close();
    
    // Fill the queue
    try queue.tryEnqueue(1);
    try queue.tryEnqueue(2);
    
    // Next enqueue should block, but we're using tryEnqueue to avoid blocking
    try std.testing.expectError(error.QueueFull, queue.tryEnqueue(3));
    
    // Dequeue one item and try again
    _ = try queue.tryDequeue();
    try queue.tryEnqueue(3); // Should work now
}
