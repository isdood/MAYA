const std = @import("std");
const neural = @import("neural");
const glimmer = @import("glimmer");

/// MAYA's core vocabulary and pattern dictionary
pub const MayaDictionary = struct {
    const Self = @This();

    /// Core pattern definitions
    pub const CorePattern = struct {
        name: []const u8,
        description: []const u8,
        quantum_signature: neural.QuantumState,
        neural_signature: f64,
        glimmer_pattern: glimmer.GlimmerPattern,
        confidence: f64,
        usage_count: usize,
        last_used: f64,
        related_patterns: std.ArrayList([]const u8),
    };

    /// Pattern categories
    pub const PatternCategory = enum {
        quantum,
        neural,
        cosmic,
        stellar,
        hybrid,
    };

    /// Pattern relationships
    pub const PatternRelationship = struct {
        source: []const u8,
        target: []const u8,
        strength: f64,
        type: RelationshipType,
        last_observed: f64,

        pub const RelationshipType = enum {
            transformation,
            combination,
            evolution,
            resonance,
        };
    };

    allocator: std.mem.Allocator,
    patterns: std.StringHashMap(CorePattern),
    relationships: std.ArrayList(PatternRelationship),
    learning_rate: f64,
    confidence_threshold: f64,
    max_patterns: usize,

    /// Initialize the dictionary with core patterns
    pub fn init(alloc: std.mem.Allocator) !Self {
        var self = Self{
            .allocator = alloc,
            .patterns = std.StringHashMap(CorePattern).init(alloc),
            .relationships = std.ArrayList(PatternRelationship).init(alloc),
            .learning_rate = 0.1,
            .confidence_threshold = 0.7,
            .max_patterns = 1000,
        };

        // Initialize with core patterns
        try self.initializeCorePatterns();
        return self;
    }

    /// Deinitialize the dictionary
    pub fn deinit(self: *Self) void {
        // Free pattern memory
        var it = self.patterns.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.related_patterns.deinit();
        }
        self.patterns.deinit();

        // Free relationships
        self.relationships.deinit();
    }

    /// Initialize core patterns
    fn initializeCorePatterns(self: *Self) !void {
        // Quantum Wave Pattern
        try self.patterns.put("quantum_wave", .{
            .name = "quantum_wave",
            .description = "A fundamental quantum oscillation pattern",
            .quantum_signature = .{
                .amplitude = 1.0,
                .phase = 0.0,
                .energy = 1.0,
                .resonance = 0.0,
                .coherence = 1.0,
            },
            .neural_signature = 0.5,
            .glimmer_pattern = glimmer.GlimmerPattern.init(.{
                .pattern_type = .quantum_wave,
                .base_color = glimmer.colors.GlimmerColors.quantum,
                .intensity = 1.0,
                .frequency = 1.0,
                .phase = 0.0,
            }),
            .confidence = 1.0,
            .usage_count = 0,
            .last_used = 0.0,
            .related_patterns = std.ArrayList([]const u8).init(self.allocator),
        });

        // Neural Flow Pattern
        try self.patterns.put("neural_flow", .{
            .name = "neural_flow",
            .description = "A dynamic neural activity pattern",
            .quantum_signature = .{
                .amplitude = 0.8,
                .phase = std.math.pi / 4,
                .energy = 0.8,
                .resonance = 0.5,
                .coherence = 0.9,
            },
            .neural_signature = 0.7,
            .glimmer_pattern = glimmer.GlimmerPattern.init(.{
                .pattern_type = .neural_flow,
                .base_color = glimmer.colors.GlimmerColors.neural,
                .intensity = 0.8,
                .frequency = 1.5,
                .phase = std.math.pi / 4,
            }),
            .confidence = 1.0,
            .usage_count = 0,
            .last_used = 0.0,
            .related_patterns = std.ArrayList([]const u8).init(self.allocator),
        });

        // Add initial relationships
        try self.relationships.append(.{
            .source = "quantum_wave",
            .target = "neural_flow",
            .strength = 0.8,
            .type = .resonance,
            .last_observed = 0.0,
        });
    }

    /// Learn a new pattern from observation
    pub fn learnPattern(self: *Self, 
        name: []const u8,
        quantum_state: neural.QuantumState,
        neural_activity: f64,
        glimmer_pattern: glimmer.GlimmerPattern
    ) !void {
        // Check if pattern exists
        if (self.patterns.get(name)) |existing| {
            // Update existing pattern
            var pattern = existing;
            pattern.quantum_signature = quantum_state;
            pattern.neural_signature = neural_activity;
            pattern.glimmer_pattern = glimmer_pattern;
            pattern.confidence = @min(1.0, pattern.confidence + self.learning_rate);
            pattern.usage_count += 1;
            pattern.last_used = @floatFromInt(std.time.timestamp());
            try self.patterns.put(name, pattern);
        } else if (self.patterns.count() < self.max_patterns) {
            // Create new pattern
            try self.patterns.put(name, .{
                .name = name,
                .description = "Learned pattern",
                .quantum_signature = quantum_state,
                .neural_signature = neural_activity,
                .glimmer_pattern = glimmer_pattern,
                .confidence = self.learning_rate,
                .usage_count = 1,
                .last_used = @floatFromInt(std.time.timestamp()),
                .related_patterns = std.ArrayList([]const u8).init(self.allocator),
            });
        }
    }

    /// Find similar patterns
    pub fn findSimilarPatterns(self: *Self, 
        quantum_state: neural.QuantumState,
        neural_activity: f64,
        max_results: usize
    ) ![]CorePattern {
        var results = std.ArrayList(CorePattern).init(self.allocator);
        defer results.deinit();

        var it = self.patterns.iterator();
        while (it.next()) |entry| {
            const pattern = entry.value_ptr;
            
            // Calculate similarity score
            const quantum_similarity = self.calculateQuantumSimilarity(
                quantum_state,
                pattern.quantum_signature
            );
            const neural_similarity = self.calculateNeuralSimilarity(
                neural_activity,
                pattern.neural_signature
            );
            const total_similarity = (quantum_similarity + neural_similarity) * 0.5;

            if (total_similarity >= self.confidence_threshold) {
                try results.append(pattern.*);
                if (results.items.len >= max_results) break;
            }
        }

        return results.toOwnedSlice();
    }

    /// Calculate quantum state similarity
    fn calculateQuantumSimilarity(self: *Self, a: neural.QuantumState, b: neural.QuantumState) f64 {
        const amplitude_diff = @abs(a.amplitude - b.amplitude);
        const phase_diff = @abs(a.phase - b.phase);
        const energy_diff = @abs(a.energy - b.energy);
        const resonance_diff = @abs(a.resonance - b.resonance);
        const coherence_diff = @abs(a.coherence - b.coherence);

        return 1.0 - (amplitude_diff + phase_diff + energy_diff + resonance_diff + coherence_diff) / 5.0;
    }

    /// Calculate neural activity similarity
    fn calculateNeuralSimilarity(self: *Self, a: f64, b: f64) f64 {
        return 1.0 - @abs(a - b);
    }

    /// Update pattern relationships
    pub fn updateRelationships(self: *Self, 
        source: []const u8,
        target: []const u8,
        relationship_type: PatternRelationship.RelationshipType
    ) !void {
        // Check if relationship exists
        for (self.relationships.items) |*rel| {
            if (std.mem.eql(u8, rel.source, source) and std.mem.eql(u8, rel.target, target)) {
                rel.strength = @min(1.0, rel.strength + self.learning_rate);
                rel.last_observed = @floatFromInt(std.time.timestamp());
                return;
            }
        }

        // Create new relationship
        try self.relationships.append(.{
            .source = source,
            .target = target,
            .strength = self.learning_rate,
            .type = relationship_type,
            .last_observed = @floatFromInt(std.time.timestamp()),
        });
    }
}; 