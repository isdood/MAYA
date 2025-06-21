const std = @import("std");
const neural = @import("neural");

pub fn main() !void {
    try neural.QuantumProcessor.Benchmarks.main();
}
