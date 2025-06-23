const std = @import("std");
const pattern_synthesis = @import("pattern_synthesis.zig");
const pattern_ops = @import("pattern_operations.zig");
const quantum_algs = @import("quantum_algorithms.zig");
const pattern_memory = @import("pattern_memory.zig");
const Pattern = @import("pattern.zig").Pattern;
const math = std.math;
const Allocator = std.mem.Allocator;
const Complex = std.math.Complex(f64);

// Re-export memory optimization utilities
pub const MemoryOptimization = struct {
    /// Initialize the global pattern memory pool
    pub fn initMemoryPool(allocator: Allocator) !void {
        try Pattern.initGlobalPool(allocator);
    }
    
    /// Deinitialize the global pattern memory pool
    pub fn deinitMemoryPool() void {
        Pattern.deinitGlobalPool();
    }
    
    /// Create a zero-copy view of a pattern
    pub fn createPatternView(pattern: *const Pattern, x: usize, y: usize, width: usize, height: usize) Pattern {
        return pattern.createView(x, y, width, height);
    }
    
    /// Apply a transformation in-place if possible
    pub fn transformPatternInPlace(
        pattern: *Pattern,
        transform_fn: fn ([]u8) void
    ) !*Pattern {
        return try pattern.transformInPlace(transform_fn);
    }
};

pub const PatternEvolution = struct {
    // First: All type declarations
    pub const EvolutionState = struct {
        generation: u64 = 0,
        fitness: f64 = 0.0,
        diversity: f64 = 0.0,
        convergence: f64 = 0.0,
        pattern_id: []const u8 = "",
        fitness_fn: *const fn (ctx: ?*anyopaque, data: []const u8) f64 = undefined,
        fitness_ctx: ?*anyopaque = null,
        evolution_type: EvolutionType = .gradient_descent,
        synthesis_state: pattern_synthesis.SynthesisState = undefined,
        transformation_state: void = {},
        
        pub fn isValid(self: *const @This()) bool {
            return self.fitness >= 0.0 and self.fitness <= 1.0 and
                   self.diversity >= 0.0 and self.diversity <= 1.0 and
                   self.convergence >= 0.0 and self.convergence <= 1.0;
        }
    };
    
    pub const EvolutionConfig = struct {
        population_size: usize = 100,
        mutation_rate: f64 = 0.01,
        crossover_rate: f64 = 0.8,
        elitism: bool = true,
        max_generations: u64 = 1000,
    };
    
    pub const RealTimeConfig = struct {
        update_interval_ms: u64 = 1000,
        max_runtime_ms: u64 = 0, // 0 = no limit
        max_generations: u64 = 0, // 0 = no limit
        target_fitness: f64 = 1.0,
        threaded: bool = true,
    };
    
    pub const EvolutionCallback = *const fn (ctx: ?*anyopaque, state: *const EvolutionState, best_pattern: []const u8) anyerror!void;
    
    /// Type of evolution to perform
    pub const EvolutionType = enum {
        gradient_descent,
        genetic_algorithm,
        particle_swarm,
        simulated_annealing,
        random_search,
        quantum_enhanced,
        crystal_computing,
    };
    
    pub const EvolutionMetrics = struct {
        diversity: f64 = 0.0,
        convergence: f64 = 0.0,
        quantum_entanglement: f64 = 0.0,
        crystal_coherence: f64 = 0.0,
        fitness_improvement: f64 = 0.0,
        generation_time_ms: u64 = 0,
    };
    
    // All container fields must be declared first in Zig
    current_best: ?[]const u8 = null,
    state: EvolutionState,
    allocator: std.mem.Allocator,
    rt_callback: ?EvolutionCallback = null,
    rt_should_stop: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
    rt_config: RealTimeConfig = .{},
    rt_context: ?*anyopaque = null,
    rt_thread: ?std.Thread = null,
    current_population: ?[]const []const u8 = null,
    synthesis: type = @import("pattern_synthesis.zig").PatternSynthesis,
    config: EvolutionConfig = .{},
    quantum_processor: ?*quantum_algs.QuantumProcessor = null,
    crystal_computing: ?*quantum_algs.CrystalComputing = null,
    global_pool: ?*Pattern.PatternPool = null,
    
    // Initialize evolution with specific type
    pub fn initWithType(allocator: std.mem.Allocator, evo_type: EvolutionType) !*@This() {
        const self = try allocator.create(@This());
        errdefer allocator.destroy(self);
        
        self.* = .{
            .allocator = allocator,
            .state = .{
                .fitness_fn = undefined, // Must be set by the caller
                .fitness_ctx = null,
                .evolution_type = evo_type,
            },
            .global_pool = null,
        };
        
        return self;
    }
    
    // Initialize with default configuration
    pub fn init(allocator: std.mem.Allocator) !*@This() {
        return try initWithType(allocator, .genetic_algorithm);
    }

    pub fn deinit(self: *@This()) void {
        if (self.current_best) |best| {
            self.allocator.free(best);
        }
        self.allocator.destroy(self);
    }

    /// Stop any running real-time evolution
    pub fn stopRealtime(self: *PatternEvolution) void {
        self.rt_should_stop.store(true, .SeqCst);
    }
    
    /// Evolve pattern data in real-time with callbacks
    pub fn evolveRealtime(
        self: *PatternEvolution, 
        pattern_data: []const u8,
        config: RealTimeConfig,
        callback: EvolutionCallback,
        context: ?*anyopaque
    ) !void {
        // Store real-time configuration and callback
        self.rt_config = config;
        self.rt_callback = callback;
        self.rt_context = context;
        self.rt_should_stop.store(false, .SeqCst);
        
        // Store initial pattern
        if (self.current_best) |best| {
            self.allocator.free(best);
        }
        self.current_best = try self.allocator.dupe(u8, pattern_data);
        
        // Initialize population if needed
        if (self.current_population == null) {
            self.current_population = try self.generatePopulation(pattern_data);
        }
        
        // Start evolution in a separate thread if requested
        if (config.threaded) {
            self.rt_thread = try std.Thread.spawn(.{}, evolveThread, .{self});
        } else {
            try self.evolveThread();
        }
    }
    
    fn evolveThread(self: *PatternEvolution) !void {
        const config = self.rt_config orelse return error.NoRealTimeConfig;
        const callback = self.rt_callback orelse return error.NoCallbackProvided;
        
        const start_time = std.time.milliTimestamp();
        var last_update: i64 = 0;
        
        while (!self.rt_should_stop.load(.SeqCst)) {
            const now = std.time.milliTimestamp();
            
            // Check if max runtime exceeded
            if (config.max_runtime_ms > 0 and (now - start_time) >= @as(i64, @intCast(config.max_runtime_ms))) {
                break;
            }
            
            // Perform a single evolution step
            try self.evolveStep();
            
            // Call callback at specified interval
            if ((now - last_update) >= @as(i64, @intCast(config.update_interval_ms))) {
                try callback(self.rt_context, &self.state, self.current_best orelse return error.NoBestPattern);
                last_update = now;
            }
            
            // Small sleep to prevent busy waiting
            std.time.sleep(1_000_000); // 1ms
        }
        
        // Final update
        try callback(self.rt_context, &self.state, self.current_best orelse return error.NoBestPattern);
        try callback(self.rt_context, &self.state, self.state.pattern_id);
    }
    
    /// Evolve a single step with enhanced operations
    pub fn evolveStep(self: *PatternEvolution) !EvolutionMetrics {
        const start_time = std.time.milliTimestamp();
        var metrics = EvolutionMetrics{};
        
        // Initialize population if this is the first step
        if (self.current_population == null) {
            if (self.current_best == null) {
                return error.NoInitialPattern;
            }
            self.current_population = try self.generatePopulation(self.current_best.?);
        }
        
        const population = self.current_population orelse return error.NoPopulation;
        if (population.len == 0) return error.EmptyPopulation;
        
        // Track metrics
        var total_fitness: f64 = 0.0;
        var best_fitness: f64 = 0.0;
        var best_individual: ?[]const u8 = null;
        
        // Calculate fitness for each individual
        var valid_individuals: usize = 0;
        for (population) |individual| {
            const fitness = self.state.fitness_fn(self.state.fitness_ctx, individual);
            
            // Check if individual is valid
            if (fitness > 0.0) {
                valid_individuals += 1;
                if (fitness > best_fitness) {
                    best_fitness = fitness;
                    best_individual = individual;
                }
            }
            total_fitness += fitness;
        }
        
        // Apply quantum enhancement if enabled
        try self.applyQuantumEnhancement(population, &metrics);
        
        // Update the best pattern if we found a better one
        if (best_individual) |best| {
            if (self.current_best) |current| {
                const current_fitness = self.state.fitness_fn(self.state.fitness_ctx, current);
                if (best_fitness > current_fitness) {
                    self.allocator.free(current);
                    self.current_best = try self.allocator.dupe(u8, best);
                }
            } else {
                self.current_best = try self.allocator.dupe(u8, best);
            }
        }
        
        // Calculate diversity and convergence metrics
        metrics.diversity = self.calculateDiversity(population);
        metrics.convergence = self.calculateConvergence(&self.state);
        metrics.generation_time_ms = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
        
        return metrics;
    }
    
    // Apply quantum enhancement to the population of patterns
    fn applyQuantumEnhancement(self: *PatternEvolution, population: []*const Pattern, metrics: *EvolutionMetrics) !void {
        // Skip if no quantum enhancement is enabled
        if (self.state.evolution_type != .quantum_enhanced and 
            self.state.evolution_type != .crystal_computing) {
            return;
        }
        
        // Initialize quantum components if needed
        if (self.quantum_processor == null) {
            self.quantum_processor = try quantum_algs.QuantumProcessor.init(self.allocator, .{
                .use_crystal_computing = (self.state.evolution_type == .crystal_computing),
                .max_qubits = 32,
                .enable_parallel = true,
                .optimization_level = 3,
            });
        }
        
        // Apply quantum enhancement to each pattern
        for (population) |pattern| {
            // Create a mutable copy of the pattern data
            const pattern_data = try self.allocator.alloc(u8, pattern.data.len);
            defer self.allocator.free(pattern_data);
            @memcpy(pattern_data, pattern.data);
            
            // Convert pattern to quantum state
            var qstate = try self.patternToQuantumState(pattern_data);
            defer qstate.deinit(self.allocator);
            
            // Apply quantum processing
            try self.quantum_processor.?.process(&qstate);
            
            // Update quantum metrics
            metrics.quantum_entanglement = qstate.entanglement;
            
            // Apply crystal computing if enabled
            if (self.state.evolution_type == .crystal_computing) {
                if (self.crystal_computing == null) {
                    self.crystal_computing = try quantum_algs.CrystalComputing.init(
                        self.allocator, 4, 4, 4); // 4x4x4 crystal lattice
                }
                try self.crystal_computing.?.applyCrystalEffects(&qstate);
                metrics.crystal_coherence = self.crystal_computing.?.calculateCoherence();
            }
            
            // Convert back to classical pattern
            try self.quantumStateToPattern(&qstate, pattern_data);
            
            // Update the pattern with enhanced data
            @memcpy(pattern.data, pattern_data);
        }
    }
    
    /// Convert pattern to quantum state
    fn patternToQuantumState(self: *PatternEvolution, pattern_data: []const u8) !quantum_algs.QuantumState {
        const num_qubits = std.math.log2_int_ceil(usize, pattern_data.len * 8);
        const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
        
        var qstate = try quantum_algs.QuantumState.init(self.allocator, num_qubits);
        
        // Initialize quantum state from pattern data
        // This is a simplified version - in a real implementation, you'd use quantum encoding
        for (0..@min(pattern_data.len, num_states / 8)) |i| {
            const byte = pattern_data[i];
            for (0..8) |bit| {
                const idx = i * 8 + bit;
                if (idx >= num_states) break;
                const mask = @as(u8, 1) << @as(u3, @intCast(bit));
                const is_set = (byte & mask) != 0;
                qstate.amplitudes[idx] = .{
                    .real = if (is_set) 1.0 else 0.0,
                    .imag = 0.0,
                };
            }
        }
        
        // Normalize the quantum state
        try qstate.normalize();
        
        return qstate;
    }
    
    /// Convert quantum state back to pattern
    fn quantumStateToPattern(self: *PatternEvolution, qstate: *quantum_algs.QuantumState, pattern: []u8) !void {
        _ = self; // Unused parameter
        
        // Measure the quantum state to get classical bits
        const measurement = try qstate.measure();
        
        // Convert the measurement result back to pattern data
        // This is a simplified version - in a real implementation, you'd use quantum decoding
        for (0..@min(pattern.len, measurement.len / 8)) |i| {
            var byte: u8 = 0;
            for (0..8) |bit| {
                const idx = i * 8 + bit;
                if (idx >= measurement.len) break;
                if (measurement.get(idx)) {
                    byte |= @as(u8, 1) << @as(u3, @intCast(bit));
                }
            }
            pattern[i] = byte;
        }
    }
    

    

    
    /// Evolve pattern data (blocking)
    pub fn evolve(self: *PatternEvolution, pattern_data: []const u8) !EvolutionState {
        // Process initial pattern
        const initial_state = try self.synthesis.synthesize(pattern_data);

        // Initialize evolution state
        var state = EvolutionState{
            .fitness = 0.0,
            .generation = 0,
            .diversity = 0.0,
            .convergence = 0.0,
            .pattern_id = try self.allocator.dupe(u8, pattern_data[0..@min(32, pattern_data.len)]),
            .pattern_type = initial_state.pattern_type,
            .evolution_type = self.determineEvolutionType(initial_state),
            .synthesis_state = initial_state,
            .transformation_state = undefined,
        };

        // Evolve pattern
        try self.evolvePattern(&state, pattern_data);

        // Validate evolution state
        if (!state.isValid()) {
            return error.InvalidEvolutionState;
        }

        return state;
    }

    /// Evolve pattern through generations using memory pooling and zero-copy operations
    fn evolvePattern(self: *PatternEvolution, state: *EvolutionState, pattern_data: []const u8) !void {
        // Create a pattern using memory pool if available
        const pattern = try Pattern.init(self.allocator, pattern_data, state.width, state.height);
        
        // Use a defer with a block to ensure proper cleanup
        {
            defer {
                // Only deinit if we're not using the memory pool
                if (self.global_pool == null) {
                    pattern.deinit(self.allocator);
                } else if (self.global_pool.?.config.thread_safe) {
                    // If using thread-safe pool, release the pattern back to the pool
                    self.global_pool.?.releasePattern(pattern);
                }
            }
            
            // Track the best pattern using a view to avoid copying
            var best_pattern = pattern.createView(0, 0, state.width, state.height);
            var best_fitness = self.calculateFitness(best_pattern);
            
            // Main evolution loop
            while (state.generation < self.config.max_generations) {
                // Generate population using memory pool
                const population = try self.generatePopulation(pattern);
                defer {
                    for (population) |p| {
                        if (self.global_pool) |pool| {
                            pool.releasePattern(p);
                        } else {
                            p.deinit(self.allocator);
                        }
                    }
                }
                
                // Evaluate population and find best individual
                for (population) |individual| {
                    const fitness = self.calculateFitness(individual);
                    if (fitness > best_fitness) {
                        best_fitness = fitness;
                        // Create a new view of the best individual
                        best_pattern = individual.createView(0, 0, state.width, state.height);
                    }
                }
                
                // Update state
                state.generation += 1;
                state.fitness = best_fitness;
                state.diversity = self.calculateDiversity(population);
                state.convergence = self.calculateConvergence(state);
                
                // Check convergence
                if (state.convergence >= self.config.min_fitness) {
                    break;
                }
                
                // Prepare for next generation by updating the base pattern
                @memcpy(pattern.data, best_pattern.data);
            }
            
            // Apply quantum enhancement to the final pattern if enabled
            if (self.state.evolution_type == .quantum_enhanced) {
                try self.applyQuantumEnhancement(&[1]Pattern{pattern.*}, null);
            }
            
            // Apply synthesis to the final pattern if enabled
            if (self.state.synthesis_state.enabled) {
                try pattern_synthesis.applySynthesis(pattern, &self.state.synthesis_state);
            }
            
            // Copy the final result back to the output buffer
            @memcpy(pattern_data, pattern.data);
        }
    }

    /// Generate a new population from a parent pattern
    /// Uses memory pooling when available to reduce allocations
    fn generatePopulation(self: *PatternEvolution, parent: *const Pattern) ![]*Pattern {
        const pop_size = self.config.population_size;
        var population = try self.allocator.alloc(*Pattern, pop_size);
        
        // Use thread-local RNG for better performance in multi-threaded scenarios
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const rand = rng.random();
        
        // First individual is always a copy of the parent
        population[0] = try self.copyPattern(parent);
        
        // Generate variations for the rest of the population
        for (1..pop_size) |i| {
            // Decide whether to mutate or crossover
            if (i > 1 and rand.float(f64) < self.config.crossover_rate) {
                // Perform crossover with two random parents
                const parent1 = population[rand.uintLessThan(usize, i)];
                const parent2 = population[rand.uintLessThan(usize, i)];
                population[i] = try self.createOffspring(parent1, parent2);
            } else {
                // Perform mutation
                const parent_idx = rand.uintLessThan(usize, i);
                population[i] = try self.mutatePattern(population[parent_idx], false);
            }
        }
        
        return population;
    }
    
    /// Free a population of patterns, returning them to the memory pool if available
    fn freePopulation(self: *PatternEvolution, population: []*Pattern) void {
        for (population) |pattern| {
            if (self.global_pool) |pool| {
                pool.releasePattern(pattern);
            } else {
                pattern.deinit(self.allocator);
                self.allocator.destroy(pattern);
            }
        }
        self.allocator.free(population);
    }
    
    /// Create a deep copy of a pattern using memory pooling when available
    fn copyPattern(self: *PatternEvolution, pattern: *const Pattern) !*Pattern {
        if (self.global_pool) |pool| {
            const copy = try pool.getPattern(pattern.width, pattern.height, 4);
            @memcpy(copy.data, pattern.data);
            copy.complexity = pattern.complexity;
            copy.stability = pattern.stability;
            copy.pattern_type = pattern.pattern_type;
            return copy;
        } else {
            const copy = try self.allocator.create(Pattern);
            copy.* = .{
                .data = try self.allocator.dupe(u8, pattern.data),
                .width = pattern.width,
                .height = pattern.height,
                .complexity = pattern.complexity,
                .stability = pattern.stability,
                .pattern_type = pattern.pattern_type,
                .allocator = self.allocator,
            };
            return copy;
        }
    }
    
    /// Select a parent using tournament selection
    fn selectParent(self: *PatternEvolution, population: []*const Pattern, tournament_size: usize) !*const Pattern {
        // Use thread-local RNG for better performance in multi-threaded scenarios
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const rand = rng.random();
        
        var best_fitness: f64 = -std.math.f64_max;
        var best_individual: *const Pattern = undefined;
        var found_valid = false;
        
        // Randomly select tournament_size individuals and pick the best one
        for (0..tournament_size) |_| {
            const idx = rand.uintLessThan(usize, population.len);
            const individual = population[idx];
            const fitness = self.evaluateFitness(individual) catch continue;
            
            if (!found_valid or fitness > best_fitness) {
                best_fitness = fitness;
                best_individual = individual;
                found_valid = true;
            }
        }
        
        if (!found_valid) {
            // If no valid individual was found, return a random one
            return population[rand.uintLessThan(usize, population.len)];
        }
        
        return best_individual;
    }
    
    /// Create an offspring through crossover and mutation using memory pooling
    fn createOffspring(self: *PatternEvolution, parent1: *const Pattern, parent2: *const Pattern) !*Pattern {
        // Ensure parents have the same dimensions
        if (parent1.width != parent2.width or parent1.height != parent2.height) {
            return error.ParentDimensionMismatch;
        }
        
        const width = parent1.width;
        const height = parent1.height;
        const size = width * height * 4; // 4 channels (RGBA)
        
        // Get a pattern from the pool or allocate a new one
        const child = if (self.global_pool) |pool|
            try pool.getPattern(width, height, 4)
        else
            try Pattern.init(self.allocator, &[_]u8{0} ** size, width, height);
        
        // Use a defer with a block to ensure proper cleanup on error
        errdefer {
            if (self.global_pool) |pool| {
                pool.releasePattern(child);
            } else {
                child.deinit(self.allocator);
                self.allocator.destroy(child);
            }
        }
        
        // Use thread-local RNG for better performance in multi-threaded scenarios
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const rand = rng.random();
        
        // Choose a random row for the crossover point
        const crossover_row = rand.uintLessThan(usize, height);
        const row_size = width * 4; // 4 bytes per pixel (RGBA)
        const crossover_byte = crossover_row * row_size;
        
        // Perform crossover: take pixels from parent1 above the crossover row, parent2 below
        @memcpy(child.data[0..crossover_byte], parent1.data[0..crossover_byte]);
        @memcpy(child.data[crossover_byte..], parent2.data[crossover_byte..]);
        
        // Apply mutation with a certain probability
        if (rand.float(f64) < self.config.mutation_rate) {
            try self.mutatePattern(child, true);
        }
        
        // Update pattern metadata
        child.complexity = (parent1.complexity + parent2.complexity) * 0.5;
        child.stability = (parent1.stability + parent2.stability) * 0.5;
        
        return child;
    }
    
    /// Mutate a pattern with memory pooling and zero-copy optimizations
    /// If `in_place` is true, mutates the input buffer directly and returns void
    /// If `in_place` is false, returns a new mutated copy of the input using the memory pool
    fn mutatePattern(self: *PatternEvolution, pattern: anytype, in_place: bool) anyerror!if (in_place) void else *Pattern {
        const pattern_type = @TypeOf(pattern);
        const is_mutable = std.meta.Elem(pattern_type) == u8;
        
        // Use thread-local RNG for better performance in multi-threaded scenarios
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const rand = rng.random();
        
        // For in-place mutation, we can modify the pattern directly
        if (in_place and is_mutable) {
            // Apply mutation directly to the pattern data
            const num_mutations = @min(10, pattern.len);
            for (0..num_mutations) |_| {
                const idx = rand.uintLessThan(usize, pattern.len);
                pattern[idx] +%= @as(u8, @intCast(rand.intRangeAtMost(i8, -10, 10)));
            }
            return;
        }
        
        // For non-in-place mutations, use the memory pool if available
        const width = if (@hasField(pattern_type, "width")) pattern.width else @intCast(u32, @sqrt(@divFloor(pattern.len, 4)));
        const height = if (@hasField(pattern_type, "height")) pattern.height else width;
        
        // Try to get a pattern from the memory pool
        const result = if (self.global_pool) |pool| 
            try pool.getPattern(width, height, 4) 
        else 
            try Pattern.init(self.allocator, pattern, width, height);
        
        // Ensure we clean up if we fail after this point
        errdefer {
            if (self.global_pool) |pool| {
                pool.releasePattern(result);
            } else {
                result.deinit(self.allocator);
            }
        }
        
        // Copy the pattern data
        @memcpy(result.data, if (is_mutable) pattern else pattern.data);
        
        // Apply mutation to the copy
        const num_mutations = @min(10, result.data.len);
        for (0..num_mutations) |_| {
            const idx = rand.uintLessThan(usize, result.data.len);
            result.data[idx] +%= @as(u8, @intCast(rand.intRangeAtMost(i8, -10, 10)));
        }
        
        return result;
    }

    /// Evaluate population and return the best individual and its fitness
    /// Evaluate population and return the best individual and its fitness
    /// Note: The caller is responsible for deallocating the returned pattern if not using memory pooling
    fn evaluatePopulation(self: *PatternEvolution, population: []*const Pattern) !struct { pattern: *const Pattern, fitness: f64 } {
        if (population.len == 0) return error.EmptyPopulation;
        
        var best_fitness: f64 = -std.math.f64_max;
        var best_individual: *const Pattern = undefined;
        var total_fitness: f64 = 0.0;
        var valid_individuals: usize = 0;

        // Evaluate all individuals in the population
        for (population) |individual| {
            const fitness = try self.evaluateFitness(individual);
            
            // Skip invalid fitness values
            if (std.math.isNan(fitness) or !std.math.isFinite(fitness)) {
                continue;
            }
            
            valid_individuals += 1;
            total_fitness += fitness;
            
            // Track the best individual
            if (fitness > best_fitness) {
                best_fitness = fitness;
                best_individual = individual;
            }
        }
        
        // Check if we have any valid individuals
        if (valid_individuals == 0) {
            return error.NoValidIndividuals;
        }
        
        // Update the best pattern if we found a better one
        if (self.current_best == null or best_fitness > self.state.fitness) {
            // If using memory pool, we can just store a reference
            if (self.global_pool != null) {
                self.current_best = best_individual;
            } else {
                // Otherwise, we need to make a copy
                if (self.current_best) |current| {
                    current.deinit(self.allocator);
                }
                self.current_best = try Pattern.init(
                    self.allocator,
                    best_individual.data,
                    best_individual.width,
                    best_individual.height
                );
            }
            
            // Update the state with the new best fitness
            self.state.fitness = best_fitness;
        }
        
        // Update other state metrics
        self.state.diversity = self.calculateDiversity(population);
        self.state.convergence = self.calculateConvergence(&self.state);

        return .{
            .pattern = best_individual,
            .fitness = best_fitness,
        };
    }
    
    /// Evaluate fitness of a pattern
    fn evaluateFitness(self: *PatternEvolution, pattern: *const Pattern) !f64 {
        _ = self; // Unused parameter
        
        // Simple fitness function based on pattern complexity and stability
        // You should replace this with your actual fitness calculation
        var fitness: f64 = 0.0;
        
        // Add a small base fitness to avoid division by zero
        fitness += 0.001;
        
        // Reward higher complexity (up to a point)
        fitness += @min(0.5, pattern.complexity * 0.1);
        
        // Reward stability
        fitness += pattern.stability * 0.2;
        
        return fitness;
    }
    
    /// Calculate population diversity based on pattern similarity
    fn calculateDiversity(self: *PatternEvolution, population: []*const Pattern) f64 {
        _ = self; // Unused parameter
        
        if (population.len < 2) {
            return 0.0; // No diversity with 0 or 1 individual
        }
        
        var total_distance: f64 = 0.0;
        var pair_count: usize = 0;
        
        // Compare each pair of patterns
        for (0..population.len) |i| {
            const pattern1 = population[i];
            
            for (i+1..population.len) |j| {
                const pattern2 = population[j];
                
                // Calculate Hamming distance between patterns
                const dist = Pattern.calculateHammingDistance(pattern1.data, pattern2.data);
                total_distance += dist;
                pair_count += 1;
            }
        }
        
        // Return average distance between patterns (normalized to [0, 1])
        return if (pair_count > 0) 
            total_distance / @as(f64, @floatFromInt(pair_count)) 
        else 
            0.0;
    }
    
    /// Calculate convergence based on fitness
    fn calculateConvergence(self: *PatternEvolution, state: *const EvolutionState) f64 {
        _ = self; // Unused
        // Return fitness as convergence metric (higher fitness = more converged)
        return state.fitness;
    }
    
    /// Calculate distance between two patterns
    fn calculatePatternDistance(_: *const PatternEvolution, pattern1: *const Pattern, pattern2: *const Pattern) f64 {
        // Simple Hamming distance implementation
        if (pattern1.data.len != pattern2.data.len) {
            return 1.0; // Patterns of different lengths are maximally different
        }
        
        var distance: usize = 0;
        for (pattern1.data, 0..) |byte1, i| {
            const byte2 = pattern2.data[i];
            distance += @popCount(byte1 ^ byte2);
        }
        
        // Normalize to [0, 1] range
        return @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(pattern1.data.len * 8));
    }

    /// Determine evolution type based on pattern characteristics
    fn determineEvolutionType(_: *PatternEvolution, state: pattern_synthesis.PatternSynthesis.SynthesisState) EvolutionType {
        _ = state; // Silence unused parameter warning
        // TODO: Implement actual evolution type determination
        return .gradient_descent;
    }

    /// Should mutate
    fn shouldMutate(self: *PatternEvolution) bool {
        return std.crypto.random.float(f64) < self.config.mutation_rate;
    }

    /// Calculate Hamming distance
    /// Calculate Hamming distance between two patterns using SIMD when possible
    fn calculateHammingDistance(_: *const PatternEvolution, data1: []const u8, data2: []const u8) f64 {
        // Use SIMD for faster comparison if the data is aligned and large enough
        if (std.simd.suggestVectorSize(u8)) |vector_size| {
            const vector_count = data1.len / vector_size;
            const remainder = data1.len % vector_size;
            
            var distance: usize = 0;
            
            // Process in chunks of vector_size
            for (0..vector_count) |i| {
                const start = i * vector_size;
                const vec1 = @as(@Vector(vector_size, u8), data1[start..][0..vector_size].*);
                const vec2 = @as(@Vector(vector_size, u8), data2[start..][0..vector_size].*);
                const diff = vec1 != vec2;
                const diff_u32 = @as(u32, diff);
                distance += @popCount(@bitCast(u32, diff_u32));
            }
            
            // Process remaining elements
            for (data1[vector_count * vector_size ..], data2[vector_count * vector_size ..]) |a, b| {
                distance += @intFromBool(a != b);
            }
            
            return @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(data1.len));
        }
        var distance: usize = 0;
        const min_len = @min(data1.len, data2.len);

        for (0..min_len) |i| {
            if (data1[i] != data2[i]) {
                distance += 1;
            }
        }

        return @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(min_len));
    }
    
};

// Tests
const testing = std.testing;

test "real-time pattern evolution" {
    const allocator = testing.allocator;
    
    // Initialize pattern evolution
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();
    
    // Test pattern
    const pattern_data = "test pattern";
    
    // Set initial best
    evolution.current_best = try allocator.dupe(u8, pattern_data);
    
    // Run a few evolution steps
    for (0..10) |_| {
        try evolution.evolveStep();
        
        // Verify state is valid
        try testing.expect(evolution.state.isValid());
        try testing.expect(evolution.state.generation > 0);
    }
    
    // Cleanup
    if (evolution.current_best) |best| {
        allocator.free(best);
    }
}

test "pattern evolution initialization" {
    const allocator = std.testing.allocator;
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();

    try std.testing.expect(evolution.config.min_fitness == 0.95);
    try std.testing.expect(evolution.config.max_generations == 100);
    try std.testing.expect(evolution.config.mutation_rate == 0.1);
    try std.testing.expect(evolution.config.crossover_rate == 0.8);
}

test "pattern evolution" {
    const allocator = std.testing.allocator;
    var evolution = try PatternEvolution.init(allocator);
    defer evolution.deinit();

    const pattern_data = "test pattern";
    const state = try evolution.evolve(pattern_data);

    try std.testing.expect(state.fitness >= 0.0);
    try std.testing.expect(state.fitness <= 1.0);
    try std.testing.expect(state.generation > 0);
    try std.testing.expect(state.generation <= evolution.config.max_generations);
    try std.testing.expect(state.diversity >= 0.0);
    try std.testing.expect(state.diversity <= 1.0);
    try std.testing.expect(state.convergence >= 0.0);
    try std.testing.expect(state.convergence <= 1.0);
} 
