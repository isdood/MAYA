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
//! - Cache-blocked quantum state updates
//! - Improved memory layout for better cache locality
//! - Hardware prefetching for predictable access patterns
//! - Circuit optimization passes
//! - Batch processing of quantum gates
//! - Parallel execution of independent operations

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ThreadPool = std.Thread.Pool;
const Thread = std.Thread;
const Atomic = std.atomic.Value;
const math = std.math;
const testing = std.testing;
const Complex = std.math.Complex;
const simd = @import("simd.zig");
const quantum_types = @import("quantum_types.zig");
const crystal_computing = @import("crystal_computing.zig");
const Cpu = std.Target.Cpu;
const Target = std.Target;

/// CPU vendor identifiers
const CpuVendor = enum {
    intel,
    amd,
    arm,
    apple,
    unknown,
};

/// CPU microarchitecture families
const CpuArch = enum {
    // Intel
    nehalem,
    sandybridge,
    ivybridge,
    haswell,
    broadwell,
    skylake,
    cascade_lake,
    ice_lake,
    tiger_lake,
    alder_lake,
    raptor_lake,
    
    // AMD
    bulldozer,
    zen,
    zen2,
    zen3,
    zen4,
    
    // ARM
    cortex_a53,
    cortex_a72,
    cortex_a76,
    neoverse_n1,
    neoverse_v1,
    
    // Apple
    icestorm,
    firestorm,
    avalanche,
    blizzard,
    
    unknown,
};

/// Memory hierarchy configuration
const MemoryHierarchy = struct {
    has_smt: bool = false,                     // Simultaneous Multi-Threading
    num_ccx: usize = 1,                        // CPU Complex count (AMD)
    numa_nodes: usize = 1,                     // NUMA nodes
    memory_channels: usize = 2,                // Memory channels
    memory_bandwidth_gb: f64 = 25.6,           // GB/s
    l1d_assoc: u8 = 8,                         // L1D associativity
    l2_assoc: u8 = 8,                          // L2 associativity
    l3_assoc: u8 = 16,                         // L3 associativity
    l1d_prefetcher: bool = true,               // Hardware prefetcher
    l2_prefetcher: bool = true,                // L2 hardware prefetcher
};

/// CPU-specific optimization parameters
const CpuOptimizations = struct {
    vector_width: usize = 1,
    prefetch_distance: usize = 1,
    unroll_factor: usize = 1,
    use_simd: bool = false,
};

/// Detect CPU vendor from CPU features
fn detectCpuVendor(cpu: std.Target.Cpu) CpuVendor {
    if (cpu.arch == .x86_64 or cpu.arch == .x86) {
        if (std.Target.x86.featureSetHasAll(cpu.features, .{ .intel })) {
            return .intel;
        } else if (std.Target.x86.featureSetHasAll(cpu.features, .{ .amd })) {
            return .amd;
        }
    } else if (cpu.arch.isARM() or cpu.arch == .aarch64) {
        if (std.Target.arm.featureSetHasAll(cpu.features, .{ .apple })) {
            return .apple;
        }
        return .arm;
    }
    return .unknown;
}

/// Detect CPU architecture
fn detectCpuArch(cpu: std.Target.Cpu) CpuArch {
    if (cpu.arch == .x86_64) {
        // Intel CPUs
        if (std.Target.x86.featureSetHasAll(cpu.features, .{ .intel })) {
            if (std.Target.x86.featureSetHasAll(cpu.features, .{ .avx512f })) {
                if (std.Target.x86.featureSetHasAll(cpu.features, .{ .avx512vnni })) {
                    return .ice_lake;
                }
                return .skylake;
            } else if (std.Target.x86.featureSetHasAll(cpu.features, .{ .avx2 })) {
                return .haswell;
            }
            return .sandybridge;
        } 
        // AMD CPUs
        else if (std.Target.x86.featureSetHasAll(cpu.features, .{ .amd })) {
            if (std.Target.x86.featureSetHasAll(cpu.features, .{ .avx2 })) {
                if (std.Target.x86.featureSetHasAll(cpu.features, .{ .avx512f })) {
                    return .zen4;
                }
                return .zen3;
            }
            return .zen;
        }
    } else if (cpu.arch == .aarch64 or cpu.arch.isARM()) {
        // Apple Silicon
        if (std.Target.arm.featureSetHasAll(cpu.features, .{ .apple })) {
            return .firestorm;  // Default to firestorm for Apple Silicon
        }
        // ARM Cortex
        if (std.Target.arm.featureSetHasAll(cpu.features, .{ .v8_1a })) {
            return .cortex_a76;
        }
        return .cortex_a53;
    }
    
    return .unknown;
}

/// CPU-specific optimization parameters
const ArchOptimizations = struct {
    const Self = @This();
    
    vendor: CpuVendor = .unknown,
    arch: CpuArch = .unknown,
    
    // Prefetch settings
    prefetch_distance: usize = 2,
    prefetch_level: u2 = 3,
    prefetch_aggressiveness: f64 = 0.7,
    
    // Blocking and tiling
    block_size_aggression: f64 = 0.5,  // 0.0 = conservative, 1.0 = aggressive
    min_block_size_ratio: f64 = 0.1,   // Min block size as fraction of cache size
    max_block_size_ratio: f64 = 0.8,   // Max block size as fraction of cache size
    
    // Memory access patterns
    spatial_locality: bool = true,     // Optimize for spatial locality
    temporal_locality: bool = true,    // Optimize for temporal locality
    
    // Vectorization
    prefer_avx512: bool = false,
    prefer_avx2: bool = false,
    prefer_neon: bool = false,
    
    /// Create optimizations based on CPU detection
    pub fn detect() Self {
        const target = Target.current;
        const cpu = target.cpu;
        
        var optim = Self{
            .vendor = detectCpuVendor(cpu),
            .arch = detectCpuArch(cpu),
        };
        
        // Apply architecture-specific optimizations
        optim.applyArchitectureTuning();
        return optim;
    }
    
    /// Apply architecture-specific tuning
    fn applyArchitectureTuning(self: *Self) void {
        switch (self.vendor) {
            .intel => self.tuneIntel(),
            .amd => self.tuneAmd(),
            .arm, .apple => self.tuneArm(),
            else => {},
        }
    }
    
    /// Tune for Intel CPUs
    fn tuneIntel(self: *Self) void {
        self.prefetch_aggressiveness = 0.8;
        self.spatial_locality = true;
        self.temporal_locality = true;
        
        switch (self.arch) {
            .skylake, .cascade_lake => {
                self.prefetch_distance = 3;
                self.prefer_avx512 = true;
                self.block_size_aggression = 0.75;
            },
            .ice_lake, .tiger_lake => {
                self.prefetch_distance = 4;
                self.prefer_avx512 = true;
                self.block_size_aggression = 0.8;
            },
            .alder_lake, .raptor_lake => {
                self.prefetch_distance = 3;
                self.prefer_avx512 = false; // Hybrid architecture
                self.prefer_avx2 = true;
                self.block_size_aggression = 0.7;
            },
            else => {},
        }
    }
    
    /// Tune for AMD CPUs
    fn tuneAmd(self: *Self) void {
        self.prefetch_aggressiveness = 0.9;
        self.spatial_locality = true;
        self.temporal_locality = false; // Zen benefits less from temporal locality
        
        switch (self.arch) {
            .zen, .zen2 => {
                self.prefetch_distance = 2;
                self.block_size_aggression = 0.6;
                self.min_block_size_ratio = 0.1;
            },
            .zen3, .zen4 => {
                self.prefetch_distance = 3;
                self.block_size_aggression = 0.8;
                self.prefetch_level = 2;
            },
            else => {},
        }
    }
    
    /// Tune for ARM/Apple CPUs
    fn tuneArm(self: *Self) void {
        self.prefetch_aggressiveness = 0.6; // ARM has aggressive hardware prefetching
        self.spatial_locality = true;
        self.temporal_locality = false;
        self.prefer_neon = true;
        
        switch (self.arch) {
            .firestorm, .avalanche => {
                // Apple M1/M2
                self.prefetch_distance = 1; // Very good hardware prefetcher
                self.block_size_aggression = 0.8;
                self.min_block_size_ratio = 0.2;
            },
            .cortex_a76, .neoverse_n1, .neoverse_v1 => {
                self.prefetch_distance = 2;
                self.block_size_aggression = 0.7;
            },
            else => {},
        }
    }
};

/// Quantum Processor for advanced pattern recognition and quantum state manipulation
pub const QuantumProcessor = struct {
    allocator: Allocator,
    config: QuantumConfig,
    rng: std.rand.Xoshiro256,
    thread_pool: ?*ThreadPool = null,
    crystal: ?*crystal_computing.CrystalProcessor = null,
    state: quantum_types.QuantumState = .{},
    state_size: usize = 0,
    memory_hierarchy: MemoryHierarchy = .{},
    arch_optimizations: ArchOptimizations = .{},
    vendor: CpuVendor = .unknown,
    arch: CpuArch = .unknown,

    const Self = @This();

    /// Initialize a new quantum processor with the given configuration
    pub fn init(allocator: Allocator, config: QuantumConfig) !*QuantumProcessor {
        var self = try allocator.create(QuantumProcessor);
        errdefer allocator.destroy(self);
        
        self.allocator = allocator;
        self.config = config;
        self.rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        
        // Initialize thread pool
        const default_threads = std.Thread.getCpuCount() catch 1;
        self.thread_pool = try ThreadPool.init(.{
            .allocator = allocator,
            .n_jobs = default_threads,
        });
        
        // Initialize crystal computing if enabled
        if (config.use_crystal_computing) {
            self.crystal = try crystal_computing.CrystalProcessor.init(allocator);
        }
        
        // Detect CPU architecture and apply optimizations
        self.vendor = detectCpuVendor();
        self.arch = detectCpuArch();
        self.arch_optimizations = ArchOptimizations{
            .vendor = self.vendor,
            .arch = self.arch,
        };
        self.arch_optimizations.applyArchitectureTuning();
        
        // Initialize memory hierarchy
        self.memory_hierarchy = MemoryHierarchy{};
        self.config.detectCacheHierarchy();
        
        // Initialize quantum state
        self.state = quantum_types.QuantumState{
            .coherence = 1.0,
            .entanglement = 0.0,
            .superposition = 0.0,
            .qubits = &[0]quantum_types.Qubit{},
        };
        
        return self;
    }
    
    /// Clean up resources used by the quantum processor
    pub fn deinit(self: *QuantumProcessor) void {
        if (self.thread_pool) |pool| {
            pool.deinit();
            self.allocator.destroy(pool);
        }
        
        if (self.crystal) |crystal| {
            crystal.deinit();
            self.allocator.destroy(crystal);
        }
        
        if (self.state.qubits.len > 0) {
            self.allocator.free(self.state.qubits);
        }
        
        self.allocator.destroy(self);
    }
    
    /// Process a batch of patterns in parallel
    pub fn processBatch(self: *QuantumProcessor, patterns: []const []const u8) ![]quantum_types.PatternMatch {
        const results = try self.allocator.alloc(quantum_types.PatternMatch, patterns.len);
        errdefer self.allocator.free(results);
        
        // Process patterns in parallel using the thread pool
        if (self.thread_pool) |pool| {
            // Parallel processing
            var context = struct {
                processor: *QuantumProcessor,
                patterns: []const []const u8,
                results: []quantum_types.PatternMatch,
                
                fn process(
                    ctx: *@This(),
                    i: usize,
                    _: *ThreadPool.Node,
                ) void {
                    ctx.results[i] = ctx.processor.processPattern(ctx.patterns[i]) catch |err| {
                        // Handle error - store an error result
                        ctx.results[i] = .{
                            .similarity = 0.0,
                            .confidence = 0.0,
                            .pattern_id = "error",
                            .qubits_used = 0,
                            .depth = 0,
                        };
                    };
                }
            }{
                .processor = self,
                .patterns = patterns,
                .results = results,
            };
            
            // Dispatch tasks to thread pool
            var nodes = try self.allocator.alloc(ThreadPool.Node, patterns.len);
            defer self.allocator.free(nodes);
            
            for (patterns, 0..) |_, i| {
                nodes[i] = ThreadPool.Node{
                    .data = &context,
                    .next = undefined,
                };
                pool.spawn(&nodes[i], context.process);
            }
            
            // Wait for all tasks to complete
            pool.waitAndWork();
        } else {
            // Fallback to sequential processing
            for (patterns, 0..) |pattern, i| {
                results[i] = try self.processPattern(pattern);
            }
        }
        
        return results;
    }
    
    /// Get the current quantum state
    pub fn getState(self: *const QuantumProcessor) quantum_types.QuantumState {
        return self.state;
    }
    
    /// Set the quantum state
    pub fn setState(self: *QuantumProcessor, new_state: quantum_types.QuantumState) !void {
        // Validate the new state
        if (new_state.coherence < 0.0 or new_state.coherence > 1.0 or
            new_state.entanglement < 0.0 or new_state.entanglement > 1.0 or
            new_state.superposition < 0.0 or new_state.superposition > 1.0) {
            return error.InvalidQuantumState;
        }
        
        // Free old qubits if they exist
        if (self.state.qubits.len > 0) {
            self.allocator.free(self.state.qubits);
        }
        
        // Allocate new qubits and copy the state
        const new_qubits = try self.allocator.alloc(quantum_types.Qubit, new_state.qubits.len);
        @memcpy(new_qubits, new_state.qubits);
        
        // Update the state
        self.state = .{
            .coherence = new_state.coherence,
            .entanglement = new_state.entanglement,
            .superposition = new_state.superposition,
            .qubits = new_qubits,
        };
        
        // Update state size
        self.state_size = @as(usize, 1) << @as(u6, @intCast(new_qubits.len));
    }
    
    /// Reset the quantum processor to its initial state
    pub fn reset(self: *QuantumProcessor) void {
        // Reset the quantum state to |0...0>
        if (self.state.qubits.len > 0) {
            // Reset all qubits to |0>
            for (self.state.qubits) |*qubit| {
                qubit.* = .{ .amplitude0 = 1.0, .amplitude1 = 0.0 };
            }
        }
        
        // Reset state properties
        self.state.coherence = 1.0;
        self.state.entanglement = 0.0;
        self.state.superposition = 0.0;
    }
    
    /// Internal method to detect CPU vendor
    fn detectCpuVendor() CpuVendor {
        if (@hasDecl(std.Target.x86, "featureSet")) {
            if (comptime std.Target.x86.featureSetHas(builtin.cpu.features, .intel)) {
                return .intel;
            } else if (comptime std.Target.x86.featureSetHas(builtin.cpu.features, .amd)) {
                return .amd;
            }
        } else if (@hasDecl(std.Target.arm, "featureSet")) {
            if (comptime std.Target.arm.featureSetHas(builtin.cpu.features, .aarch64)) {
                if (builtin.target.os.tag == .macos) {
                    return .apple;
                }
                return .arm;
            }
        }
        return .unknown;
    }
    
    /// Internal method to detect CPU architecture
    fn detectCpuArch() CpuArch {
        const cpu = builtin.cpu;
        
        // Check for Intel architectures
        if (cpu.model == .skylake) return .skylake;
        if (cpu.model == .icelake) return .ice_lake;
        if (cpu.model == .tigerlake) return .tiger_lake;
        if (cpu.model == .alderlake) return .alder_lake;
        
        // Check for AMD architectures
        if (cpu.model == .zen) return .zen;
        if (cpu.model == .zen2) return .zen2;
        if (cpu.model == .zen3) return .zen3;
        if (cpu.model == .zen4) return .zen4;
        
        // Check for Apple Silicon
        if (cpu.model == .apple_m1) return .firestorm;
        if (cpu.model == .apple_m2) return .avalanche;
        
        return .unknown;
    }
    
    /// Internal method to measure a pattern and return the match result
    fn measurePattern(self: *const QuantumProcessor, state: *quantum_types.QuantumState, pattern: []const u8) !quantum_types.PatternMatch {
        _ = self; // Use self to avoid unused parameter warning
        _ = pattern; // Use pattern to avoid unused parameter warning
        
        // In a real implementation, this would perform quantum measurement
        // and return the result. For now, return a simple pattern match.
        return quantum_types.PatternMatch{
            .similarity = 0.9,
            .confidence = 0.95,
            .pattern_id = try std.fmt.allocPrint(self.allocator, "pattern_{d}", .{std.time.milliTimestamp()}),
            .qubits_used = @intCast(state.qubits.len),
            .depth = state.qubits.len,
        };
    }
};

// CPU detection helper functions
fn detectCpuVendor(cpu: std.Target.Cpu) CpuVendor {
    // Check for Intel
    if (std.mem.startsWith(u8, cpu.model.llvm_name, "intel") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "core") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "nehalem") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "sandy") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "ivy") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "haswell") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "broadwell") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "skylake") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "cannonlake") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "icelake") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "tigerlake") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "alderlake") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "raptor")) 
    {
        return .intel;
    }
    
    // Check for AMD
    if (std.mem.startsWith(u8, cpu.model.llvm_name, "amd") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "barcelona") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "zen")) 
    {
        return .amd;
    }
    
    // Check for Apple Silicon
    if (std.mem.startsWith(u8, cpu.model.llvm_name, "apple")) {
        return .apple;
    }
    
    // Check for ARM
    if (std.mem.startsWith(u8, cpu.model.llvm_name, "cortex") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "neoverse") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "a7") or
        std.mem.startsWith(u8, cpu.model.llvm_name, "a5")) 
    {
        return .arm;
    }
    
    // Default to unknown
    return .unknown;
}

/// Detect CPU architecture from CPU features
fn detectCpuArch(cpu: std.Target.Cpu) CpuArch {
    return switch (cpu.arch) {
        .x86_64, .x86 => .x86_64,
        .aarch64, .aarch64_be, .aarch64_32 => .aarch64,
        .arm, .armeb, .thumb, .thumbeb => .arm,
        .riscv64 => .riscv64,
        .wasm32 => .wasm32,
        .wasm64 => .wasm64,
        .mips, .mipsel, .mips64, .mips64el => .mips,
        .powerpc => .powerpc,
        .powerpc64, .powerpc64le => .powerpc64,
        .sparc, .sparcel => .sparc,
        .sparc64 => .sparc64,
        .s390x => .s390x,
        else => .generic,  // Default to generic architecture
    };
}

    /// Tune for Intel CPUs
    fn tuneIntel(self: *Self) void {
        self.prefetch_aggressiveness = 0.8;
        self.spatial_locality = true;
        self.temporal_locality = true;
        
        switch (self.arch) {
            .skylake, .cascade_lake => {
                self.prefetch_distance = 3;
                self.prefer_avx512 = true;
                self.block_size_aggression = 0.75;
            },
            .ice_lake, .tiger_lake => {
                self.prefetch_distance = 4;
                self.prefer_avx512 = true;
                self.block_size_aggression = 0.8;
            },
            .alder_lake, .raptor_lake => {
                self.prefetch_distance = 3;
                self.prefer_avx512 = false; // Hybrid architecture
                self.prefer_avx2 = true;
                self.block_size_aggression = 0.7;
            },
            else => {},
        }
    }
    

};

/// Quantum processor configuration
pub const QuantumConfig = struct {
    // Processing parameters
    min_coherence: f64 = 0.95,           // Minimum quantum coherence threshold
    max_entanglement: f64 = 1.0,         // Maximum entanglement level
    superposition_depth: usize = 8,       // Maximum superposition depth
    min_pattern_similarity: f64 = 0.8,   // Minimum similarity threshold for pattern matching
    max_parallel_qubits: usize = 16,      // Maximum qubits for parallel processing
    use_crystal_computing: bool = false,  // Enable crystal computing enhancements
    use_parallel_execution: bool = true,  // Enable parallel execution
    batch_size: usize = 16,               // Default batch size for batch processing
    
    // Cache configuration
    min_block_size: usize = 64,           // Minimum block size in bytes
    max_block_size: usize = 4096,         // Maximum block size in bytes
    cache_sizes: [3]usize = .{32 * 1024, 256 * 1024, 8 * 1024 * 1024}, // L1, L2, L3 in bytes
    cache_line_sizes: [3]usize = .{64, 64, 64}, // Cache line sizes in bytes
    
    // Architecture optimizations
    arch_optimizations: ArchOptimizations = .{},
    
    // Memory hierarchy
    memory_hierarchy: MemoryHierarchy = .{},
    
    // Prefetch settings
    prefetch_distance: usize = 2,         // Default prefetch distance
    prefetch_level: u2 = 1,               // Default prefetch level (0=L1, 1=L2, 2=L3, 3=RAM)
    
    // Blocking and tiling
    block_size_aggression: f64 = 0.5,     // Aggressiveness of block size selection
    min_block_size_ratio: f64 = 0.1,      // Minimum block size as fraction of cache size
    max_block_size_ratio: f64 = 0.8,      // Maximum block size as fraction of cache size
    
    // Memory access patterns
    spatial_locality: bool = true,        // Optimize for spatial locality
    temporal_locality: bool = true,       // Optimize for temporal locality

    /// Detect cache hierarchy and adjust configuration
    pub fn detectCacheHierarchy(self: *QuantumConfig) void {
        if (@import("builtin").target.cpu.arch != .x86_64 and 
            @import("builtin").target.cpu.arch != .aarch64) {
            // Use default values for unsupported architectures
            return;
        }

        // Try to detect cache sizes using system-specific methods
        if (@import("builtin").os.tag == .linux) {
            // Read cache information from sysfs on Linux
            _ = self.detectLinuxCacheHierarchy() catch |err| {
                // Fall back to defaults if detection fails
                std.debug.print("Warning: Failed to detect Linux cache hierarchy: {s}\n", .{@errorName(err)});
            };
        }
        
        // Sanity check and adjust block sizes
        self.min_block_size = @max(64, self.min_block_size); // At least one cache line
        self.max_block_size = @max(self.min_block_size * 4, self.max_block_size);
    }
    
    /// Detect cache hierarchy on Linux using sysfs
    fn detectLinuxCacheHierarchy(self: *QuantumConfig) !void {
        const allocator = std.heap.page_allocator;
        
        // Look for cache information in /sys/devices/system/cpu/cpu0/cache/
        var cache_dir = try std.fs.cwd().openDir("/sys/devices/system/cpu/cpu0/cache", .{});
        defer cache_dir.close();
        
        var it = try cache_dir.iterate();
        var level: usize = 0;
        
        while (try it.next()) |entry| : (level += 1) {
            if (level >= self.cache_sizes.len) break;
            
            // Read cache size
            if (cache_dir.openFile(entry.name ++ "/size", .{})) |file| {
                defer file.close();
                
                var buf: [32]u8 = undefined;
                const bytes_read = try file.readAll(&buf);
                const line = std.mem.trim(u8, buf[0..bytes_read], " \n");
                
                if (std.mem.indexOfScalar(u8, line, 'K')) |k_pos| {
                    const size_str = line[0..k_pos];
                    if (std.fmt.parseInt(usize, size_str, 10)) |size_kb| {
                        self.cache_sizes[level] = size_kb * 1024;
                    } else |_| {}
                }
            } else |_| {}
            
            // Read cache line size
            if (cache_dir.openFile(entry.name ++ "/coherency_line_size", .{})) |file| {
                defer file.close();
                
                var buf: [32]u8 = undefined;
                const bytes_read = try file.readAll(&buf);
                const line = std.mem.trim(u8, buf[0..bytes_read], " \n");
                
                if (std.fmt.parseInt(usize, line, 10)) |line_size| {
                    self.cache_line_sizes[level] = line_size;
                } else |_| {}
            } else |_| {}
        }
    }
    
    /// Calculate optimal block size based on problem size and cache hierarchy
    pub fn calculateBlockSize(self: *const QuantumConfig, data_size: usize, element_size: usize) usize {
        if (data_size == 0) return 1024; // Default block size for empty data
        
        const total_data_size = data_size * element_size;
        var best_block_size = self.min_block_size;
        var best_score: f64 = 0.0;
        
        // Calculate block size for each cache level
        for (self.cache_sizes, 0..) |cache_size, level| {
            if (cache_size == 0) continue;
            
            // Calculate effective cache size considering associativity and other processes
            const effective_cache_size = @as(f64, @floatFromInt(cache_size)) * 
                (1.0 - 0.2 * @as(f64, @floatFromInt(level))); // Penalize higher cache levels
            
            // Calculate block size range for this cache level
            const min_block = @as(usize, @intFromFloat(effective_cache_size * self.min_block_size_ratio));
            const max_block = @min(
                @as(usize, @intFromFloat(effective_cache_size * self.max_block_size_ratio)),
                self.max_block_size
            );
            
            // Skip if no valid block size range
            if (min_block >= max_block) continue;
            
            // Calculate block size based on data size relative to cache size
            const data_ratio = @as(f64, @floatFromInt(total_data_size)) / effective_cache_size;
            var block_size: usize = undefined;
            
            if (data_ratio < 0.25) {
                // Small data: use larger blocks
                block_size = @as(usize, @intFromFloat(
                    @as(f64, @floatFromInt(max_block)) * 
                    (0.7 + 0.3 * self.block_size_aggression)
                ));
            } else if (data_ratio < 1.0) {
                // Medium data: balance block size
                const t = (data_ratio - 0.25) / 0.75;
                const scale = 0.7 - 0.4 * t * self.block_size_aggression;
                block_size = @as(usize, @intFromFloat(
                    @as(f64, @floatFromInt(max_block)) * scale
                ));
            } else {
                // Large data: use smaller blocks
                block_size = @as(usize, @intFromFloat(
                    @as(f64, @floatFromInt(max_block)) * 
                    (0.3 * (1.0 - self.block_size_aggression * 0.5))
                ));
            }
            
            // Apply cache line alignment
            const cache_line_size = self.cache_line_sizes[level];
            const aligned_block = std.math.max(
                self.min_block_size,
                std.math.min(
                    max_block,
                    (block_size / cache_line_size) * cache_line_size
                )
            );
            
            // Calculate score for this block size
            const locality_score = if (self.spatial_locality) 1.2 else 1.0;
            const temporal_score = if (self.temporal_locality) 1.1 else 1.0;
            const score = @as(f64, @floatFromInt(aligned_block)) * locality_score * temporal_score;
            
            if (score > best_score) {
                best_score = score;
                best_block_size = aligned_block;
            }
        }
        
        // Ensure minimum size and alignment
        best_block_size = std.math.max(best_block_size, self.min_block_size);
        best_block_size = std.math.min(best_block_size, self.max_block_size);
        
        // Round to nearest power of two for better cache alignment
        return std.math.ceilPowerOfTwo(usize, best_block_size) catch best_block_size;
    }
    
    /// Calculate optimal thread count based on problem size and CPU capabilities
    pub fn calculateOptimalThreads(self: *const QuantumConfig, problem_size: usize) usize {
        const cpu_count = std.Thread.getCpuCount() catch 1;
        const threads_per_core = if (self.memory_hierarchy.has_smt) 2 else 1;
        const physical_cores = cpu_count / threads_per_core;
        
        // For very small problems, use fewer threads to avoid overhead
        if (problem_size <= 4) { // 1-4 qubits (2-16 states)
            return @min(1, physical_cores);
        } 
        // For small problems, use up to half the cores
        else if (problem_size <= 8) { // 5-8 qubits (32-256 states)
            return @max(1, @min(2, physical_cores / 2));
        }
        // For medium problems, use all physical cores
        else if (problem_size <= 12) { // 9-12 qubits (512-4096 states)
            return physical_cores;
        }
        // For large problems, use all available threads
        else {
            return cpu_count;
        }
    }
    
    /// Get the optimal prefetch distance based on memory latency and access pattern
    pub fn calculatePrefetchDistance(self: *const QuantumConfig, block_size: usize, element_size: usize) usize {
        // Get architecture-specific base prefetch distance
        var prefetch_dist: usize = 8; // Default value
        
        // Adjust based on CPU architecture
        switch (self.arch_optimizations.arch) {
            .skylake, .zen3, .zen4 => {
                // Modern CPUs with good prefetchers
                prefetch_dist = 12;
            },
            .firestorm, .avalanche => {
                // Apple Silicon has aggressive prefetchers
                prefetch_dist = 8;
            },
            else => {
                // Conservative default for unknown architectures
                prefetch_dist = 6;
            },
        }
        
        // Adjust based on block size and element size
        const elements_per_cache_line = 64 / @max(1, element_size);
        const cache_lines_per_block = (block_size + elements_per_cache_line - 1) / elements_per_cache_line;
        
        // Scale prefetch distance based on block size and cache hierarchy
        prefetch_dist = @min(prefetch_dist, cache_lines_per_block * 2);
        
        // Ensure minimum prefetch distance
        return @max(1, @min(32, prefetch_dist));
    }

    /// Get the prefetch level (0=L1, 1=L2, 2=L3, 3=RAM)
    pub fn getPrefetchLevel(self: *const QuantumConfig) u2 {
        // For very small qubit counts (1-2 qubits), no prefetching
        if (self.state_size <= 4) { // 1-2 qubits (2-4 states)
            return 0; // No prefetching for very small states
        }
        
        // For small qubit counts (3-4 qubits), use L1 prefetching
        if (self.state_size <= 16) { // 3-4 qubits (8-16 states)
            return 0; // L1 prefetch
        }
        
        // For medium sizes (5-8 qubits), use L2
        if (self.state_size <= 256) { // 5-8 qubits (32-256 states)
            return 1; // L2 prefetch
        }
        
        // For larger sizes (9+ qubits), use L3 or RAM based on cache sizes
        const l3_size = self.memory_hierarchy.l3_cache_size;
        const total_data_size = self.state_size * @sizeOf(f64);
        
        if (total_data_size <= l3_size / 4) {
            return 2; // L3 prefetch
        }
        
        return 3; // RAM prefetch (minimal benefit)
    }
    
    /// Normalize the quantum state to ensure the sum of probabilities is 1
    fn normalizeState(state: *quantum_types.QuantumState) !void {
        var norm: f64 = 0.0;
        const num_qubits = state.qubits.len;
        const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
        
        // Calculate norm
        for (0..num_states) |i| {
            const amp = state.amplitudes[i];
            norm += amp.re * amp.re + amp.im * amp.im;
        }
        
        // Normalize if norm is greater than 0
        if (norm > 0.0) {
            const inv_norm = 1.0 / @sqrt(norm);
            for (0..num_states) |i| {
                state.amplitudes[i].re *= inv_norm;
                state.amplitudes[i].im *= inv_norm;
            }
        }
    }
};


/// Initialize a new quantum processor with the given configuration
pub fn init(allocator: Allocator, config: QuantumConfig) !*QuantumProcessor {
    var self = try allocator.create(QuantumProcessor);
    errdefer allocator.destroy(self);
    
    self.allocator = allocator;
    self.config = config;
    self.rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    
    // Initialize with default thread count, will be adjusted per-operation
    // based on problem size
    const default_threads = std.Thread.getCpuCount() catch 1;
    self.thread_pool = try ThreadPool.init(.{
        .allocator = allocator,
        .n_jobs = default_threads,
    });
    
    // Set thread pool size based on default problem size (8 qubits)
    self.adjustThreadPool(8);
    
    // Initialize crystal computing if enabled
    if (config.use_crystal_computing) {
        self.crystal = try crystal_computing.CrystalProcessor.init(allocator);
    } else {
        self.crystal = null;
    }
    
    return self;
    
    /// Adjust thread pool size based on problem size (qubit count)
    fn adjustThreadPool(self: *QuantumProcessor, num_qubits: usize) void {
        if (self.thread_pool) |pool| {
            const optimal_threads = self.config.calculateOptimalThreads(num_qubits);
            if (pool.workers.len != optimal_threads) {
                // In a real implementation, we would resize the thread pool here
                // For now, we just log the recommended thread count
                std.log.debug("Optimal thread count for {} qubits: {}", .{num_qubits, optimal_threads});
            }
        }
    }
    
    /// Specialized encoding for very small qubit counts (1-2 qubits)
    fn encodeSmallPattern(self: *QuantumProcessor, state: *quantum_types.QuantumState, pattern: []const u8) !void {
        const num_qubits = state.qubits.len;
        const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
        
        // For very small patterns, use a simple sequential approach
        for (0..num_states) |i| {
            const val = if (i < pattern.len) 
                @as(f64, @floatFromInt(pattern[i])) / 255.0 
            else 
                0.0;
            state.amplitudes[i] = .{ .re = val, .im = 0.0 };
        }
        
        // Use optimized normalization for small states
        try normalizeStateSmall(state);
    }
    
    /// Optimized normalization for small quantum states (≤4 qubits)
    fn normalizeStateSmall(state: *quantum_types.QuantumState) !void {
        var norm: f64 = 0.0;
        const num_states = @as(usize, 1) << @as(u6, @intCast(state.qubits.len));
        
        // Unrolled loop for small counts
        switch (num_states) {
            1...4 => {
                for (0..num_states) |i| {
                    const amp = state.amplitudes[i];
                    norm += amp.re * amp.re + amp.im * amp.im;
                }
            },
            else => {
                return error.InvalidStateSize;
            },
        }
        
        if (norm > 0.0) {
            const inv_norm = 1.0 / @sqrt(norm);
            for (0..num_states) |i| {
                state.amplitudes[i].re *= inv_norm;
                state.amplitudes[i].im *= inv_norm;
            }
        }
    }
    
    /// Simple encoding that uses the first qubit for pattern representation
    fn encodeSimplePattern(self: *QuantumProcessor, state: *quantum_types.QuantumState, pattern: []const u8) void {
        if (pattern.len > 0) {
            const norm = @as(f64, @floatFromInt(pattern[0])) / 255.0;
            state.qubits[0].amplitude0 = norm;
            state.qubits[0].amplitude1 = 1.0 - norm;
        }
    }
    
    /// Apply optimized quantum pattern matching with adaptive cache-blocking
    fn applyOptimizedPatternMatching(self: *QuantumProcessor, circuit: *quantum_types.QuantumCircuit, 
                                   pattern: []const u8) !void {
        const num_qubits = circuit.qubits.len;
        const complex_size = @sizeOf(quantum_types.Complex);
        
        // Calculate adaptive block size for qubit processing
        const qubits_per_block = self.config.calculateBlockSize(num_qubits, @sizeOf(quantum_types.Qubit));
        const num_blocks = (num_qubits + qubits_per_block - 1) / qubits_per_block;
        
        // Apply optimized gates with cache awareness
        if (self.config.use_simd) {
            // Process qubits in blocks that fit in cache
            var qubit: usize = 0;
            while (qubit < num_qubits) {
                const block_end = @min(qubit + qubits_per_block, num_qubits);
                
                // Prefetch next block of qubits
                if (block_end < num_qubits) {
                    const next_block_start = block_end;
                    const next_block_end = @min(next_block_start + qubits_per_block, num_qubits);
                    for (next_block_start..next_block_end) |i| {
                        @prefetch(&circuit.qubits[i], .{ .rw = .read, .locality = 3, .cache = .data });
                    }
                }
                
                // Process current block with SIMD
                for (qubit..block_end) |i| {
                    try circuit.h(i);
                }
                qubit = block_end;
            }
        } else {
            // Standard gate application with prefetching
            for (0..num_qubits) |i| {
                // Prefetch next few qubits
                if (i + 4 < num_qubits) {
                    @prefetch(&circuit.qubits[i + 4], .{ .rw = .read, .locality = 2, .cache = .data });
                }
                try circuit.h(i);
            }
        }
        
        // Apply pattern-dependent gates
        for (pattern, 0..) |_, i| {
            const target_qubit = i % num_qubits;
            try circuit.x(target_qubit);
            try circuit.h(target_qubit);
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
    fn measurePattern(self: *QuantumProcessor, state: *quantum_types.QuantumState, _: []const u8) !quantum_types.PatternMatch {
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
        self: *QuantumProcessor,
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
    
    /// Process a single pattern through the quantum processor
    pub fn processPattern(self: *QuantumProcessor, pattern: []const u8) !quantum_types.PatternMatch {
        if (pattern.len == 0) return error.InvalidPattern;

        // Calculate optimal number of qubits for the pattern length
        const num_qubits = @min(
            self.config.max_parallel_qubits,
            @as(usize, @intCast(@log2(@as(f64, @floatFromInt(pattern.len + 1)))))
        );
        
        // Adjust thread pool based on problem size
        self.adjustThreadPool(num_qubits);

        // Initialize quantum state
        var state = try quantum_types.QuantumState.init(self.allocator, num_qubits);
        defer state.deinit();

        // Use specialized encoding based on qubit count
        if (num_qubits <= 2) {
            try self.encodeSmallPattern(&state, pattern);
        } else if (num_qubits <= 4) {
            try self.encodeMediumPattern(&state, pattern);
        } else {
            try self.encodePattern(&state, pattern);
        }

        // Process quantum state
        try self.processQuantumState(&state, pattern);

        // Apply crystal computing enhancement if enabled
        if (self.config.use_crystal_computing) {
            if (self.crystal) |crystal| {
                const crystal_state = try crystal.computeState(pattern);
                try self.enhanceWithCrystalState(&state, crystal_state);
            }
        }

        // Measure and return results
        return self.measurePattern(&state, pattern);
    }
    
    /// Encode a pattern into the quantum state
    fn encodePattern(state: *quantum_types.QuantumState, pattern: []const u8) !void {
        const num_qubits = state.qubits.len;
        const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
        
        // Calculate normalization factor
        var norm: f64 = 0.0;
        for (0..num_states) |i| {
            const val = if (i < pattern.len) @as(f64, @floatFromInt(pattern[i])) / 255.0 else 0.0;
            state.amplitudes[i] = .{ .re = val, .im = 0.0 };
            norm += val * val;
        }
        
        // Normalize the state
        if (norm > 0.0) {
            const inv_norm = 1.0 / @sqrt(norm);
            for (0..num_states) |i| {
                state.amplitudes[i].re *= inv_norm;
            }
        }
    }
    
    /// Process quantum state with the pattern
    fn processQuantumState(self: *QuantumProcessor, state: *quantum_types.QuantumState, pattern: []const u8) !void {
        const num_qubits = state.qubits.len;
        
        // Apply Hadamard to all qubits to create superposition
        for (0..num_qubits) |i| {
            try state.applyGate(.H, i);
        }
        
        // Apply pattern-specific phase shifts
        for (0..pattern.len) |i| {
            const phase = @as(f64, @floatFromInt(pattern[i])) / 255.0 * math.pi * 2.0;
            try state.applyPhase(i % num_qubits, phase);
        }
        
        // Apply inverse QFT for pattern matching
        try applyInverseQFT(state);
    }
    
    /// Apply inverse Quantum Fourier Transform to the quantum state
    fn applyInverseQFT(state: *quantum_types.QuantumState) !void {
        const n = state.qubits.len;
        
        // Apply inverse QFT by applying QFT in reverse order with negative phases
        for (0..n) |i| {
            // Apply Hadamard to qubit i
            try state.applyGate(.H, i);
            
            // Apply controlled rotations with negative phase
            for (i + 1..n) |j| {
                const theta = -2.0 * math.pi / std.math.pow(f64, 2.0, @as(f64, @floatFromInt(j - i + 1)));
                try state.applyControlledPhaseShift(j, i, theta);
            }
        }
        
        // Swap qubits to complete the inverse QFT
        for (0..n / 2) |i| {
            if (i != n - 1 - i) {
                try state.applySwap(i, n - 1 - i);
            }
        }
    }
    
    /// Enhance quantum state with advanced crystal computing results
    fn enhanceWithCrystalState(
        self: *QuantumProcessor,
        state: *quantum_types.QuantumState,
        crystal_state: crystal_computing.CrystalState,
    ) !void {
        const num_qubits = state.qubits.len;
        const num_states = @as(usize, 1) << @as(u6, @intCast(num_qubits));
        
        // Calculate enhancement factors based on crystal properties
        const coherence_boost = 1.0 + (crystal_state.coherence * 0.5);  // Up to 50% boost
        const entanglement_boost = 1.0 + (crystal_state.entanglement * 0.3);  // Up to 30% boost
        const depth_boost = 1.0 + (@as(f64, @floatFromInt(crystal_state.depth)) / 10.0);  // 10% per depth level
        
        // Apply spectral enhancement if available
        var spectral_boost: f64 = 1.0;
        if (crystal_state.spectral) |spectral| {
            // Higher entropy means more uniform spectrum, less enhancement
            spectral_boost = 1.2 - (spectral.spectral_entropy * 0.2);
            spectral_boost = @max(0.8, @min(1.2, spectral_boost));  // Clamp to [0.8, 1.2]
        }
        
        // Calculate final enhancement factor
        const enhancement = (coherence_boost * entanglement_boost * depth_boost * spectral_boost) / 4.0;
        
        // Apply enhancement to quantum state
        for (0..num_states) |i| {
            const idx = i % crystal_state.amplitudes.len;  // Handle different sizes
            
            // Enhanced amplitude mixing with crystal state
            state.amplitudes[i].re = (state.amplitudes[i].re * 0.7) + 
                                   (crystal_state.amplitudes[idx].re * 0.3) * enhancement;
            state.amplitudes[i].im = (state.amplitudes[i].im * 0.7) + 
                                   (crystal_state.amplitudes[idx].im * 0.3) * enhancement;
        }
        
        // Update quantum state properties based on crystal state
        state.coherence = @min(1.0, state.coherence * coherence_boost);
        state.entanglement = @min(1.0, state.entanglement * entanglement_boost);
        state.depth = @max(state.depth, crystal_state.depth);
        
        // Apply resonance effects if available
        if (crystal_state.resonance) |resonance| {
            try applyResonanceEffects(state, resonance);
        }
        
        // Crystal depth can increase effective qubit count
        const depth_factor = @as(f64, @floatFromInt(crystal_state.depth)) / 
                           @as(f64, @floatFromInt(self.config.max_circuit_depth));
        
        // Apply depth boost to all qubits
        for (state.qubits) |*qubit| {
            // Increase superposition based on crystal depth
            qubit.amplitude0 *= (1.0 + depth_factor * 0.1);
            qubit.amplitude1 *= (1.0 + depth_factor * 0.1);
            
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
    
    /// Apply resonance effects from crystal state to quantum state
    fn applyResonanceEffects(
        state: *quantum_types.QuantumState,
        resonance: crystal_computing.ResonanceAnalysis,
    ) !void {
        // Simple resonance effect: boost amplitudes at resonant frequencies
        for (resonance.resonance_frequencies, resonance.q_factors) |freq, q_factor| {
            // Skip invalid frequencies
            if (freq <= 0.0 or freq >= 1.0) continue;
            
            // Calculate the index in the state vector
            const idx = @min(
                state.amplitudes.len - 1,
                @as(usize, @intFromFloat(freq * @as(f64, @floatFromInt(state.amplitudes.len - 1))))
            );
            
            // Apply resonance boost based on Q-factor (quality factor)
            const boost = 1.0 + (0.1 * q_factor);  // Up to 10% boost per Q-factor unit
            state.amplitudes[idx].re *= boost;
            state.amplitudes[idx].im *= boost;
        }
    }
    
    /// Set the quantum state (use with caution)
    pub fn setState(self: *QuantumProcessor, new_state: quantum_types.QuantumState) !void {
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
            if (std.math.fabs(norm - 1.0) > 1e-10) {
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
    pub fn reset(self: *QuantumProcessor) void {
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
    pub fn getState(self: *const QuantumProcessor) quantum_types.QuantumState {
        return self.state;
    }
    


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
