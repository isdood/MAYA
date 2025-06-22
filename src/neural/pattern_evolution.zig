pub const PatternEvolution = struct {
    // All fields grouped first - absolutely no exceptions
    current_best: ?[]const u8 = null,
    state: EvolutionState,
    allocator: std.mem.Allocator,
    config: EvolutionConfig,
    rt_context: ?*anyopaque = null,
    rt_thread: ?std.Thread = null,
    rt_should_stop: std.atomic.Atomic(bool),
    synthesis: pattern_synthesis.Synthesis,
    transformer: pattern_transformation.Transformer,
    current_population: ?[][]const u8 = null,
    rt_config: ?RealTimeConfig = null,
    rt_callback: ?EvolutionCallback = null,

    // Then all functions - nothing else between fields
    pub fn init(allocator: std.mem.Allocator) !*@This() {
        const self = try allocator.create(@This());
        self.* = .{
            .current_best = null,
            .state = .{},
            .allocator = allocator,
            .config = .{},
            .rt_context = null,
            .rt_thread = null,
            .rt_should_stop = std.atomic.Atomic(bool).init(false),
            .synthesis = try pattern_synthesis.PatternSynthesizer.init(allocator, .{}),
            .transformer = try pattern_transformation.PatternTransformer.init(allocator),
            .current_population = null,
            .rt_config = null,
            .rt_callback = null
        };
        return self;
    }

    pub fn deinit(self: *@This()) void {
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
    
    /// Evolve a single step
    pub fn evolveStep(self: *PatternEvolution) !void {
        // Initialize population if this is the first step
        if (self.current_population == null) {
            if (self.current_best == null) {
                return error.NoInitialPattern;
            }
            self.current_population = try self.generatePopulation(self.current_best.?);
        }
        
        const population = self.current_population orelse return error.NoPopulation;
        if (population.len == 0) return error.EmptyPopulation;
        
        // Evaluate all individuals in the population
        var total_fitness: f64 = 0.0;
        var best_fitness: f64 = 0.0;
        var best_individual: ?[]const u8 = null;
        
        // Calculate fitness for each individual
        for (population) |individual| {
            const fitness = self.state.fitness_fn(self.state.fitness_ctx, individual);
            total_fitness += fitness;
            
            // Track the best individual
            if (best_individual == null or fitness > best_fitness) {
                best_fitness = fitness;
                best_individual = individual;
            }
        }
        
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
        
        // Calculate population statistics
        const avg_fitness = total_fitness / @as(f64, @floatFromInt(population.len));
        
        // Simple diversity metric (standard deviation of fitness values)
        var variance: f64 = 0.0;
        for (population) |individual| {
            const diff = self.state.fitness_fn(self.state.fitness_ctx, individual) - avg_fitness;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(population.len));
        const diversity = @sqrt(variance);
        
        // Update state
        self.state.generation += 1;
        self.state.fitness = best_fitness;
        self.state.diversity = if (diversity > 1.0) 1.0 else if (diversity < 0.0) 0.0 else diversity;
        self.state.convergence = 1.0 - (diversity / @max(1.0, best_fitness));
        
        // Create new population through selection, crossover, and mutation
        var new_population = try self.allocator.alloc([]const u8, population.len);
        errdefer {
            for (new_population) |ind| self.allocator.free(ind);
            self.allocator.free(new_population);
        }
        
        // Keep the best individual (elitism)
        if (self.current_best) |best| {
            new_population[0] = try self.allocator.dupe(u8, best);
        } else {
            new_population[0] = try self.allocator.dupe(u8, population[0]);
        }
        
        // Fill the rest of the population with offspring
        for (new_population[1..]) |*individual| {
            // Select parents (tournament selection)
            const parent1 = try self.selectParent(population, 3);
            const parent2 = try self.selectParent(population, 3);
            
            // Create offspring through crossover and mutation
            individual.* = try self.createOffspring(parent1, parent2);
        }
        
        // Free old population
        for (population) |ind| self.allocator.free(ind);
        self.allocator.free(population);
        
        // Update current population
        self.current_population = new_population;
        }
        
        // Update evolution state
        self.state.generation += 1;
        self.state.diversity = self.calculateDiversity(population);
        self.state.convergence = self.calculateConvergence(&self.state);
        
        // Generate next generation
        self.freePopulation(population);
        self.current_population = try self.generatePopulation(self.current_best.?);
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

    /// Evolve pattern through generations
    fn evolvePattern(self: *PatternEvolution, state: *EvolutionState, pattern_data: []const u8) !void {
        var current_data = try self.allocator.dupe(u8, pattern_data);
        defer self.allocator.free(current_data);

        while (state.generation < self.config.max_generations) {
            // Generate new population
            const population = try self.generatePopulation(current_data);
            defer self.freePopulation(population);

            // Evaluate population
            const best_individual = try self.evaluatePopulation(population);
            if (best_individual.fitness > state.fitness) {
                state.fitness = best_individual.fitness;
                current_data = try self.allocator.dupe(u8, best_individual.data);
                self.allocator.free(current_data);
            }

            // Update evolution state
            state.generation += 1;
            state.diversity = self.calculateDiversity(population);
            state.convergence = self.calculateConvergence(state);

            // Check convergence
            if (state.convergence >= self.config.min_fitness) {
                break;
            }
        }

        // Update final states
        state.synthesis_state = try self.synthesis.synthesize(current_data);
        state.transformation_state = try self.transformer.transform(pattern_data, current_data);
    }

    /// Generate population
    fn generatePopulation(self: *PatternEvolution, pattern_data: []const u8) ![][]const u8 {
        // Initialize the population with random patterns
        var population = try self.allocator.alloc([]const u8, self.config.population_size);
        var seed = @as(u64, @intCast(std.time.milliTimestamp()));
        var rng = std.rand.DefaultPrng.init(seed);
        for (population) |*individual| {
            individual.* = try self.allocator.alloc(u8, self.config.pattern_size);
            for (individual.*) |*byte| {
                byte.* = rng.random().int(u8);
            }
        }
        return population;
    }

    /// Free population
    fn freePopulation(self: *PatternEvolution, population: [][]const u8) void {
        for (population) |individual| {
            self.allocator.free(individual);
        }
        self.allocator.free(population);
    }
    
    /// Select a parent using tournament selection
    fn selectParent(self: *PatternEvolution, population: [][]const u8, tournament_size: usize) ![]const u8 {
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        
        // Select tournament_size random individuals
        var best_fitness: f64 = -1.0;
        var best_individual: ?[]const u8 = null;
        
        for (0..tournament_size) |_| {
            const idx = rng.random().int(usize) % population.len;
            const individual = population[idx];
            const fitness = self.state.fitness_fn(self.state.fitness_ctx, individual);
            
            if (best_individual == null or fitness > best_fitness) {
                best_fitness = fitness;
                best_individual = individual;
            }
        }
        
        return best_individual orelse return error.SelectionFailed;
    }
    
    /// Create an offspring through crossover and mutation
    fn createOffspring(self: *PatternEvolution, parent1: []const u8, parent2: []const u8) ![]u8 {
        // Simple one-point crossover
        const min_len = @min(parent1.len, parent2.len);
        if (min_len == 0) return error.InvalidPatternLength;
        
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        const crossover_point = rng.random().int(usize) % min_len;
        
        // Create child by combining parts of both parents
        var child = try self.allocator.alloc(u8, parent1.len);
        
        // Copy first part from parent1
        @memcpy(child[0..crossover_point], parent1[0..crossover_point]);
        
        // Copy second part from parent2
        @memcpy(child[crossover_point..], parent2[crossover_point..]);
        
        // Apply mutation
        try self.mutatePattern(child);
        
        return child;
    }
    
    /// Mutate a pattern in-place
    fn mutatePattern(self: *PatternEvolution, pattern: []u8) !void {
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        
        for (pattern) |*byte| {
            if (rng.random().float(f64) < self.config.mutation_rate) {
                // Flip a random bit in the byte
                const bit_pos = rng.random().int(u3);
                byte.* ^= @as(u8, 1) << @intCast(bit_pos);
            }
        }
    }

    /// Evaluate population
    fn evaluatePopulation(self: *PatternEvolution, population: [][]const u8) !struct { data: []const u8, fitness: f64 } {
        var best_fitness: f64 = 0.0;
        var best_individual: []const u8 = undefined;

        for (population) |individual| {
            const fitness = try self.evaluateFitness(individual);
            if (fitness > best_fitness) {
                best_fitness = fitness;
                best_individual = individual;
            }
        }

        return .{
            .data = best_individual,
            .fitness = best_fitness,
        };
    }

    /// Mutate pattern
    fn mutatePattern(self: *PatternEvolution, pattern_data: []const u8) ![]const u8 {
        const mutated = try self.allocator.dupe(u8, pattern_data);
        errdefer self.allocator.free(mutated);

        // Apply mutations based on mutation rate
        for (mutated) |*byte| {
            if (self.shouldMutate()) {
                byte.* = @as(u8, @truncate(std.crypto.random.int(u8)));
            }
        }

        return mutated;
    }

    /// Evaluate fitness
    fn evaluateFitness(self: *PatternEvolution, pattern_data: []const u8) !f64 {
        const state = try self.synthesis.synthesize(pattern_data);
        return state.confidence;
    }

    /// Calculate diversity
    fn calculateDiversity(self: *PatternEvolution, population: [][]const u8) f64 {
        var diversity: f64 = 0.0;
        const n = population.len;

        // Calculate average Hamming distance
        for (0..population.len) |i| {
            const individual1 = population[i];
            for (population[i + 1..]) |individual2| {
                diversity += self.calculateHammingDistance(individual1, individual2);
            }
        }

        return diversity / (@as(f64, @floatFromInt(n * (n - 1))) / 2.0);
    }

    /// Calculate convergence
    fn calculateConvergence(_: *PatternEvolution, state: *EvolutionState) f64 {
        return state.fitness;
    }

    /// Determine evolution type
    fn determineEvolutionType(_: *PatternEvolution, state: pattern_synthesis.SynthesisState) EvolutionType {
        return switch (state.pattern_type) {
            .Quantum => .Quantum,
            .Visual => .Visual,
            .Neural => .Neural,
            .Universal => .Universal,
        };
    }

    /// Should mutate
    fn shouldMutate(self: *PatternEvolution) bool {
        return std.crypto.random.float(f64) < self.config.mutation_rate;
    }

    /// Calculate Hamming distance
    fn calculateHammingDistance(_: *PatternEvolution, data1: []const u8, data2: []const u8) f64 {
        var distance: usize = 0;
        const min_len = @min(data1.len, data2.len);

        for (0..min_len) |i| {
            if (data1[i] != data2[i]) {
                distance += 1;
            }
        }

        return @as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(min_len));
    }

    fn calculateIterations(self: *PatternTransformer, state: *TransformationState, source_data: []const u8, target_data: []const u8) usize {
    _ = self; // Mark as unused but keep interface consistent
    const base_iterations = state.base_iterations;
    const source_complexity = calculatePatternComplexity(source_data);
    const target_complexity = calculatePatternComplexity(target_data);
    return @min(
        state.max_iterations, 
        base_iterations + @as(usize, @intFromFloat(@max(source_complexity, target_complexity) * 10.0))
        );
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
