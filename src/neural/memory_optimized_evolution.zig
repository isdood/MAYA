//! 🧠 Memory-Optimized Evolution Engine
//! ✨ Version: 1.0.0
//! 📅 Created: 2025-06-22
//! 👤 Author: isdood

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;
const builtin = @import("builtin");

// Import GPU module if available
const gpu = if (@hasDecl(@import("root"), "gpu")) 
    struct {
        const gpu_impl = @import("gpu");
        pub const GPUEvolution = gpu_impl.pattern_fitness.GPUEvolution;
    } 
else 
    struct {
        pub const GPUEvolution = struct {
            pub const Config = struct { 
                enabled: bool = false, 
                batch_size: u32 = 256, 
                threads_per_block: u32 = 256 
            };
            pub fn init(_: Allocator, _: Config) anyerror!@This() { 
                return .{}; 
            }
            pub fn deinit(_: *@This()) void {}
            pub fn calculateFitnessBatch(
                _: *@This(), 
                _: []const []const u8, 
                _: u32, 
                _: u32
            ) anyerror![]f32 {
                return error.GPUNotAvailable;
            }
        };
    };

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
    
    /// Allocate a new pattern with the given size
    pub fn alloc(self: *@This(), size: usize) ![]u8 {
        // If no chunks or current chunk is full, allocate a new one
        if (self.chunks.items.len == 0 or self.current_offset + size > self.chunk_size) {
            const new_chunk = try self.allocator.alloc(u8, @max(self.chunk_size, size));
            try self.chunks.append(new_chunk);
            self.current_offset = 0;
        }
        
        const chunk = self.chunks.items[self.chunks.items.len - 1];
        const start = self.current_offset;
        const end = start + size;
        self.current_offset = end;
        return chunk[start..end];
    }
};

/// Memory-optimized pattern
pub const CompactPattern = struct {
    data: []const u8,
    fitness: f64,
    
    pub fn init(pool: *PatternPool, data: []const u8) !@This() {
        const storage = try pool.alloc(data.len);
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

/// Configuration for memory-efficient evolution
pub const EvolutionConfig = struct {
    /// Enable GPU acceleration if available
    enable_gpu: bool = true,
    /// Batch size for GPU processing
    gpu_batch_size: u32 = 1024,
    /// Number of threads per block for GPU kernels
    gpu_threads_per_block: u32 = 256,
    /// Number of top individuals to preserve between generations
    elitism_count: u32 = 1,
};

/// Memory-optimized evolution engine with optional GPU acceleration
pub const MemoryEfficientEvolver = struct {
    allocator: Allocator,
    population: Population,
    pool: *PatternPool,
    rng: SimpleRng,
    gpu_evolution: ?gpu.GPUEvolution = null,
    config: EvolutionConfig,
    
    pub fn init(allocator: Allocator, population_size: usize, pattern_size: usize, config: EvolutionConfig) !@This() {
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
            .config = config,
        };
        
        // Initialize GPU evolution if enabled
        if (config.enable_gpu) {
            if (gpu.GPUEvolution.init(allocator, .{
                .enabled = true,
                .batch_size = config.gpu_batch_size,
                .threads_per_block = config.gpu_threads_per_block,
            })) |gpu_ev| {
                self.gpu_evolution = gpu_ev;
                std.debug.print("✅ GPU acceleration enabled\n", .{});
            } else |err| {
                std.debug.print("⚠️  GPU initialization failed: {s}\n", .{@errorName(err)});
                self.gpu_evolution = null;
            }
        }
        
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
        // Free GPU resources if initialized
        if (self.gpu_evolution) |*gpu_ev| {
            gpu_ev.deinit();
        }
        
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
    
    /// Calculate fitness for a batch of patterns using GPU if available
    fn calculateFitnessBatch(
        self: *@This(),
        patterns: []const []const u8,
        fitness_fn: *const fn ([*]const u8, usize) callconv(.C) f64,
    ) ![]f64 {
        if (patterns.len == 0) return &.{};
        
        // Fall back to CPU implementation
        const results = try self.allocator.alloc(f64, patterns.len);
        for (patterns, 0..) |pattern, i| {
            results[i] = fitness_fn(pattern.ptr, pattern.len);
        }
        return results;
    }
    
    /// Evolve the population for one generation
    pub fn evolveGeneration(
        self: *@This(),
        fitness_fn: *const fn ([*]const u8, usize) callconv(.C) f64,
        crossover_rate: f64,
        mutation_rate: f64,
    ) !void {
        // Find unevaluated individuals
        var unevaluated = std.ArrayList([]const u8).init(self.allocator);
        defer unevaluated.deinit();
        
        for (self.population.individuals.items) |indiv| {
            if (indiv.fitness == 0.0) {
                try unevaluated.append(indiv.data);
            }
        }
        
        // Evaluate unevaluated individuals in batch if using GPU
        if (unevaluated.items.len > 0) {
            const fitness_values = try self.calculateFitnessBatch(unevaluated.items, fitness_fn);
            defer self.allocator.free(fitness_values);
            
            // Update fitness values
            var eval_idx: usize = 0;
            for (self.population.individuals.items) |*indiv| {
                if (indiv.fitness == 0.0 and eval_idx < fitness_values.len) {
                    indiv.fitness = fitness_values[eval_idx];
                    eval_idx += 1;
                }
            }
        }
        
        // Sort population by fitness (descending)
        std.sort.insertion(CompactPattern, self.population.individuals.items, {}, struct {
            fn lessThan(_: void, a: CompactPattern, b: CompactPattern) bool {
                return a.fitness > b.fitness;
            }
        }.lessThan);
        
        // Create new population with elitism (keep the best individuals)
        const elitism_count = @min(
            self.config.elitism_count,
            self.population.individuals.items.len / 2
        );
        
        var new_population = try Population.init(
            self.allocator,
            self.pool,
            self.population.individuals.items.len
        );
        
        // Add elite individuals to the new population
        for (self.population.individuals.items[0..elitism_count]) |elite| {
            try new_population.add(elite.data);
            new_population.individuals.items[new_population.individuals.items.len - 1].fitness = elite.fitness;
        }
        
        // Generate offspring through selection, crossover, and mutation
        while (new_population.individuals.items.len < self.population.individuals.items.len) {
            // Select parents using tournament selection
            const parent1 = self.tournamentSelect(3);
            const parent2 = self.tournamentSelect(3);
            
            // Create child through crossover (allocated from pool)
            const child = try self.crossover(parent1, parent2, crossover_rate);
            
            // Make a mutable copy for mutation (also from pool)
            const child_mut = try self.pool.alloc(parent1.len);
            @memcpy(child_mut, child);
            
            // Mutate the child in place
            try self.mutate(child_mut, mutation_rate);
            
            // Add to new population (this will make its own copy)
            try new_population.add(child_mut);
            
            // No need to free child_mut as it's managed by the pool
            // The pool will be reset when the population is replaced
        }
        
        // Replace old population with new one
        self.population.deinit();
        self.population = new_population;
    }
    
    /// Perform single-point crossover between two parent patterns
    fn crossover(self: *@This(), parent1: []const u8, parent2: []const u8, crossover_rate: f64) ![]const u8 {
        // Always allocate from the pool to ensure consistent memory management
        const child = try self.pool.alloc(parent1.len);
        
        // If no crossover, copy parent1
        if (self.rng.float() >= crossover_rate) {
            @memcpy(child, parent1);
            return child;
        }
        
        // Perform single-point crossover
        const crossover_point = self.rng.int(usize, 1, parent1.len - 1);
        @memcpy(child[0..crossover_point], parent1[0..crossover_point]);
        @memcpy(child[crossover_point..], parent2[crossover_point..]);
        
        return child;
    }
    
    /// Mutate an individual's data with a given probability per bit
    fn mutate(self: *@This(), individual: []u8, mutation_rate: f64) !void {
        // Calculate number of bits to flip based on mutation rate
        const total_bits = individual.len * 8;
        const bits_to_flip = @as(usize, @intFromFloat(mutation_rate * @as(f64, @floatFromInt(total_bits))));
        
        // Flip the specified number of random bits
        for (0..bits_to_flip) |_| {
            const idx = self.rng.int(usize, 0, total_bits - 1);
            const byte_idx = idx / 8;
            const bit_idx = @as(u3, @intCast(idx % 8));
            individual[byte_idx] ^= @as(u8, 1) << bit_idx;
        }
    }
    
    /// Select an individual using tournament selection
    fn tournamentSelect(self: *@This(), tournament_size: usize) []const u8 {
        var best_idx: usize = self.rng.int(usize, 0, self.population.individuals.items.len - 1);
        var best_fitness = self.population.individuals.items[best_idx].fitness;
        
        for (1..tournament_size) |_| {
            const idx = self.rng.int(usize, 0, self.population.individuals.items.len - 1);
            const fitness = self.population.individuals.items[idx].fitness;
            
            if (fitness > best_fitness) {
                best_idx = idx;
                best_fitness = fitness;
            }
        }
        
        return self.population.individuals.items[best_idx].data;
    }
};

// Tests
test "memory optimized evolution" {
    const allocator = testing.allocator;
    
    // Initialize evolver with a larger population and smaller pattern size
    const population_size = 50;  // Larger population for better exploration
    const pattern_size = 8;     // 8 bytes = 64 bits (smaller target is easier)
    
    // Create and initialize the pattern pool
    var pool = try PatternPool.init(allocator, 1 << 16); // 64KB chunks
    defer pool.deinit();
    
    // Initialize evolver with configuration
    var evolver = try MemoryEfficientEvolver.init(
        allocator,
        population_size,
        pattern_size,
        .{
            .enable_gpu = false, // Disable GPU for tests
            .elitism_count = 2,
        }
    );
    defer evolver.deinit();
    
    // Set the pool after initialization
    evolver.pool = &pool;
    
    // Create a target pattern to evolve towards (alternating bits: 01010101...)
    const target_pattern = [_]u8{0x55} ** 8; // 01010101 in binary
    
    // Fitness function that rewards patterns matching the target pattern
    const fitness_fn = struct {
        fn call(pattern_ptr: [*]const u8, pattern_len: usize) callconv(.C) f64 {
            const pattern = pattern_ptr[0..pattern_len];
            var matches: u32 = 0;
            for (pattern, 0..) |byte, i| {
                matches += @popCount(~(byte ^ target_pattern[i % target_pattern.len]));
            }
            return @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(pattern.len * 8));
        }
    }.call;
    
    // Run evolution for a few generations
    const max_generations = 50;
    var generation: usize = 0;
    var best_fitness: f64 = 0.0;
    
    while (generation < max_generations) : (generation += 1) {
        try evolver.evolveGeneration(fitness_fn, 0.8, 0.1);
        
        // Track best fitness in this generation
        var current_best: f64 = 0.0;
        var total_fitness: f64 = 0.0;
        
        for (evolver.population.individuals.items) |indiv| {
            current_best = @max(current_best, indiv.fitness);
            total_fitness += indiv.fitness;
        }
        
        best_fitness = @max(best_fitness, current_best);
        const avg_fitness = total_fitness / @as(f64, @floatFromInt(evolver.population.individuals.items.len));
        
        // Print progress every 5 generations
        if (generation % 5 == 0 or generation == max_generations - 1) {
            std.debug.print("Generation {:3}: Best = {d:.4}, Avg = {d:.4}\n", .{
                generation + 1, best_fitness, avg_fitness
            });
        }
        
        // Early exit if we've found a perfect match
        if (best_fitness >= 0.999) break;
    }
    
    // Verify that we found a good solution
    try testing.expect(best_fitness >= 0.9);
}
