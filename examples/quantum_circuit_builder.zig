const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();

// Simple Qubit State Representation
const QubitState = struct {
    alpha: f64 = 1.0,
    beta: f64 = 0.0,
    beta_imag: f64 = 0.0,

    pub fn applyGate(self: *@This(), gate: []const f64) void {
        const new_alpha = gate[0] * self.alpha + gate[1] * self.beta;
        const new_beta = gate[2] * self.alpha + gate[3] * self.beta;
        
        self.alpha = new_alpha;
        self.beta = new_beta;
        self.normalize();
    }

    fn normalize(self: *@This()) void {
        const norm = math.sqrt(self.alpha * self.alpha + 
                             self.beta * self.beta + 
                             self.beta_imag * self.beta_imag);
        if (norm > 0) {
            self.alpha /= norm;
            self.beta /= norm;
            self.beta_imag /= norm;
        }
    }

    pub fn measure(self: *@This()) bool {
        const prob1 = self.beta * self.beta + self.beta_imag * self.beta_imag;
        const r = std.crypto.random.float(f64);
        
        if (r < prob1) {
            self.alpha = 0.0;
            self.beta = 1.0;
            self.beta_imag = 0.0;
            return true;
        } else {
            self.alpha = 1.0;
            self.beta = 0.0;
            self.beta_imag = 0.0;
            return false;
        }
    }
};

// Quantum Gates
const Gates = struct {
    pub const X = &[_]f64{ 0, 1, 1, 0 };
    pub const Y = &[_]f64{ 0, -1, 1, 0 };
    pub const Z = &[_]f64{ 1, 0, 0, -1 };
    pub const H = &[_]f64{ 
        1.0/math.sqrt(2.0), 1.0/math.sqrt(2.0),
        1.0/math.sqrt(2.0), -1.0/math.sqrt(2.0) 
    };
    pub const S = &[_]f64{ 1, 0, 0, 1.0 };
    pub const T = &[_]f64{ 1, 0, 0, 0.5 + 0.5 };
    
    pub fn getGate(name: []const u8) ?[]const f64 {
        return std.meta.stringToEnum(enum { x, y, z, h, s, t }, std.ascii.lowerString(name, name)) orelse {
            return null;
        };
    }
};

// Quantum Circuit
const QuantumCircuit = struct {
    qubits: []QubitState,
    allocator: Allocator,
    history: std.ArrayList([]const u8),
    
    pub fn init(allocator: Allocator, num_qubits: usize) !@This() {
        const qubits = try allocator.alloc(QubitState, num_qubits);
        for (qubits) |*qubit| {
            qubit.* = QubitState{};
        }
        return .{ 
            .qubits = qubits, 
            .allocator = allocator,
            .history = std.ArrayList([]const u8).init(allocator)
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.qubits);
        self.history.deinit();
    }

    pub fn applyGate(self: *@This(), gate: []const f64, target: usize) !void {
        if (target >= self.qubits.len) return;
        self.qubits[target].applyGate(gate);
        try self.history.append(try std.fmt.allocPrint(self.allocator, "GATE {} {}", .{gate, target}));
    }

    pub fn applyControlledGate(self: *@This(), gate: []const f64, control: usize, target: usize) !void {
        if (control >= self.qubits.len or target >= self.qubits.len) return;
        if (self.qubits[control].measure()) {
            try self.applyGate(gate, target);
        }
        try self.history.append(try std.fmt.allocPrint(self.allocator, "CNOT {} {}", .{control, target}));
    }

    pub fn printState(self: *const @This()) !void {
        try stdout.print("\n=== Quantum Circuit State ===\n", .{});
        for (self.qubits, 0..) |qubit, i| {
            const prob0 = qubit.alpha * qubit.alpha;
            const prob1 = qubit.beta * qubit.beta + qubit.beta_imag * qubit.beta_imag;
            
            try stdout.print("Qubit {}: |ψ> = {d:.3}|0> + ({d:.3}{s}{d:.3}i)|1>  [P(0)={d:.3}, P(1)={d:.3}]\n", .{
                i,
                qubit.alpha,
                qubit.beta,
                if (qubit.beta_imag >= 0) "+" else "-",
                if (qubit.beta_imag >= 0) qubit.beta_imag else -qubit.beta_imag,
                prob0,
                prob1,
            });
        }
    }

    pub fn saveToFile(self: *const @This(), filename: []const u8) !void {
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();
        
        var writer = file.writer();
        for (self.history.items) |cmd| {
            try writer.print("{s}\n", .{cmd});
        }
    }

    pub fn loadFromFile(allocator: Allocator, filename: []const u8) !@This() {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        
        var reader = file.reader();
        var buffer: [1024]u8 = undefined;
        
        // First line is number of qubits
        if (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            const num_qubits = try std.fmt.parseInt(usize, line, 10);
            var circuit = try QuantumCircuit.init(allocator, num_qubits);
            
            while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |cmd| {
                var iter = std.mem.tokenize(u8, cmd, " ");
                const cmd_type = iter.next() orelse continue;
                
                if (std.mem.eql(u8, cmd_type, "GATE")) {
                    const gate = iter.next() orelse continue;
                    const target = try std.fmt.parseInt(usize, iter.next() orelse "0", 10);
                    try circuit.applyGate(Gates.getGate(gate) orelse continue, target);
                } else if (std.mem.eql(u8, cmd_type, "CNOT")) {
                    const control = try std.fmt.parseInt(usize, iter.next() orelse "0", 10);
                    const target = try std.fmt.parseInt(usize, iter.next() orelse "0", 10);
                    try circuit.applyControlledGate(Gates.X, control, target);
                }
            }
            return circuit;
        }
        return error.InvalidFileFormat;
    }
};

// Interactive Command Parser
const Command = union(enum) {
    help,
    quit,
    add_qubit: usize,
    apply_gate: struct { gate: []const u8, target: usize },
    cnot: struct { control: usize, target: usize },
    measure: usize,
    save: []const u8,
    load: []const u8,
    show,
    
    pub fn parse(input: []const u8) !Command {
        var iter = std.mem.tokenize(u8, input, " \t\r\n");
        const cmd = iter.next() orelse return error.InvalidCommand;
        
        if (std.mem.eql(u8, cmd, "help")) return .help;
        if (std.mem.eql(u8, cmd, "quit")) return .quit;
        if (std.mem.eql(u8, cmd, "show")) return .show;
        
        if (std.mem.eql(u8, cmd, "add")) {
            const count = iter.next() orelse return error.MissingArgument;
            return .{ .add_qubit = try std.fmt.parseInt(usize, count, 10) };
        }
        
        if (std.mem.eql(u8, cmd, "gate")) {
            const gate = iter.next() orelse return error.MissingArgument;
            const target = iter.next() orelse return error.MissingArgument;
            return .{ .apply_gate = .{
                .gate = gate,
                .target = try std.fmt.parseInt(usize, target, 10),
            }};
        }
        
        if (std.mem.eql(u8, cmd, "cnot")) {
            const control = iter.next() orelse return error.MissingArgument;
            const target = iter.next() orelse return error.MissingArgument;
            return .{ .cnot = .{
                .control = try std.fmt.parseInt(usize, control, 10),
                .target = try std.fmt.parseInt(usize, target, 10),
            }};
        }
        
        if (std.mem.eql(u8, cmd, "measure")) {
            const target = iter.next() orelse return error.MissingArgument;
            return .{ .measure = try std.fmt.parseInt(usize, target, 10) };
        }
        
        if (std.mem.eql(u8, cmd, "save")) {
            const filename = iter.rest();
            if (filename.len == 0) return error.MissingArgument;
            return .{ .save = filename };
        }
        
        if (std.mem.eql(u8, cmd, "load")) {
            const filename = iter.rest();
            if (filename.len == 0) return error.MissingArgument;
            return .{ .load = filename };
        }
        
        return error.UnknownCommand;
    }
};

// Main REPL
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var circuit = try QuantumCircuit.init(allocator, 1);
    defer circuit.deinit();
    
    var input_buf: [1024]u8 = undefined;
    
    try stdout.print("Quantum Circuit Builder\n");
    try stdout.print("Type 'help' for available commands\n\n");
    
    while (true) {
        try stdout.print("qcircuit> ", .{});
        
        if (try stdin.readUntilDelimiterOrEof(&input_buf, '\n')) |input| {
            const cmd = Command.parse(input) catch |err| {
                try stdout.print("Error: {s}\n", .{@errorName(err)});
                continue;
            };
            
            switch (cmd) {
                .help => {
                    try stdout.print(
                        \nAvailable commands:
                        \n  help                 - Show this help
                        \n  add <n>             - Add n qubits
                        \n  gate <name> <target> - Apply gate to qubit
                        \n  cnot <c> <t>        - Apply CNOT (control, target)
                        \n  measure <qubit>      - Measure a qubit
                        \n  save <file>          - Save circuit
                        \n  load <file>          - Load circuit
                        \n  show                 - Show current state
                        \n  quit                - Exit\n\n",
                        .{},
                    );
                },
                .quit => break,
                .add_qubit => |n| {
                    // In a real implementation, we'd resize the circuit
                    try stdout.print("Added {} qubit(s)\n", .{n});
                },
                .apply_gate => |g| {
                    if (Gates.getGate(g.gate)) |gate| {
                        try circuit.applyGate(gate, g.target);
                        try stdout.print("Applied gate {} to qubit {}\n", .{g.gate, g.target});
                    } else {
                        try stdout.print("Unknown gate: {s}\n", .{g.gate});
                    }
                },
                .cnot => |c| {
                    try circuit.applyControlledGate(Gates.X, c.control, c.target);
                    try stdout.print("Applied CNOT (control: {}, target: {})\n", .{c.control, c.target});
                },
                .measure => |q| {
                    const result = circuit.qubits[q].measure();
                    try stdout.print("Qubit {} measured: {}\n", .{q, @as(u8, if (result) '1' else '0')});
                },
                .save => |filename| {
                    try circuit.saveToFile(filename);
                    try stdout.print("Circuit saved to {s}\n", .{filename});
                },
                .load => |filename| {
                    circuit = try QuantumCircuit.loadFromFile(allocator, filename);
                    try stdout.print("Circuit loaded from {s}\n", .{filename});
                },
                .show => {
                    try circuit.printState();
                },
            }
        }
    }
}
