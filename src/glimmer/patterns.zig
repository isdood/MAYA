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
        base_color: colors.GlimmerColor,
        intensity: f32,
        frequency: f32,
        phase: f32,
    };

    /// Pattern state
    pub const PatternState = struct {
        current_color: colors.GlimmerColor,
        amplitude: f32,
        last_update: f32,
        energy: f32,
        resonance: f32,
    };

    pub const ValidationError = error{
        InvalidIntensity,
        InvalidFrequency,
        InvalidPhase,
        QuantumCoherenceViolation,
        NeuralResonanceMismatch,
    };

    pattern_type: PatternType,
    base_color: colors.GlimmerColor,
    intensity: f32,
    frequency: f32,
    phase: f32,
    state: PatternState,

    pub fn init(config: Config) Self {
        return Self{
            .pattern_type = config.pattern_type,
            .base_color = config.base_color,
            .intensity = config.intensity,
            .frequency = config.frequency,
            .phase = config.phase,
            .state = .{
                .current_color = config.base_color,
                .amplitude = 0.0,
                .last_update = 0.0,
                .energy = 1.0,
                .resonance = 0.0,
            },
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Update pattern based on neural activity
    pub fn update(self: *Self, neural_activity: f32, delta_time: f32) !void {
        // Validate pattern before update
        try self.validate();

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
                const quantum_color = colors.GlimmerColors.quantum.blend(
                    colors.GlimmerColors.primary,
                    self.state.energy,
                );
                self.state.current_color = self.base_color.blend(
                    quantum_color,
                    self.state.amplitude,
                );
            },
            .neural_flow => {
                const neural_color = colors.GlimmerColors.neural.blend(
                    colors.GlimmerColors.secondary,
                    self.state.energy,
                );
                self.state.current_color = self.base_color.blend(
                    neural_color,
                    self.state.amplitude,
                );
            },
            .cosmic_sparkle => {
                const cosmic_color = colors.GlimmerColors.cosmic.blend(
                    colors.GlimmerColors.accent,
                    self.state.energy,
                );
                self.state.current_color = self.base_color.blend(
                    cosmic_color,
                    self.state.amplitude,
                );
            },
            .stellar_pulse => {
                const stellar_color = colors.GlimmerColors.stellar.blend(
                    colors.GlimmerColors.quantum,
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
};

var initialized = false;
var patterns: ?[]GlimmerPattern = null;

pub fn init() !void {
    if (initialized) return;
    
    // Create default patterns
    const default_patterns = [_]GlimmerPattern.Config{
        .{
            .pattern_type = .quantum_wave,
            .base_color = colors.GlimmerColors.primary,
            .intensity = 0.5,
            .frequency = 1.0,
            .phase = 0.0,
        },
        .{
            .pattern_type = .neural_flow,
            .base_color = colors.GlimmerColors.secondary,
            .intensity = 0.7,
            .frequency = 1.5,
            .phase = 0.5,
        },
        .{
            .pattern_type = .cosmic_sparkle,
            .base_color = colors.GlimmerColors.accent,
            .intensity = 0.6,
            .frequency = 2.0,
            .phase = 1.0,
        },
        .{
            .pattern_type = .stellar_pulse,
            .base_color = colors.GlimmerColors.neural,
            .intensity = 0.8,
            .frequency = 1.2,
            .phase = 1.5,
        },
    };

    patterns = try std.heap.page_allocator.alloc(GlimmerPattern, default_patterns.len);
    for (default_patterns, 0..) |config, i| {
        patterns.?[i] = GlimmerPattern.init(config);
    }

    initialized = true;
}

pub fn deinit() void {
    if (!initialized) return;
    if (patterns) |p| {
        std.heap.page_allocator.free(p);
    }
    patterns = null;
    initialized = false;
}

pub fn processPatterns() !void {
    if (!initialized) return error.NotInitialized;
    if (patterns) |p| {
        for (p) |*pattern| {
            try pattern.update(0.5, 0.016); // Simulate 60 FPS
        }
    }
}

test "GlimmerPattern" {
    const config = GlimmerPattern.Config{
        .pattern_type = .quantum_wave,
        .base_color = colors.GlimmerColor{ .r = 0xFF, .g = 0xFF, .b = 0xFF },
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    };

    var pattern = GlimmerPattern.init(config);
    try pattern.update(0.5, 0.1);
    try std.testing.expect(pattern.state.energy >= 0.0 and pattern.state.energy <= 1.0);
    try std.testing.expect(pattern.state.resonance >= -1.0 and pattern.state.resonance <= 1.0);
}

test "PatternValidation" {
    // Test valid pattern
    const valid_config = GlimmerPattern.Config{
        .pattern_type = .quantum_wave,
        .base_color = colors.GlimmerColors.primary,
        .intensity = 0.5,
        .frequency = 1.0,
        .phase = 0.0,
    };
    var valid_pattern = GlimmerPattern.init(valid_config);
    try valid_pattern.validate();

    // Test invalid intensity
    const invalid_intensity_config = GlimmerPattern.Config{
        .pattern_type = .quantum_wave,
        .base_color = colors.GlimmerColors.primary,
        .intensity = 1.5, // Invalid intensity
        .frequency = 1.0,
        .phase = 0.0,
    };
    var invalid_pattern = GlimmerPattern.init(invalid_intensity_config);
    try std.testing.expectError(error.InvalidIntensity, invalid_pattern.validate());
} 