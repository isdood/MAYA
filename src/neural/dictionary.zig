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

    /// Compression settings
    pub const CompressionConfig = struct {
        min_compression: f64 = 0.0,    // No compression for most important patterns
        max_compression: f64 = 0.8,    // Maximum compression for least important
        compression_threshold: f64 = 0.5, // Importance threshold for compression
        quantum_precision: u8 = 8,     // Bits of precision for quantum values
        neural_precision: u8 = 8,      // Bits of precision for neural values
    };

    /// Compressed pattern data
    pub const CompressedPattern = struct {
        name: []const u8,
        quantum_data: []u8,
        neural_data: []u8,
        metadata: []u8,
        compression_level: f64,
        original_size: usize,
        compressed_size: usize,

        pub fn deinit(self: *CompressedPattern, alloc: std.mem.Allocator) void {
            alloc.free(self.quantum_data);
            alloc.free(self.neural_data);
            alloc.free(self.metadata);
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
    compression_config: CompressionConfig,
    compressed_patterns: std.StringHashMap(CompressedPattern),

    /// Initialize with compression
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
            .compression_config = .{},
            .compressed_patterns = std.StringHashMap(CompressedPattern).init(alloc),
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

    /// Compress a pattern based on its importance
    fn compressPattern(self: *Self, pattern: CorePattern, importance: PatternImportance) !CompressedPattern {
        const compression_level = if (importance.total_score >= self.compression_config.compression_threshold)
            self.compression_config.min_compression
        else
            self.compression_config.max_compression * (1.0 - importance.total_score);

        // Calculate original size
        const original_size = @sizeOf(CorePattern) + pattern.name.len + 
            pattern.related_patterns.items.len * @sizeOf([]const u8);

        // Compress quantum data
        var quantum_data = try self.allocator.alloc(u8, @sizeOf(neural.QuantumState));
        const quantum_bytes = std.mem.toBytes(pattern.quantum_signature);
        @memcpy(quantum_data, &quantum_bytes);

        // Compress neural data
        var neural_data = try self.allocator.alloc(u8, @sizeOf(f64));
        const neural_bytes = std.mem.toBytes(pattern.neural_signature);
        @memcpy(neural_data, &neural_bytes);

        // Compress metadata
        var metadata = try self.allocator.alloc(u8, @sizeOf(f64) * 3 + @sizeOf(usize));
        var metadata_writer = std.io.fixedBufferStream(metadata).writer();
        try metadata_writer.writeFloat(f64, pattern.confidence, .little);
        try metadata_writer.writeInt(u64, pattern.usage_count, .little);
        try metadata_writer.writeFloat(f64, pattern.last_used, .little);

        // Apply compression based on level
        if (compression_level > 0.0) {
            // Reduce precision of quantum values
            const quantum_precision = @as(u8, @intFromFloat(@round(
                @as(f64, @floatFromInt(self.compression_config.quantum_precision)) * (1.0 - compression_level)
            )));
            try self.reducePrecision(quantum_data, quantum_precision);

            // Reduce precision of neural values
            const neural_precision = @as(u8, @intFromFloat(@round(
                @as(f64, @floatFromInt(self.compression_config.neural_precision)) * (1.0 - compression_level)
            )));
            try self.reducePrecision(neural_data, neural_precision);
        }

        return CompressedPattern{
            .name = pattern.name,
            .quantum_data = quantum_data,
            .neural_data = neural_data,
            .metadata = metadata,
            .compression_level = compression_level,
            .original_size = original_size,
            .compressed_size = quantum_data.len + neural_data.len + metadata.len,
        };
    }

    /// Reduce precision of floating-point values
    fn reducePrecision(self: *Self, data: []u8, precision: u8) !void {
        const float_size = @sizeOf(f64);
        var i: usize = 0;
        while (i < data.len) : (i += float_size) {
            if (i + float_size <= data.len) {
                const value = std.mem.readInt(f64, data[i..][0..float_size], .little);
                const reduced = self.reduceFloatPrecision(value, precision);
                std.mem.writeInt(f64, data[i..][0..float_size], reduced, .little);
            }
        }
    }

    /// Reduce floating-point precision
    fn reduceFloatPrecision(self: *Self, value: f64, precision: u8) f64 {
        const factor = std.math.pow(f64, 2.0, @as(f64, @floatFromInt(precision)));
        return @round(value * factor) / factor;
    }

    /// Decompress a pattern
    fn decompressPattern(self: *Self, compressed: CompressedPattern) !CorePattern {
        // Reconstruct quantum signature
        var quantum_signature: neural.QuantumState = undefined;
        @memcpy(&std.mem.toBytes(&quantum_signature), compressed.quantum_data);

        // Reconstruct neural signature
        var neural_signature: f64 = undefined;
        @memcpy(&std.mem.toBytes(&neural_signature), compressed.neural_data);

        // Reconstruct metadata
        var metadata_reader = std.io.fixedBufferStream(compressed.metadata).reader();
        const confidence = try metadata_reader.readFloat(f64, .little);
        const usage_count = try metadata_reader.readInt(u64, .little);
        const last_used = try metadata_reader.readFloat(f64, .little);

        return CorePattern{
            .name = compressed.name,
            .description = "Decompressed pattern",
            .quantum_signature = quantum_signature,
            .neural_signature = neural_signature,
            .glimmer_pattern = glimmer.GlimmerPattern.init(.{
                .pattern_type = .quantum_wave,
                .base_color = glimmer.colors.GlimmerColors.quantum,
                .intensity = 1.0,
                .frequency = 1.0,
                .phase = 0.0,
            }),
            .confidence = confidence,
            .usage_count = usage_count,
            .last_used = last_used,
            .related_patterns = std.ArrayList([]const u8).init(self.allocator),
        };
    }

    /// Save patterns with compression
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
            const importance = self.pattern_importance.get(pattern.name) orelse continue;
            
            // Compress pattern
            const compressed = try self.compressPattern(pattern.*, importance.*);
            defer compressed.deinit(self.allocator);

            // Write compressed data
            try writer.writeInt(u32, @intCast(compressed.name.len), .little);
            try writer.writeAll(compressed.name);
            try writer.writeFloat(f64, compressed.compression_level, .little);
            try writer.writeInt(u64, compressed.original_size, .little);
            try writer.writeInt(u64, compressed.compressed_size, .little);
            try writer.writeAll(compressed.quantum_data);
            try writer.writeAll(compressed.neural_data);
            try writer.writeAll(compressed.metadata);
        }
    }

    /// Load patterns with decompression
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

            // Read compression info
            const compression_level = try reader.readFloat(f64, .little);
            const original_size = try reader.readInt(u64, .little);
            const compressed_size = try reader.readInt(u64, .little);

            // Read compressed data
            var quantum_data = try self.allocator.alloc(u8, @sizeOf(neural.QuantumState));
            _ = try reader.read(quantum_data);
            var neural_data = try self.allocator.alloc(u8, @sizeOf(f64));
            _ = try reader.read(neural_data);
            var metadata = try self.allocator.alloc(u8, @sizeOf(f64) * 3 + @sizeOf(usize));
            _ = try reader.read(metadata);

            // Create compressed pattern
            const compressed = CompressedPattern{
                .name = name,
                .quantum_data = quantum_data,
                .neural_data = neural_data,
                .metadata = metadata,
                .compression_level = compression_level,
                .original_size = original_size,
                .compressed_size = compressed_size,
            };

            // Decompress pattern
            const pattern = try self.decompressPattern(compressed);
            try self.patterns.put(pattern.name, pattern);
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