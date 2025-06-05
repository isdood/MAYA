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

    /// Memory consolidation settings
    pub const ConsolidationConfig = struct {
        max_patterns: usize = 1000,
        min_confidence: f64 = 0.3,
        consolidation_interval: f64 = 3600.0, // 1 hour
        decay_rate: f64 = 0.1,
        importance_threshold: f64 = 0.7,
        max_storage_mb: usize = 100, // 100MB limit
    };

    /// Pattern importance metrics
    pub const PatternImportance = struct {
        usage_frequency: f64,
        relationship_strength: f64,
        quantum_significance: f64,
        neural_impact: f64,
        last_accessed: f64,
        total_score: f64,

        pub fn calculate(self: *PatternImportance) void {
            // Weighted combination of factors
            self.total_score = 
                self.usage_frequency * 0.3 +
                self.relationship_strength * 0.2 +
                self.quantum_significance * 0.2 +
                self.neural_impact * 0.2 +
                (1.0 - (std.time.timestamp() - self.last_accessed) / 86400.0) * 0.1; // Recency bonus
        }
    };

    allocator: std.mem.Allocator,
    patterns: std.StringHashMap(CorePattern),
    relationships: std.ArrayList(PatternRelationship),
    learning_rate: f64,
    confidence_threshold: f64,
    max_patterns: usize,
    config: ConsolidationConfig,
    last_consolidation: f64,
    pattern_importance: std.StringHashMap(PatternImportance),
    storage_path: []const u8,

    /// Initialize with persistence
    pub fn init(alloc: std.mem.Allocator, config: ConsolidationConfig, storage_path: []const u8) !Self {
        var self = Self{
            .allocator = alloc,
            .patterns = std.StringHashMap(CorePattern).init(alloc),
            .relationships = std.ArrayList(PatternRelationship).init(alloc),
            .learning_rate = 0.1,
            .confidence_threshold = 0.7,
            .max_patterns = config.max_patterns,
            .config = config,
            .last_consolidation = @floatFromInt(std.time.timestamp()),
            .pattern_importance = std.StringHashMap(PatternImportance).init(alloc),
            .storage_path = storage_path,
        };

        // Load existing patterns if available
        try self.loadPatterns();
        
        // Initialize core patterns if no patterns exist
        if (self.patterns.count() == 0) {
            try self.initializeCorePatterns();
        }

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

    /// Save patterns to disk
    pub fn savePatterns(self: *Self) !void {
        const file = try std.fs.cwd().createFile(self.storage_path, .{});
        defer file.close();

        var writer = file.writer();
        
        // Write pattern count
        try writer.writeInt(u32, @intCast(self.patterns.count()), .little);
        
        // Write each pattern
        var it = self.patterns.iterator();
        while (it.next()) |entry| {
            const pattern = entry.value_ptr;
            
            // Write pattern name
            try writer.writeInt(u32, @intCast(pattern.name.len), .little);
            try writer.writeAll(pattern.name);
            
            // Write pattern data
            try writer.writeAll(&std.mem.toBytes(pattern.quantum_signature));
            try writer.writeFloat(f64, pattern.neural_signature, .little);
            try writer.writeFloat(f64, pattern.confidence, .little);
            try writer.writeInt(u64, pattern.usage_count, .little);
            try writer.writeFloat(f64, pattern.last_used, .little);
            
            // Write related patterns
            try writer.writeInt(u32, @intCast(pattern.related_patterns.items.len), .little);
            for (pattern.related_patterns.items) |related| {
                try writer.writeInt(u32, @intCast(related.len), .little);
                try writer.writeAll(related);
            }
        }
    }

    /// Load patterns from disk
    pub fn loadPatterns(self: *Self) !void {
        const file = std.fs.cwd().openFile(self.storage_path, .{}) catch return;
        defer file.close();

        var reader = file.reader();
        
        // Read pattern count
        const count = try reader.readInt(u32, .little);
        
        // Read each pattern
        var i: usize = 0;
        while (i < count) : (i += 1) {
            // Read pattern name
            const name_len = try reader.readInt(u32, .little);
            var name = try self.allocator.alloc(u8, name_len);
            _ = try reader.read(name);
            
            // Read pattern data
            var quantum_signature: neural.QuantumState = undefined;
            _ = try reader.readAll(&std.mem.toBytes(&quantum_signature));
            const neural_signature = try reader.readFloat(f64, .little);
            const confidence = try reader.readFloat(f64, .little);
            const usage_count = try reader.readInt(u64, .little);
            const last_used = try reader.readFloat(f64, .little);
            
            // Read related patterns
            const related_count = try reader.readInt(u32, .little);
            var related_patterns = std.ArrayList([]const u8).init(self.allocator);
            var j: usize = 0;
            while (j < related_count) : (j += 1) {
                const related_len = try reader.readInt(u32, .little);
                var related = try self.allocator.alloc(u8, related_len);
                _ = try reader.read(related);
                try related_patterns.append(related);
            }
            
            // Create pattern
            try self.patterns.put(name, .{
                .name = name,
                .description = "Loaded pattern",
                .quantum_signature = quantum_signature,
                .neural_signature = neural_signature,
                .glimmer_pattern = glimmer.GlimmerPattern.init(.{
                    .pattern_type = .quantum_wave, // Default, will be updated
                    .base_color = glimmer.colors.GlimmerColors.quantum,
                    .intensity = 1.0,
                    .frequency = 1.0,
                    .phase = 0.0,
                }),
                .confidence = confidence,
                .usage_count = usage_count,
                .last_used = last_used,
                .related_patterns = related_patterns,
            });
        }
    }

    /// Consolidate memory (prune and strengthen patterns)
    pub fn consolidateMemory(self: *Self) !void {
        const current_time = @floatFromInt(std.time.timestamp());
        if (current_time - self.last_consolidation < self.config.consolidation_interval) {
            return;
        }

        // Calculate importance scores
        var it = self.patterns.iterator();
        while (it.next()) |entry| {
            const pattern = entry.value_ptr;
            var importance = PatternImportance{
                .usage_frequency = @floatFromInt(pattern.usage_count) / (current_time - pattern.last_used),
                .relationship_strength = 0.0,
                .quantum_significance = pattern.quantum_signature.coherence,
                .neural_impact = pattern.neural_signature,
                .last_accessed = pattern.last_used,
                .total_score = 0.0,
            };

            // Calculate relationship strength
            for (self.relationships.items) |rel| {
                if (std.mem.eql(u8, rel.source, pattern.name) or 
                    std.mem.eql(u8, rel.target, pattern.name)) {
                    importance.relationship_strength += rel.strength;
                }
            }

            importance.calculate();
            try self.pattern_importance.put(pattern.name, importance);
        }

        // Sort patterns by importance
        var patterns_to_keep = std.ArrayList(CorePattern).init(self.allocator);
        defer patterns_to_keep.deinit();

        var importance_it = self.pattern_importance.iterator();
        while (importance_it.next()) |entry| {
            const importance = entry.value_ptr;
            if (importance.total_score >= self.config.importance_threshold) {
                if (self.patterns.get(entry.key_ptr.*)) |pattern| {
                    try patterns_to_keep.append(pattern.*);
                }
            }
        }

        // Clear and rebuild pattern storage
        self.patterns.clearRetainingCapacity();
        for (patterns_to_keep.items) |pattern| {
            try self.patterns.put(pattern.name, pattern);
        }

        // Update consolidation time
        self.last_consolidation = current_time;

        // Save consolidated patterns
        try self.savePatterns();
    }

    /// Check storage size and trigger consolidation if needed
    pub fn checkStorageSize(self: *Self) !void {
        const file = std.fs.cwd().openFile(self.storage_path, .{}) catch return;
        defer file.close();

        const stat = try file.stat();
        const size_mb = stat.size / (1024 * 1024);

        if (size_mb >= self.config.max_storage_mb) {
            try self.consolidateMemory();
        }
    }
}; 