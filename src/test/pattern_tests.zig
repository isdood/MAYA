
const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
const LanguageProcessor = @import("language_processor.zig").LanguageProcessor;

pub fn runPatternTests() !void {
    print("\nMAYA Pattern Tests\n", .{});
    print("=================\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var processor = try LanguageProcessor.init(allocator);
    defer processor.deinit();

    // Test pattern addition with metadata
    try testPatternWithMetadata(&processor);
    
    // Test pattern validation
    try testPatternValidation(&processor);
    
    // Test pattern operations
    try testPatternOperations(&processor);
    
    // Test memory management
    try testMemoryManagement(&processor);
}

fn testPatternWithMetadata(processor: *LanguageProcessor) !void {
    print("Testing pattern with metadata...\n", .{});
    
    const metadata = "{\"type\": \"test\", \"version\": 1}";
    try processor.addPattern("test3", "Pattern with metadata", metadata);
    
    // Verify the pattern was added with metadata
    for (processor.patterns.items) |pattern| {
        if (std.mem.eql(u8, pattern.name, "test3")) {
            if (pattern.metadata) |meta| {
                if (!std.mem.eql(u8, meta, metadata)) {
                    print("Error: Metadata mismatch\n", .{});
                    return error.MetadataMismatch;
                }
            } else {
                print("Error: Metadata is null\n", .{});
                return error.MetadataMissing;
            }
        }
    }
    print("✓ Pattern with metadata test passed\n", .{});
}

fn testPatternValidation(processor: *LanguageProcessor) !void {
    print("\nTesting pattern validation...\n", .{});
    
    // Test empty name
    if (processor.addPattern("", "Content", null)) {
        print("Error: Empty name was accepted\n", .{});
        return error.EmptyNameAccepted;
    } else |err| {
        if (err != error.InvalidPattern) {
            print("Error: Unexpected error for empty name: {}\n", .{err});
            return error.UnexpectedError;
        }
        print("✓ Empty name correctly rejected\n", .{});
    }
    
    // Test empty content
    if (processor.addPattern("name", "", null)) {
        print("Error: Empty content was accepted\n", .{});
        return error.EmptyContentAccepted;
    } else |err| {
        if (err != error.InvalidPattern) {
            print("Error: Unexpected error for empty content: {}\n", .{err});
            return error.UnexpectedError;
        }
        print("✓ Empty content correctly rejected\n", .{});
    }
    
    print("✓ Pattern validation test passed\n", .{});
}

fn testPatternOperations(processor: *LanguageProcessor) !void {
    print("\nTesting pattern operations...\n", .{});
    
    // Test pattern addition
    try processor.addPattern("test4", "Test pattern 4", null);
    try processor.addPattern("test5", "Test pattern 5", null);
    
    // Test pattern listing
    var count: usize = 0;
    for (processor.patterns.items) |pattern| {
        if (std.mem.eql(u8, pattern.name, "test4") or 
            std.mem.eql(u8, pattern.name, "test5")) {
            count += 1;
        }
    }
    
    if (count != 2) {
        print("Error: Expected 2 patterns, found {}\n", .{count});
        return error.PatternCountMismatch;
    }
    
    print("✓ Pattern operations test passed\n", .{});
}

fn testMemoryManagement(processor: *LanguageProcessor) !void {
    print("\nTesting memory management...\n", .{});
    
    // Test memory allocation and deallocation
    const test_pattern = "test6";
    const test_content = "Test pattern 6";
    
    try processor.addPattern(test_pattern, test_content, null);
    
    // Force a reallocation by adding many patterns
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const name = try std.fmt.allocPrint(processor.allocator, "test{}", .{i + 7});
        defer processor.allocator.free(name);
        try processor.addPattern(name, "Test pattern", null);
    }
    
    // Verify the original pattern is still intact
    for (processor.patterns.items) |pattern| {
        if (std.mem.eql(u8, pattern.name, test_pattern)) {
            if (!std.mem.eql(u8, pattern.content, test_content)) {
                print("Error: Pattern content corrupted after reallocation\n", .{});
                return error.PatternCorrupted;
            }
        }
    }
    
    print("✓ Memory management test passed\n", .{});
} 
