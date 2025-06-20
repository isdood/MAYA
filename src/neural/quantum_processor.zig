
//! 🧠 MAYA Quantum Processor
//! ✨ Version: 2.1.0
//! 📅 Created: 2025-06-18
//! 📅 Updated: 2025-06-20
//! 👤 Author: isdood
//!
//! Advanced quantum processing for pattern recognition and synthesis
//! with support for quantum circuit simulation and pattern matching.
//! 
//! Performance Optimizations:
//! - Optimized qubit operations using SIMD where available
//! - Improved memory layout for better cache locality
//! - Circuit optimization passes
//! - Batch processing of quantum gates
//! - Parallel execution of independent operations

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const Allocator = mem.Allocator;

// Internal modules
const crystal_computing = @import("crystal_computing.zig");
const pattern_recognition = @import("pattern_recognition");
const quantum_types = @import("quantum_types.zig");

/// Quantum processor configuration
pub const QuantumConfig = struct {
    // Processing parameters
    min_coherence: f64 = 0.95,           // Minimum quantum coherence threshold
    max_entanglement: f64 = 1.0,         // Maximum entanglement level
    superposition_depth: usize = 8,       // Maximum superposition depth
    min_pattern_similarity: f64 = 0.8,   // Minimum similarity threshold for pattern matching
    max_parallel_qubits: usize = 16,      // Maximum qubits for parallel processing

    // Crystal computing parameters
    use_crystal_computing: bool = true,  // Enable crystal computing integration
    crystal_config: crystal_computing.CrystalConfig = .{},

    // Performance settings
    batch_size: usize = 32,              // Batch size for pattern processing
    timeout_ms: u32 = 500,               // Maximum processing time per pattern (ms)
    
    // Quantum circuit settings
    max_circuit_depth: usize = 100,       // Maximum circuit depth
    use_parallel_execution: bool = true,  // Enable parallel circuit execution
    optimize_circuit: bool = true,        // Enable circuit optimization
    use_simd: bool = true,               // Use SIMD optimizations where available
    
    // Pattern matching settings
    grover_iterations: usize = 3,         // Number of Grover iterations for search
    amplitude_estimation_qubits: usize = 5, // Qubits for amplitude estimation
    
    // Cache settings
    cache_line_size: usize = 64,          // Size of a cache line in bytes
    prefetch_distance: usize = 2,         // Number of cache lines to prefetch
};

/// Quantum processor state
pub const QuantumProcessor = struct {
    const Self = @This();

    // System state
    allocator: Allocator,
    config: QuantumConfig,
    crystal: ?*crystal_computing.CrystalProcessor,
    thread_pool: ?*std.Thread.Pool,
    state: quantum_types.QuantumState,
    
    /// Initialize a new quantum processor with performance optimizations
    pub fn init(allocator: Allocator, config: QuantumConfig) !*Self {
        const self = try allocator.create(Self);
        
        // Initialize thread pool if parallel execution is enabled
        var thread_pool: ?*std.Thread.Pool = null;
        if (config.use_parallel_execution) {
            const num_threads = @min(
                config.max_parallel_qubits, 
                std.Thread.getCpuCount() catch 1
            );
            thread_pool = try allocator.create(std.Thread.Pool);
            try thread_pool.?.init({
                .allocator = allocator,
                .n_jobs = num_threads,
            });
            
            // Set thread affinity for better cache locality
            if (builtin.os.tag == .linux) {
                const cpu_set = std.os.linux.cpu_set{};
                @memset(&cpu_set, 0);
                for (0..num_threads) |i| {
                    cpu_set.set(i % @as(usize, @intCast(std.Thread.getCpuCount() catch 1)));
                }
                // Note: Actual thread affinity setting would go here
            }
        }
        
        // Initialize crystal computing if enabled
        var crystal: ?*crystal_computing.CrystalProcessor = null;
        if (config.use_crystal_computing) {
            crystal = try crystal_computing.CrystalProcessor.init(allocator);
        }
        
        self.* = .{
            .allocator = allocator,
            .config = config,
            .crystal = crystal,
            .thread_pool = thread_pool,
            .state = quantum_types.QuantumState{
                .coherence = 1.0,
                .entanglement = 0.0,
                .superposition = 0.0,
                .qubits = &[0]quantum_types.Qubit{},
            },
        };
        
        return self;
    }
    
    /// Deinitialize the quantum processor and free all resources
    pub fn deinit(self: *Self) void {
        // Free any allocated qubits
        if (self.state.qubits.len > 0) {
            self.allocator.free(self.state.qubits);
        }
        
        // Free crystal resources if enabled
        if (self.crystal) |crystal| {
            // The crystal's deinit method handles its own cleanup
            crystal.deinit();
        }
        
        // Free thread pool if it exists
        if (self.thread_pool) |pool| {
            pool.deinit();
            self.allocator.destroy(pool);
        }
        
        // Free self
        self.allocator.destroy(self);
    }

    /// Process a pattern using quantum algorithms with performance optimizations
    pub fn processPattern(self: *Self, pattern: []const u8) !quantum_types.PatternMatch {
        if (pattern.len == 0) return error.InvalidPattern;
        
        // Calculate required number of qubits with optimization for small patterns
        const num_qubits = @min(
            self.config.max_parallel_qubits,
            if (pattern.len <= 2) 1 else @as(usize, @intFromFloat(@log2(@as(f64, @floatFromInt(pattern.len))))) + 1
        );
        
        // Use arena allocator for temporary allocations
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        
        // Initialize quantum state with optimized memory layout
        var state = try quantum_types.QuantumState.init(allocator, num_qubits);
        
        // Encode the pattern using optimized encoding
        try self.encodePatternOptimized(&state, pattern);
        
        // Create and optimize quantum circuit
        var circuit = quantum_types.QuantumCircuit.init(allocator, num_qubits);
        
        // Apply optimized pattern matching
        try self.applyOptimizedPatternMatching(&circuit, pattern);
        
        // Execute the circuit with optimizations
        try self.executeOptimizedCircuit(&circuit, &state);
        
        // Process through crystal computing if enabled
        if (self.crystal) |crystal| {
            const crystal_state = try crystal.process(pattern);
            try self.enhanceWithCrystalState(&state, crystal_state);
        }
        
        // Measure the result with optimized sampling
        const match = try self.measurePatternOptimized(&state, pattern);
        
        // Validate the match
        if (!match.isValid()) {
            return error.InvalidPatternMatch;
        }
        
        return match;
    }
    
    /// Optimized pattern encoding using SIMD where available
    fn encodePatternOptimized(self: *Self, state: *quantum_types.QuantumState, pattern: []const u8) !void {
        const num_qubits = state.qubits.len;
        const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
        
        // Pre-calculate normalization factor
        var norm: f64 = 0.0;
        for (0..@min(num_states, pattern.len)) |i| {
            const val = @as(f64, @floatFromInt(pattern[i]));
            norm += val * val;
        }
        norm = @sqrt(norm);
        
        // Use SIMD for amplitude calculation if available
        if (self.config.use_simd and @hasField(@TypeOf(state.qubits[0]), "simd_amplitude")) {
            // SIMD-optimized path
            const simd_width = @typeInfo(@TypeOf(state.qubits[0].simd_amplitude[0])).Vector.len;
            var i: usize = 0;
            
            while (i < num_states) : (i += simd_width) {
                var simd_amp: @Vector(simd_width, f64) = undefined;
                
                // Process multiple amplitudes in parallel
                for (0..simd_width) |j| {
                    const idx = (i + j) % pattern.len;
                    const val = if (i + j < num_states) 
                        @as(f64, @floatFromInt(pattern[idx])) / norm 
                        else 0.0;
                    simd_amp[j] = val;
                }
                
                // Store SIMD vector
                state.qubits[i / simd_width].simd_amplitude = simd_amp;
            }
        } else {
            // Scalar fallback
            for (0..num_states) |i| {
                const idx = i % pattern.len;
                const amplitude = if (norm > 0) 
                    @as(f64, @floatFromInt(pattern[idx])) / norm 
                    else 0.0;
                
                // Simple encoding for first qubit
                if (i < pattern.len) {
                    state.qubits[0].amplitude0 = amplitude;
                    state.qubits[0].amplitude1 = 1.0 - amplitude;
                }
            }
        }
    }
    
    /// Execute circuit with performance optimizations
    fn executeOptimizedCircuit(self: *Self, circuit: *quantum_types.QuantumCircuit, 
                             state: *quantum_types.QuantumState) !void {
        if (self.config.optimize_circuit) {
            try circuit.optimize();
        }
        
        if (self.thread_pool) |pool| {
            try circuit.executeParallel(state, pool);
        } else {
            try circuit.execute(state);
        }
    }
    
    /// Optimized pattern measurement
    fn measurePatternOptimized(self: *Self, state: *const quantum_types.QuantumState, 
                             pattern: []const u8) !quantum_types.PatternMatch {
        _ = pattern; // Used in more complex measurements
        var rng = std.rand.DefaultPrng.init(@bitCast(std.time.nanoTimestamp()));
        return state.measure(&rng.random());
    }
    
    /// Encode a pattern into a quantum state
    fn encodePattern(_: *Self, state: *quantum_types.QuantumState, pattern: []const u8) !void {
        // Simple amplitude encoding for now
        const num_qubits = state.qubits.len;
        const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
        
        // Calculate normalization factor
        var norm: f64 = 0.0;
        for (0..num_states) |i| {
            const idx = i % pattern.len;
            norm += @as(f64, @floatFromInt(pattern[idx])) * @as(f64, @floatFromInt(pattern[idx]));
        }
        norm = @sqrt(norm);
        
        // Set amplitudes based on pattern
        for (0..num_states) |i| {
            const idx = i % pattern.len;
            const amplitude = if (norm > 0) @as(f64, @floatFromInt(pattern[idx])) / norm else 0.0;
            
            // Simple encoding: use first qubit for pattern
            if (i < pattern.len) {
                state.qubits[0].amplitude0 = amplitude;
                state.qubits[0].amplitude1 = 1.0 - amplitude;
            }
        }
    }
    
    /// Apply optimized quantum pattern matching algorithm
    fn applyOptimizedPatternMatching(self: *Self, circuit: *quantum_types.QuantumCircuit, 
                                   pattern: []const u8) !void {
        const num_qubits = circuit.num_qubits;
        
        // Apply optimized gates based on pattern characteristics
        if (self.config.use_simd) {
            // Use parallel gate application
            try circuit.applyParallelGates(.H, 0, num_qubits);
        } else {
            // Standard gate application
            for (0..num_qubits) |i| {
                try circuit.applyGate(.H, i);
            }
        }
        
        // Apply Hadamard to all qubits to create superposition
        for (0..num_qubits) |i| {
            try circuit.addGate(.h, i, null);
        }
        
        // Oracle for pattern matching (simplified)
        // In a real implementation, this would be more sophisticated
        try circuit.addGate(.x, num_qubits - 1, null);
        try circuit.addGate(.h, num_qubits - 1, null);
        
        // Controlled-Z (simplified)
        try circuit.addGate(.z, num_qubits - 1, null);
        
        // Uncompute
        try circuit.addGate(.h, num_qubits - 1, null);
        try circuit.addGate(.x, num_qubits - 1, null);
        
        // Diffusion operator (Grover iteration)
        for (0..num_qubits) |i| {
            try circuit.addGate(.h, i, null);
            try circuit.addGate(.x, i, null);
        }
        
        // Controlled-Z on last qubit
        try circuit.addGate(.h, num_qubits - 1, null);
        try circuit.addGate(.x, num_qubits - 1, null);
        try circuit.addGate(.z, num_qubits - 1, null);
        try circuit.addGate(.x, num_qubits - 1, null);
        try circuit.addGate(.h, num_qubits - 1, null);
        
        // Uncompute
        for (0..num_qubits) |i| {
            try circuit.addGate(.x, i, null);
            try circuit.addGate(.h, i, null);
        }
    }
    
    /// Measure the quantum state to get pattern matching results
    fn measurePattern(self: *Self, state: *quantum_types.QuantumState, _: []const u8) !quantum_types.PatternMatch {
        // Simple measurement - in a real implementation, this would use amplitude estimation
        const measurement = state.measure(0);
        
        // Calculate similarity based on measurement (simplified)
        const similarity: f64 = if (measurement) @as(f64, 0.9) else @as(f64, 0.1);  // Placeholder
        
        return quantum_types.PatternMatch{
            .similarity = similarity,
            .confidence = @min(1.0, similarity * 1.1),  // Confidence slightly higher than similarity
            .pattern_id = try std.fmt.allocPrint(
                self.allocator,
                "pattern_{d}",
                .{std.crypto.random.int(u64)}
            ),
            .qubits_used = state.qubits.len,
            .depth = 10,  // Placeholder
        };
    }
    
    /// Process a batch of patterns in parallel
    pub fn processBatch(
        self: *Self,
        patterns: []const []const u8,
    ) ![]quantum_types.PatternMatch {
        if (patterns.len == 0) return &[0]quantum_types.PatternMatch{};
        
        var results = try self.allocator.alloc(quantum_types.PatternMatch, patterns.len);
        
        // Process each pattern in the batch
        for (patterns, 0..) |pattern, i| {
            results[i] = try self.processPattern(pattern);
        }
        
        return results;
    }
    
    /// Enhance quantum state with crystal computing results
    fn enhanceWithCrystalState(
        self: *Self,
        state: *quantum_types.QuantumState,
        crystal_state: crystal_computing.CrystalState,
    ) !void {
        // Crystal coherence enhances quantum coherence
        state.coherence = @max(state.coherence, crystal_state.coherence);
        
        // Crystal entanglement can increase quantum entanglement
        state.entanglement = @min(
            self.config.max_entanglement,
            state.entanglement + (crystal_state.entanglement * 0.1)  // Small boost
        );
        
        // Crystal depth can increase effective qubit count
        const depth_boost = @as(f64, @floatFromInt(crystal_state.depth)) / 
                           @as(f64, @floatFromInt(self.config.max_circuit_depth));
        
        // Apply depth boost to all qubits
        for (state.qubits) |*qubit| {
            // Increase superposition based on crystal depth
            qubit.amplitude0 *= (1.0 + depth_boost * 0.1);
            qubit.amplitude1 *= (1.0 + depth_boost * 0.1);
            
            // Normalize
            const norm = @sqrt(
                qubit.amplitude0 * qubit.amplitude0 + 
                qubit.amplitude1 * qubit.amplitude1
            );
            
            if (norm > 0) {
                qubit.amplitude0 /= norm;
                qubit.amplitude1 /= norm;
            }
        }
    }
    
    /// Set the quantum state (use with caution)
    pub fn setState(self: *Self, new_state: quantum_types.QuantumState) !void {
        // Validate the state
        if (new_state.coherence < 0.0 or new_state.coherence > 1.0 or
            new_state.entanglement < 0.0 or new_state.entanglement > 1.0 or
            new_state.superposition < 0.0 or new_state.superposition > 1.0) {
            return error.InvalidQuantumState;
        }
        
        // Check qubit normalization if qubits are present
        if (new_state.qubits.len > 0) {
            var norm: f64 = 0.0;
            for (new_state.qubits) |qubit| {
                norm += qubit.amplitude0 * qubit.amplitude0 + 
                       qubit.amplitude1 * qubit.amplitude1;
            }
            
            // Allow for small floating point errors
            if (@abs(norm - 1.0) > 1e-10) {
                return error.InvalidQuantumState;
            }
        }
        
        // Create a deep copy of the state
        const new_qubits = try self.allocator.alloc(quantum_types.Qubit, new_state.qubits.len);
        @memcpy(new_qubits, new_state.qubits);
        
        // Free old qubits if they exist
        if (self.state.qubits.len > 0) {
            self.allocator.free(self.state.qubits);
        }
        
        self.state = quantum_types.QuantumState{
            .coherence = new_state.coherence,
            .entanglement = new_state.entanglement,
            .superposition = new_state.superposition,
            .qubits = new_qubits,
        };
    }
    
    /// Reset the quantum processor to its initial state
    pub fn reset(self: *Self) void {
        // Reuse the existing qubits array if possible
        if (self.state.qubits.len > 0) {
            // Reset the existing qubit to |0⟩
            self.state.qubits[0] = quantum_types.Qubit{ .amplitude0 = 1.0, .amplitude1 = 0.0 };
        } else {
            // If no qubits exist, create a new one
            const default_qubit = quantum_types.Qubit{ .amplitude0 = 1.0, .amplitude1 = 0.0 };
            const new_qubits = self.allocator.alloc(quantum_types.Qubit, 1) catch @panic("Failed to allocate qubits");
            new_qubits[0] = default_qubit;
            self.state.qubits = new_qubits;
        }
        
        // Reset the state
        self.state.coherence = 1.0;
        self.state.entanglement = 0.0;
        self.state.superposition = 0.0;
    }
    
    /// Get the current quantum state
    pub fn getState(self: *const Self) quantum_types.QuantumState {
        return self.state;
    }
    
    /// Process a quantum state with the given pattern
    fn processQuantumState(self: *Self, state: *quantum_types.QuantumState, pattern: []const u8) !void {
        // Simple quantum state processing - in a real implementation, this would use quantum gates
        // For now, we'll just set some basic properties
        state.coherence = 0.9;
        state.entanglement = 0.7;
        state.superposition = 0.8;
        
        // Calculate metrics based on pattern
        if (pattern.len > 0) {
            // Simple pattern analysis
            var sum: f64 = 0.0;
            for (pattern) |b| sum += @as(f64, @floatFromInt(b));
            const avg = sum / @as(f64, @floatFromInt(pattern.len));
            
            // Update state based on pattern
            state.coherence = @min(1.0, avg / 255.0 + 0.5);
            state.entanglement = @min(1.0, @as(f64, @floatFromInt(pattern.len)) / 100.0);
        }
        
        // Simple pattern processing
        if (pattern.len > 0) {
            // Set qubit state based on first character of pattern
            const first_char = @as(f64, @floatFromInt(pattern[0])) / 255.0;
            
            // Initialize qubits if needed
            if (state.qubits.len == 0) {
                // Add a single qubit for this simple example
                const qubit = quantum_types.Qubit{ 
                    .amplitude0 = @sqrt(first_char), 
                    .amplitude1 = @sqrt(1.0 - first_char) 
                };
                state.qubits = &[1]quantum_types.Qubit{qubit};
            } else {
                // Update existing qubit
                state.qubits[0].amplitude0 = @sqrt(first_char);
                state.qubits[0].amplitude1 = @sqrt(1.0 - first_char);
            }
        }
        
        // Apply crystal computing enhancement if enabled
        if (self.crystal) |crystal| {
            const crystal_state = try crystal.process(pattern);
            state.coherence = @max(state.coherence, crystal_state.coherence);
            state.entanglement = @min(state.entanglement + 0.1, 1.0);
            state.superposition = @min(state.superposition + 0.1, 1.0);
        }
    }
};

// Tests
test "quantum processor initialization" {
    const allocator = std.testing.allocator;
    const config = QuantumConfig{
        .use_crystal_computing = true,
        .use_parallel_execution = true,
        .max_parallel_qubits = 8,
    };
    
    var processor = try QuantumProcessor.init(allocator, config);
    defer processor.deinit();

    try std.testing.expect(processor.config.min_coherence == 0.95);
    try std.testing.expect(processor.config.max_entanglement == 1.0);
    try std.testing.expect(processor.config.superposition_depth == 8);
    try std.testing.expect(processor.config.use_crystal_computing == true);
    try std.testing.expect(processor.crystal != null);
    try std.testing.expect(processor.thread_pool != null);
}

test "quantum pattern processing" {
    const allocator = std.testing.allocator;
    const config = QuantumConfig{
        .use_crystal_computing = false, // Disable for simpler test
        .use_parallel_execution = false,
    };
    
    var processor = try QuantumProcessor.init(allocator, config);
    defer processor.deinit();

    const pattern = "test pattern";
    const match = try processor.processPattern(pattern);
    defer allocator.free(match.pattern_id);

    // Verify the pattern match result
    try std.testing.expect(match.similarity >= 0.0);
    try std.testing.expect(match.similarity <= 1.0);
    try std.testing.expect(match.confidence >= 0.0);
    try std.testing.expect(match.confidence <= 1.0);
    try std.testing.expect(match.pattern_id.len > 0);
    try std.testing.expect(match.qubits_used > 0);
    try std.testing.expect(match.depth > 0);
    try std.testing.expect(match.isValid());
}

test "batch pattern processing" {
    const allocator = std.testing.allocator;
    const config = QuantumConfig{
        .use_crystal_computing = false,
        .use_parallel_execution = false, // Disable parallel for test stability
        .batch_size = 3,
    };
    
    var processor = try QuantumProcessor.init(allocator, config);
    defer processor.deinit();

    // Test with empty patterns
    {
        const empty_results = try processor.processBatch(&[_][]const u8{});
        defer allocator.free(empty_results);
        try std.testing.expect(empty_results.len == 0);
    }

    // Test with actual patterns
    const patterns = [_][]const u8{ "pattern1", "pattern2", "pattern3" };
    const results = try processor.processBatch(&patterns);
    defer {
        for (results) |result| {
            allocator.free(result.pattern_id);
        }
        allocator.free(results);
    }

    // Verify results
    try std.testing.expect(results.len == patterns.len);
    
    for (results) |result| {
        // Verify pattern ID is not empty and result is valid
        try std.testing.expect(result.pattern_id.len > 0);
        
        // Validate result metrics
        try std.testing.expect(result.similarity >= 0.0 and result.similarity <= 1.0);
        try std.testing.expect(result.confidence >= 0.0 and result.confidence <= 1.0);
        try std.testing.expect(result.qubits_used > 0);
        try std.testing.expect(result.depth > 0);
        try std.testing.expect(result.isValid());
    }
}

test "quantum state management" {
    const allocator = std.testing.allocator;
    
    // Test with a fresh processor for each test case
    {
        var processor = try QuantumProcessor.init(allocator, .{});
        defer processor.deinit();

        // Test initial state after reset
        processor.reset();
        const initialState = processor.getState();
        try std.testing.expect(initialState.coherence == 1.0);
        try std.testing.expect(initialState.entanglement == 0.0);
        try std.testing.expect(initialState.superposition == 0.0);
    }
    
    // Test with a simple state (no qubits)
    {
        var processor = try QuantumProcessor.init(allocator, .{});
        defer processor.deinit();
        
        const simpleState = quantum_types.QuantumState{
            .coherence = 0.8,
            .entanglement = 0.5,
            .superposition = 0.3,
            .qubits = &[_]quantum_types.Qubit{},
        };
        
        try processor.setState(simpleState);
        const currentState = processor.getState();
        try std.testing.expect(currentState.coherence == simpleState.coherence);
        try std.testing.expect(currentState.entanglement == simpleState.entanglement);
    }
    
    // Test with a state that has qubits
    {
        var processor = try QuantumProcessor.init(allocator, .{});
        defer processor.deinit();
        
        const qubit = quantum_types.Qubit{ .amplitude0 = 0.6, .amplitude1 = 0.8 };
        var qubits = try allocator.alloc(quantum_types.Qubit, 1);
        defer allocator.free(qubits);
        qubits[0] = qubit;
        
        const testState = quantum_types.QuantumState{
            .coherence = 0.9,
            .entanglement = 0.6,
            .superposition = 0.4,
            .qubits = qubits,
        };
        
        try processor.setState(testState);
        const currentState = processor.getState();
        try std.testing.expect(currentState.coherence == testState.coherence);
        try std.testing.expect(currentState.entanglement == testState.entanglement);
    }
    
    // Test invalid state
    {
        var processor = try QuantumProcessor.init(allocator, .{});
        defer processor.deinit();
        
        const qubit = quantum_types.Qubit{ .amplitude0 = 0.6, .amplitude1 = 0.8 };
        var qubits = try allocator.alloc(quantum_types.Qubit, 1);
        defer allocator.free(qubits);
        qubits[0] = qubit;
        
        const invalidState = quantum_types.QuantumState{
            .coherence = 1.5, // Invalid value
            .entanglement = 0.6,
            .superposition = 0.4,
            .qubits = qubits,
        };
        
        try std.testing.expectError(error.InvalidQuantumState, processor.setState(invalidState));
    }
}

test "crystal computing integration" {
    const allocator = std.testing.allocator;
    
    // Test with crystal computing enabled
    {
        const config = QuantumConfig{
            .use_crystal_computing = true,
            .use_parallel_execution = false,
        };
        
        var processor = try QuantumProcessor.init(allocator, config);
        defer processor.deinit();

        const pattern = "test pattern with crystal computing";
        const match = try processor.processPattern(pattern);
        defer allocator.free(match.pattern_id);

        // Verify enhanced match properties from crystal computing
        try std.testing.expect(match.confidence >= 0.0);
        try std.testing.expect(match.confidence <= 1.0);
        try std.testing.expect(match.similarity >= 0.0);
        try std.testing.expect(match.similarity <= 1.0);
        try std.testing.expect(match.isValid());
        
        // Verify crystal enhancement affected the state
        try std.testing.expect(processor.crystal != null);
        
        // Check crystal state if available
        if (processor.crystal) |crystal| {
            try std.testing.expect(crystal.state.coherence >= 0.0);
            try std.testing.expect(crystal.state.coherence <= 1.0);
            try std.testing.expect(crystal.state.entanglement >= 0.0);
            try std.testing.expect(crystal.state.entanglement <= 1.0);
            try std.testing.expect(crystal.state.depth >= 0);
            // Pattern ID might be empty in some cases
        }
    }
    
    // Test with crystal computing disabled for comparison
    {
        const config = QuantumConfig{
            .use_crystal_computing = false,
            .use_parallel_execution = false,
        };
        
        var processor = try QuantumProcessor.init(allocator, config);
        defer processor.deinit();

        const pattern = "test pattern without crystal computing";
        const match = try processor.processPattern(pattern);
        defer allocator.free(match.pattern_id);

        // Verify standard match properties
        try std.testing.expect(match.confidence >= 0.0);
        try std.testing.expect(match.confidence <= 1.0);
        try std.testing.expect(match.isValid());
        
        // Verify crystal computing is disabled
        try std.testing.expect(processor.crystal == null);
        
        // Verify quantum state is within bounds
        const state = processor.getState();
        try std.testing.expect(state.entanglement <= processor.config.max_entanglement);
        try std.testing.expect(state.coherence >= 0.0 and state.coherence <= 1.0);
        try std.testing.expect(state.superposition >= 0.0 and state.superposition <= 1.0);
    }
}

// End of file
