//! 🧠 Memory-Optimized Evolution Engine
//! ✨ Version: 1.0.0
//! 📅 Created: 2025-06-22
//! 👤 Author: isdood

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;

// Simple PRNG using Xorshift64*
const SimpleRng = struct {
    state: u64,

    pub fn init(seed: u64) SimpleRng {
        var rng = SimpleRng{ .state = seed | 1 }; // Ensure state is never 0
        _ = rng.next(); // Discard first value
        return rng;
    }

    pub fn next(self: *SimpleRng) u64 {
        var x = self.state;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.state = x;
        // Use wrapping multiplication to handle overflow
        return @mulWithOverflow(x, 0x2545F4914F6CDD1D)[0];
    }

    pub fn int(self: *SimpleRng, comptime T: type, min: T, max: T) T {
        const range = @as(u64, max) - @as(u64, min) + 1;
        if (range == 0) return min; // Handle case where min == max
        
        // Use rejection sampling to avoid bias
        const max_valid = std.math.maxInt(u64) - (std.math.maxInt(u64) % range) - 1;
        var result: u64 = 0;
        while (true) {
            result = self.next();
            if (result <= max_valid) break;
        }
        
        return @as(T, @intCast(min + @as(u64, @intCast(result % range))));
    }

    pub fn float(self: *SimpleRng) f64 {
        // Generate a random number in [0, 1)
        return @as(f64, @floatFromInt(self.next() >> 11)) * (1.0 / 9007199254740992.0);
    }
};

/// Memory pool for pattern storage
const PatternPool = struct {
    allocator: Allocator,
    chunks: std.ArrayList([]u8),
    chunk_size: usize,
    current_offset: usize,
    
    pub fn init(allocator: Allocator, chunk_size: usize) !@This() {
        return .{
            .allocator = allocator,
            .chunks = std.ArrayList([]u8).init(allocator),
            .chunk_size = chunk_size,
            .current_offset = 0,
        };
    }
    
    pub fn deinit(self: *@This()) void {
        for (self.chunks.items) |chunk| {
            self.allocator.free(chunk);
        }
        self.chunks.deinit();
    }
    
    pub fn allocate(self: *@This(), size: usize) ![]u8 {
        // If no chunks or current chunk is full, allocate a new one
        if (self.chunks.items.len == 0 or self.current_offset + size > self.chunk_size) {
            const new_chunk = try self.allocator.alloc(u8, @max(self.chunk_size, size));
            try self.chunks.append(new_chunk);
            self.current_offset = 0;
        }
        
        const chunk = self.chunks.items[self.chunks.items.len - 1];
        const start = self.current_offset;
        const end = start + size;
        
        // Make sure we don't go out of bounds
        if (end > chunk.len) {
            return error.OutOfMemory;
        }
        
        self.current_offset = end;
        return chunk[start..end];
    }
};

/// Memory-optimized pattern
pub const CompactPattern = struct {
    data: []const u8,
    fitness: f64,
    
    pub fn init(pool: *PatternPool, data: []const u8) !@This() {
        const storage = try pool.allocate(data.len);
        @memcpy(storage, data);
        return .{
            .data = storage,
            .fitness = 0.0,
        };
    }
};

/// Memory-efficient population
pub const Population = struct {
    allocator: Allocator,
    pool: *PatternPool,
    individuals: std.ArrayList(CompactPattern),
    
    pub fn init(allocator: Allocator, pool: *PatternPool, capacity: usize) !@This() {
        return .{
            .allocator = allocator,
            .pool = pool,
            .individuals = try std.ArrayList(CompactPattern).initCapacity(allocator, capacity),
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.individuals.deinit();
    }
    
    pub fn add(self: *@This(), data: []const u8) !void {
        const individual = try CompactPattern.init(self.pool, data);
        try self.individuals.append(individual);
    }
    
    pub fn evaluateFitness(self: *@This(), fitness_fn: *const fn ([]const u8) f64) void {
        for (self.individuals.items) |*individual| {
            individual.fitness = fitness_fn(individual.data);
        }
    }
    
    pub fn selectTournament(self: *@This(), tournament_size: usize, rng: *SimpleRng) CompactPattern {
        var best: ?CompactPattern = null;
        
        for (0..tournament_size) |_| {
            const idx = rng.int(usize, 0, self.individuals.items.len - 1);
            const candidate = self.individuals.items[idx];
            
            if (best == null or candidate.fitness > best.?.fitness) {
                best = candidate;
            }
        }
        
        return best.?;
    }
};

/// Memory-optimized evolution engine
pub const MemoryEfficientEvolver = struct {
    allocator: Allocator,
    population: Population,
    pool: *PatternPool,
    rng: SimpleRng,
    
    pub fn init(allocator: Allocator, population_size: usize, pattern_size: usize) !@This() {
        const pool = try allocator.create(PatternPool);
        pool.* = try PatternPool.init(allocator, 1 << 20); // 1MB chunks
        
        // Initialize random number generator with timestamp
        const seed = @as(u64, @bitCast(@as(i64, @truncate(std.time.nanoTimestamp())))) | 1; // Ensure seed is odd
        const rng = SimpleRng.init(seed);
        
        var self = @This(){
            .allocator = allocator,
            .pool = pool,
            .population = try Population.init(allocator, pool, population_size),
            .rng = rng,
        };
        
        // Initialize population with random patterns
        for (0..population_size) |_| {
            const pattern = try allocator.alloc(u8, pattern_size);
            defer allocator.free(pattern);
            
            for (pattern) |*byte| {
                byte.* = self.rng.int(u8, 0, 255);
            }
            
            try self.population.add(pattern);
        }
        
        return self;
    }
    
    pub fn deinit(self: *@This()) void {
        // Free all individuals in the population
        for (self.population.individuals.items) |*individual| {
            // The memory for individual.data is managed by the pool
            _ = individual;
        }
        
        // Deinitialize the population and pool
        self.population.deinit();
        self.pool.deinit();
        self.allocator.destroy(self.pool);
    }
    
    pub fn evolveGeneration(self: *@This(), 
                          fitness_fn: *const fn ([]const u8) f64,
                          crossover_rate: f64,
                          mutation_rate: f64) !void {
        // Evaluate fitness
        self.population.evaluateFitness(fitness_fn);
        
        // Create new population
        var new_population = try Population.init(self.allocator, self.pool, self.population.individuals.items.len);
        
        // Elitism: keep the best individual
        var best_idx: usize = 0;
        for (self.population.individuals.items, 0..) |indiv, i| {
            if (indiv.fitness > self.population.individuals.items[best_idx].fitness) {
                best_idx = i;
            }
        }
        try new_population.add(self.population.individuals.items[best_idx].data);
        
        // Fill the rest of the population
        while (new_population.individuals.items.len < self.population.individuals.items.len) {
            const parent1 = self.population.selectTournament(5, &self.rng);
            
            if (self.rng.float() < crossover_rate) {
                // Crossover
                const parent2 = self.population.selectTournament(5, &self.rng);
                const child = try self.crossover(parent1, parent2);
                try new_population.add(child);
            } else {
                // Clone parent
                try new_population.add(parent1.data);
            }
            
            // Mutation
            if (self.rng.float() < mutation_rate) {
                const last_idx = new_population.individuals.items.len - 1;
                const individual = &new_population.individuals.items[last_idx];
                try self.mutate(individual);
            }
        }
        
        // Replace old population
        self.population.deinit();
        self.population = new_population;
    }
    
    fn crossover(self: *@This(), parent1: CompactPattern, parent2: CompactPattern) ![]u8 {
        const len = parent1.data.len;
        // Allocate from our memory pool instead of using the general allocator
        const child = try self.pool.allocate(len);
        
        // Single-point crossover
        const point = 1 + self.rng.int(usize, 0, len - 2);
        @memcpy(child[0..point], parent1.data[0..point]);
        @memcpy(child[point..], parent2.data[point..]);
        
        return child;
    }
    
    fn mutate(self: *@This(), individual: *CompactPattern) !void {
        const idx = self.rng.int(usize, 0, individual.data.len - 1);
        
        // Allocate new memory from our pool
        const new_data = try self.pool.allocate(individual.data.len);
        @memcpy(new_data, individual.data);
        
        // Flip a bit in the new copy
        const byte_idx = idx / 8;
        const bit_idx = @as(u3, @intCast(idx % 8));
        new_data[byte_idx] ^= @as(u8, 1) << bit_idx;
        
        // Replace the individual's data with the mutated version
        individual.data = new_data;
    }
};

// Tests
test "memory optimized evolution" {
    const allocator = testing.allocator;
    
    // Initialize evolver with a small population and pattern size
    const population_size = 20;
    const pattern_size = 16; // 16 bytes = 128 bits
    var evolver = try MemoryEfficientEvolver.init(allocator, population_size, pattern_size);
    defer evolver.deinit();
    
    // Target pattern with alternating bits (0101...)
    const target_pattern = try allocator.alloc(u8, pattern_size);
    defer allocator.free(target_pattern);
    @memset(target_pattern, 0x55); // 01010101 in binary
    
    // Fitness function: similarity to target pattern (higher is better)
    const fitness_fn = struct {
        target: []const u8,
        
        fn init(pattern: []const u8) @This() {
            return .{ .target = pattern };
        }
        
        fn calc(ctx: @This(), pattern: []const u8) f64 {
            var matches: usize = 0;
            const min_len = @min(ctx.target.len, pattern.len);
            
            // Count matching bits
            for (0..min_len) |i| {
                matches += @popCount(~(ctx.target[i] ^ pattern[i]));
            }
            
            // Calculate similarity as a value between 0.0 and 1.0
            return @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(min_len * 8));
        }
    }.init(target_pattern);
    
    // Create fitness function instance
    const fitness_fn_instance = fitness_fn.init(target_pattern);
    
    // Wrap the fitness function in a closure that matches the expected signature
    const fitness_func = struct {
        fn f(ctx: *const anyopaque, data: []const u8) f64 {
            const self = @as(*const @TypeOf(fitness_fn_instance), @ptrCast(@alignCast(ctx)));
            return self.calc(data);
        }
    }.f;
    
    // Print initial population stats
    {
        var min_fitness: f64 = 1.0;
        var max_fitness: f64 = 0.0;
        var total_fitness: f64 = 0.0;
        
        for (evolver.population.individuals.items) |individual| {
            const fitness = fitness_fn_instance.calc(individual.data);
            min_fitness = @min(min_fitness, fitness);
            max_fitness = @max(max_fitness, fitness);
            total_fitness += fitness;
        }
        
        const avg_fitness = total_fitness / @as(f64, @floatFromInt(evolver.population.individuals.items.len));
        std.debug.print("Initial - Min: {d:.3}, Avg: {d:.3}, Max: {d:.3}\n", 
            .{min_fitness, avg_fitness, max_fitness});
    }
    
    // Run evolution for several generations
    const generations = 50;
    const crossover_rate = 0.8;
    const mutation_rate = 0.05; // Lower mutation rate for more stable evolution
    
    for (0..generations) |generation| {
        try evolver.evolveGeneration(.{ .ptr = &fitness_fn_instance, .vtable = &.{
            .call = fitness_func,
        }}, crossover_rate, mutation_rate);
        
        // Track best fitness in this generation
        var best_fitness: f64 = 0.0;
        var total_fitness: f64 = 0.0;
        
        for (evolver.population.individuals.items) |individual| {
            best_fitness = @max(best_fitness, individual.fitness);
            total_fitness += individual.fitness;
        }
        
        // Print progress every few generations
        if (generation % 5 == 0 or generation == generations - 1) {
            const avg_fitness = total_fitness / @as(f64, @floatFromInt(evolver.population.individuals.items.len));
            std.debug.print("Gen {:3} - Best: {d:.3}, Avg: {d:.3}\n", 
                .{generation, best_fitness, avg_fitness});
        }
    }
    
    // Verify that we've made significant progress (should be very close to 1.0)
    var best_fitness: f64 = 0.0;
    for (evolver.population.individuals.items) |individual| {
        best_fitness = @max(best_fitness, individual.fitness);
    }
    
    std.debug.print("Final best fitness: {d:.3}\n", .{best_fitness});
    try testing.expect(best_fitness > 0.8); // Should be very close to the target
}
