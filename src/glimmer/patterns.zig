const std = @import("std");
const colors = @import("colors");

/// GLIMMER pattern system for neural-responsive visual patterns
pub const GlimmerPattern = struct {
    const Self = @This();

    /// Pattern types that respond to neural activity
    pub const PatternType = enum {
        quantum_wave,
        neural_flow,
        cosmic_sparkle,
        stellar_pulse,
    };

    /// Pattern configuration
    pub const Config = struct {
        pattern_type: PatternType,
        base_color: colors.GlimmerColors.Color,
        intensity: f32,
        frequency: f32,
        phase: f32,
    };

    /// Pattern state
    pub const PatternState = struct {
        current_color: colors.GlimmerColors.Color,
        amplitude: f32,
        last_update: f32,
        energy: f32,
        resonance: f32,
    };

    pub const PatternTransition = struct {
        target_config: Config,
        duration: f32,
        elapsed: f32,
        easing: EasingFunction,

        pub const EasingFunction = enum {
            linear,
            ease_in_out,
            quantum_bounce,
            neural_flow,
        };

        pub fn calculateProgress(self: *const PatternTransition) f32 {
            const t = self.elapsed / self.duration;
            return switch (self.easing) {
                .linear => t,
                .ease_in_out => 0.5 - 0.5 * @cos(t * std.math.pi),
                .quantum_bounce => @sin(t * std.math.pi * 2.0) * 0.5 + 0.5,
                .neural_flow => @sin(t * std.math.pi) * 0.5 + 0.5,
            };
        }
    };

    pub const ValidationError = error{
        InvalidIntensity,
        InvalidFrequency,
        InvalidPhase,
        QuantumCoherenceViolation,
        NeuralResonanceMismatch,
    };

    name: []const u8,
    pattern_type: PatternType,
    base_color: colors.GlimmerColors.Color,
    intensity: f32,
    frequency: f32,
    phase: f32,
    state: PatternState,
    transition: ?PatternTransition,

    pub fn init(name: []const u8, pattern_type: PatternType) Self {
        return Self{
            .name = name,
            .pattern_type = pattern_type,
            .base_color = colors.GlimmerColors.quantum_blue,
            .intensity = 0.5,
            .frequency = 1.0,
            .phase = 0.0,
            .state = .{
                .current_color = colors.GlimmerColors.quantum_blue,
                .amplitude = 0.0,
                .last_update = 0.0,
                .energy = 1.0,
                .resonance = 0.0,
            },
            .transition = null,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Update pattern based on neural activity
    pub fn update(self: *Self, neural_activity: f32, delta_time: f32) !void {
        // Validate pattern before update
        try self.validate();

        // Update transition if active
        if (self.transition) |*transition| {
            transition.elapsed += delta_time;
            const progress = transition.calculateProgress();

            if (progress >= 1.0) {
                // Transition complete
                self.* = Self.init(self.name, self.pattern_type);
                self.transition = null;
            } else {
                // Interpolate between current and target pattern
                const target_pattern = Self.init(self.name, transition.target_config.pattern_type);
                const interpolated = self.interpolatePatterns(&target_pattern, progress);
                self.* = interpolated;
                return;
            }
        }

        const time = self.state.last_update + delta_time;
        
        // Update resonance based on neural activity
        self.state.resonance = @sin(2.0 * std.math.pi * self.frequency * time + self.phase) * neural_activity;
        
        // Calculate energy based on pattern type
        switch (self.pattern_type) {
            .quantum_wave => {
                self.state.energy = @cos(self.state.resonance * std.math.pi) * 0.5 + 0.5;
            },
            .neural_flow => {
                self.state.energy = @sin(self.state.resonance * std.math.pi * 2.0) * 0.5 + 0.5;
            },
            .cosmic_sparkle => {
                self.state.energy = @sin(self.state.resonance * std.math.pi * 4.0) * 0.5 + 0.5;
            },
            .stellar_pulse => {
                self.state.energy = @cos(self.state.resonance * std.math.pi * 3.0) * 0.5 + 0.5;
            },
        }

        // Calculate amplitude with energy influence
        const wave = @sin(2.0 * std.math.pi * self.frequency * time + self.phase);
        self.state.amplitude = wave * self.intensity * neural_activity * self.state.energy;

        // Update color based on pattern type and energy
        switch (self.pattern_type) {
            .quantum_wave => {
                const quantum_color = colors.GlimmerColors.quantum_blue.blend(
                    colors.GlimmerColors.neural_purple,
                    self.state.energy,
                );
                self.state.current_color = self.base_color.blend(
                    quantum_color,
                    self.state.amplitude,
                );
            },
            .neural_flow => {
                const neural_color = colors.GlimmerColors.neural_purple.blend(
                    colors.GlimmerColors.cosmic_gold,
                    self.state.energy,
                );
                self.state.current_color = self.base_color.blend(
                    neural_color,
                    self.state.amplitude,
                );
            },
            .cosmic_sparkle => {
                const cosmic_color = colors.GlimmerColors.cosmic_gold.blend(
                    colors.GlimmerColors.quantum_blue,
                    self.state.energy,
                );
                self.state.current_color = self.base_color.blend(
                    cosmic_color,
                    self.state.amplitude,
                );
            },
            .stellar_pulse => {
                const stellar_color = colors.GlimmerColors.neural_purple.blend(
                    colors.GlimmerColors.quantum_blue,
                    self.state.energy,
                );
                self.state.current_color = self.base_color.blend(
                    stellar_color,
                    self.state.amplitude,
                );
            },
        }

        self.state.last_update = time;
    }

    pub fn validate(self: *const Self) ValidationError!void {
        // Validate basic parameters
        if (self.intensity < 0.0 or self.intensity > 1.0) {
            return ValidationError.InvalidIntensity;
        }
        if (self.frequency <= 0.0 or self.frequency > 10.0) {
            return ValidationError.InvalidFrequency;
        }
        if (self.phase < 0.0 or self.phase > 2.0 * std.math.pi) {
            return ValidationError.InvalidPhase;
        }

        // Validate quantum coherence
        const coherence = self.calculateQuantumCoherence();
        if (coherence < 0.7) {
            return ValidationError.QuantumCoherenceViolation;
        }

        // Validate neural resonance
        const resonance = self.calculateNeuralResonance();
        if (resonance < 0.5) {
            return ValidationError.NeuralResonanceMismatch;
        }
    }

    fn calculateQuantumCoherence(self: *const Self) f32 {
        // Calculate quantum coherence based on pattern type and state
        var base_coherence: f32 = 0.0;
        switch (self.pattern_type) {
            .quantum_wave => base_coherence = 0.9,
            .neural_flow => base_coherence = 0.8,
            .cosmic_sparkle => base_coherence = 0.85,
            .stellar_pulse => base_coherence = 0.75,
        }

        // Adjust coherence based on energy and resonance
        const energy_factor = self.state.energy * 0.2;
        const resonance_factor = @abs(self.state.resonance) * 0.1;

        return base_coherence + energy_factor + resonance_factor;
    }

    fn calculateNeuralResonance(self: *const Self) f32 {
        // Calculate neural resonance based on pattern type and frequency
        var base_resonance: f32 = 0.0;
        switch (self.pattern_type) {
            .quantum_wave => base_resonance = 0.8,
            .neural_flow => base_resonance = 0.9,
            .cosmic_sparkle => base_resonance = 0.7,
            .stellar_pulse => base_resonance = 0.85,
        }

        // Adjust resonance based on frequency and phase
        const frequency_factor = (self.frequency / 10.0) * 0.1;
        const phase_factor = (self.phase / (2.0 * std.math.pi)) * 0.1;

        return base_resonance + frequency_factor + phase_factor;
    }

    fn interpolatePatterns(source: *const Self, target: *const Self, progress: f32) Self {
        return Self{
            .name = source.name,
            .pattern_type = target.pattern_type,
            .base_color = source.base_color.blend(target.base_color, progress),
            .intensity = source.intensity + (target.intensity - source.intensity) * progress,
            .frequency = source.frequency + (target.frequency - source.frequency) * progress,
            .phase = source.phase + (target.phase - source.phase) * progress,
            .state = .{
                .current_color = source.state.current_color.blend(target.state.current_color, progress),
                .amplitude = source.state.amplitude + (target.state.amplitude - source.state.amplitude) * progress,
                .energy = source.state.energy + (target.state.energy - source.state.energy) * progress,
                .resonance = source.state.resonance + (target.state.resonance - source.state.resonance) * progress,
                .last_update = source.state.last_update,
            },
            .transition = null,
        };
    }

    pub fn startTransition(self: *Self, target_config: Config, duration: f32, easing: PatternTransition.EasingFunction) void {
        self.transition = .{
            .target_config = target_config,
            .duration = duration,
            .elapsed = 0.0,
            .easing = easing,
        };
    }

    pub fn combinePatterns(pattern_list: []const Self, weights: []const f32) !Self {
        if (pattern_list.len == 0 or pattern_list.len != weights.len) {
            return error.InvalidPatternCombination;
        }

        var combined = Self.init("", pattern_list[0].pattern_type);

        var total_weight: f32 = 0.0;
        for (weights) |w| {
            total_weight += w;
        }

        if (total_weight == 0.0) {
            return error.InvalidWeights;
        }

        // Normalize weights
        for (pattern_list, 0..) |pattern, i| {
            const normalized_weight = weights[i] / total_weight;
            combined.intensity += pattern.intensity * normalized_weight;
            combined.frequency += pattern.frequency * normalized_weight;
            combined.phase += pattern.phase * normalized_weight;
            combined.state.energy += pattern.state.energy * normalized_weight;
            combined.state.resonance += pattern.state.resonance * normalized_weight;
            combined.state.current_color = combined.state.current_color.blend(
                pattern.state.current_color,
                normalized_weight,
            );
        }

        return combined;
    }
};

var global_patterns: ?[]GlimmerPattern = null;

pub fn init() !void {
    if (global_patterns != null) return;
    
    // Create default patterns
    const default_patterns = [_]GlimmerPattern.Config{
        .{
            .pattern_type = .quantum_wave,
            .base_color = colors.GlimmerColors.quantum_blue,
            .intensity = 0.5,
            .frequency = 1.0,
            .phase = 0.0,
        },
        .{
            .pattern_type = .neural_flow,
            .base_color = colors.GlimmerColors.neural_purple,
            .intensity = 0.7,
            .frequency = 1.5,
            .phase = 0.5,
        },
        .{
            .pattern_type = .cosmic_sparkle,
            .base_color = colors.GlimmerColors.cosmic_gold,
            .intensity = 0.6,
            .frequency = 2.0,
            .phase = 1.0,
        },
        .{
            .pattern_type = .stellar_pulse,
            .base_color = colors.GlimmerColors.neural_purple,
            .intensity = 0.8,
            .frequency = 1.2,
            .phase = 1.5,
        },
    };

    global_patterns = try std.heap.page_allocator.alloc(GlimmerPattern, default_patterns.len);
    for (default_patterns, 0..) |config, i| {
        global_patterns.?[i] = GlimmerPattern.init("", config.pattern_type);
    }
}

pub fn deinit() void {
    if (global_patterns) |p| {
        std.heap.page_allocator.free(p);
    }
    global_patterns = null;
}

pub fn processPatterns() !void {
    if (global_patterns == null) return error.NotInitialized;
    if (global_patterns) |p| {
        for (p) |*pattern| {
            try pattern.update(0.5, 0.016); // Simulate 60 FPS
        }
    }
}

test "GlimmerPattern" {
    const config = GlimmerPattern.Config{
        .pattern_type = .quantum_wave,
        .base_color = colors.GlimmerColors.quantum_blue,
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    };

    var pattern = GlimmerPattern.init("", config.pattern_type);
    try pattern.update(0.5, 0.1);
    try std.testing.expect(pattern.state.energy >= 0.0 and pattern.state.energy <= 1.0);
    try std.testing.expect(pattern.state.resonance >= -1.0 and pattern.state.resonance <= 1.0);
}

test "PatternValidation" {
    const valid_config = GlimmerPattern.Config{
        .pattern_type = .quantum_wave,
        .base_color = colors.GlimmerColors.quantum_blue,
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    };

    var valid_pattern = GlimmerPattern.init("", valid_config.pattern_type);
    try valid_pattern.validate();

    const invalid_intensity_config = GlimmerPattern.Config{
        .pattern_type = .quantum_wave,
        .base_color = colors.GlimmerColors.quantum_blue,
        .intensity = 1.5, // Invalid intensity
        .frequency = 1.0,
        .phase = 0.0,
    };

    var invalid_pattern = GlimmerPattern.init("", invalid_intensity_config.pattern_type);
    try std.testing.expectError(error.InvalidIntensity, invalid_pattern.validate());
}

test "PatternTransitions" {
    const source_config = GlimmerPattern.Config{
        .pattern_type = .quantum_wave,
        .base_color = colors.GlimmerColors.quantum_blue,
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    };

    const target_config = GlimmerPattern.Config{
        .pattern_type = .neural_flow,
        .base_color = colors.GlimmerColors.neural_purple,
        .intensity = 0.7,
        .frequency = 1.5,
        .phase = 0.5,
    };

    var pattern = GlimmerPattern.init("", source_config.pattern_type);
    pattern.startTransition(target_config, 1.0, .ease_in_out);
    try pattern.update(0.5, 0.5); // Update halfway through transition

    try std.testing.expect(pattern.transition != null);
    try std.testing.expect(pattern.intensity > 0.5 and pattern.intensity < 0.7);
    try std.testing.expect(pattern.frequency > 1.0 and pattern.frequency < 1.5);
}

test "PatternCombination" {
    const test_patterns = [_]GlimmerPattern{
        GlimmerPattern.init("", .quantum_wave),
        GlimmerPattern.init("", .neural_flow),
    };

    const combined = GlimmerPattern.combine(&test_patterns, &[_]f32{ 0.6, 0.4 });
    try std.testing.expect(combined.intensity > 0.0);
    try std.testing.expect(combined.frequency > 0.0);
}

/// Parse a GLIMMER pattern from a string buffer
pub fn parsePattern(input: []const u8) !?GlimmerPattern {
    std.debug.print("[DEBUG] parsePattern: Input: {s}\n", .{input});
    // Find metadata markers
    const meta_start = std.mem.indexOf(u8, input, "@pattern_meta@") orelse return null;
    const meta_end = std.mem.indexOf(u8, input[meta_start + 14..], "@pattern_meta@") orelse return null;
    const meta_section = input[meta_start + 14..meta_start + 14 + meta_end];
    std.debug.print("[DEBUG] parsePattern: Meta section: {s}\n", .{meta_section});
    // Parse metadata
    var pattern = GlimmerPattern.init("GLIMMER Pattern", .quantum_wave);
    
    // Parse metadata
    var lines = std.mem.splitSequence(u8, meta_section, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "GLIMMER Pattern:")) {
            // Found pattern header
            continue;
        }
        
        // Parse JSON-like metadata
        if (std.mem.indexOf(u8, trimmed, "\"pattern_version\"")) |_| {
            // Extract version info
            if (std.mem.indexOf(u8, trimmed, "1.0.0")) |_| {
                pattern.intensity = 0.8;
                pattern.frequency = 1.2;
            }
        }
        
        if (std.mem.indexOf(u8, trimmed, "\"color\"")) |_| {
            // Extract color info
            if (std.mem.indexOf(u8, trimmed, "#FF69B4")) |_| {
                pattern.base_color = colors.GlimmerColors.neural_purple;
            }
        }
    }
    
    return pattern;
}

/// Apply a GLIMMER pattern to a buffer and return the transformed result
pub fn applyPattern(pattern: GlimmerPattern, buffer: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    // For demonstration, we'll transform the buffer by appending pattern info
    // In a real implementation, this would apply visual or structural changes
    if (buffer.len == 0) return null;

    // Compose a header with pattern info
    const header = std.fmt.allocPrint(allocator,
        "[GLIMMER:{s}|Intensity:{d:.2}|Freq:{d:.2}]\n",
        .{
            @tagName(pattern.pattern_type),
            pattern.intensity,
            pattern.frequency
        }
    ) catch return null;

    // Allocate space for the new buffer
    var result = try allocator.alloc(u8, header.len + buffer.len);
    std.mem.copyForwards(u8, result[0..header.len], header);
    std.mem.copyForwards(u8, result[header.len..], buffer);
    allocator.free(header);
    return result;
} 