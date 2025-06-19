// 🎯 MAYA Pattern Evolution
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-18
// 👤 Author: isdood

const std = @import("std");
const pattern_synthesis = @import("pattern_synthesis.zig");
const pattern_transformation = @import("pattern_transformation.zig");

/// Evolution configuration
pub const EvolutionConfig = struct {
    // Processing parameters
    min_fitness: f64 = 0.95,
    max_generations: usize = 100,
    mutation_rate: f64 = 0.1,
    crossover_rate: f64 = 0.8,

    // Performance settings
    population_size: usize = 32,
    timeout_ms: u32 = 500,
};

/// Evolution state
pub const EvolutionState = struct {
    // Core properties
    fitness: f64,
    generation: usize,
    diversity: f64,
    convergence: f64,

    // Pattern properties
    pattern_id: []const u8,
    pattern_type: pattern_synthesis.PatternType,
    evolution_type: EvolutionType,

    // Component states
    synthesis_state: pattern_synthesis.SynthesisState,
    transformation_state: pattern_transformation.TransformationState,

    pub fn isValid(self: *const EvolutionState) bool {
        return self.fitness >= 0.0 and
               self.fitness <= 1.0 and
               self.generation > 0 and
               self.generation <= 100 and
               self.diversity >= 0.0 and
               self.diversity <= 1.0 and
               self.convergence >= 0.0 and
               self.convergence <= 1.0;
    }
};

/// Evolution types
pub const EvolutionType = enum {
    Quantum,
    Visual,
    Neural,
    Universal,
};

/// Pattern evolution
pub const PatternEvolution = struct {
    // System state
    config: EvolutionConfig,
    allocator: std.mem.Allocator,
    state: EvolutionState,
    synthesis: *pattern_synthesis.PatternSynthesis,
    transformer: *pattern_transformation.PatternTransformer,

    pub fn init(allocator: std.mem.Allocator) !*PatternEvolution {
        var evolution = try allocator.create(PatternEvolution);
        evolution.* = PatternEvolution{
            .config = EvolutionConfig{},
            .allocator = allocator,
            .state = EvolutionState{
                .fitness = 0.0,
                .generation = 0,
                .diversity = 0.0,
                .convergence = 0.0,
                .pattern_id = "",
                .pattern_type = .Universal,
                .evolution_type = .Universal,
                .synthesis_state = undefined,
                .transformation_state = undefined,
            },
            .synthesis = try pattern_synthesis.PatternSynthesis.init(allocator),
            .transformer = try pattern_transformation.PatternTransformer.init(allocator),
        };
        return evolution;
    }

    pub fn deinit(self: *PatternEvolution) void {
        self.synthesis.deinit();
        self.transformer.deinit();
        self.allocator.destroy(self);
    }

    /// Evolve pattern data
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
        var population = try self.allocator.alloc([]const u8, self.config.population_size);
        errdefer self.freePopulation(population);

        // Initialize population with mutations
        for (population) |*individual| {
            individual.* = try self.mutatePattern(pattern_data);
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
        var mutated = try self.allocator.dupe(u8, pattern_data);
        errdefer self.allocator.free(mutated);

        // Apply mutations based on mutation rate
        for (mutated) |*byte| {
            if (self.shouldMutate()) {
                byte.* = @truncate(u8, std.crypto.random.int(u8));
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
        for (population) |individual1, i| {
            for (population[i + 1..]) |individual2| {
                diversity += self.calculateHammingDistance(individual1, individual2);
            }
        }

        return diversity / (@intToFloat(f64, n * (n - 1)) / 2.0);
    }

    /// Calculate convergence
    fn calculateConvergence(self: *PatternEvolution, state: *EvolutionState) f64 {
        return state.fitness;
    }

    /// Determine evolution type
    fn determineEvolutionType(self: *PatternEvolution, state: pattern_synthesis.SynthesisState) EvolutionType {
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
    fn calculateHammingDistance(self: *PatternEvolution, data1: []const u8, data2: []const u8) f64 {
        var distance: usize = 0;
        const min_len = @min(data1.len, data2.len);

        for (0..min_len) |i| {
            if (data1[i] != data2[i]) {
                distance += 1;
            }
        }

        return @intToFloat(f64, distance) / @intToFloat(f64, min_len);
    }
};

// Tests
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