const std = @import("std");
const Allocator = std.mem.Allocator;
const crypto = std.crypto;

const VulkanContext = @import("vulkan_context").VulkanContext;
const VulkanMemory = @import("vulkan_memory").VulkanMemory;
const VulkanBuffer = @import("vulkan_buffer").Buffer;
const VulkanImage = @import("vulkan_image").VulkanImage;
const PatternMatcher = @import("vulkan_pattern_matcher").PatternMatcher; 
const vk = @import("vk");

// Import the pattern matching method enum if needed
const PatternMatchingMethod = @import("vulkan/pattern_matcher").PatternMatchingMethod;

// Generate a simple test pattern
fn generateTestPattern(width: u32, height: u32, pattern_size: u32) ![]u8 {
    const pixel_size = 4; // RGBA
    const data = try std.heap.page_allocator.alloc(u8, width * height * pixel_size);
    
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = (y * width + x) * pixel_size;
            // Create a checkerboard pattern
            const is_white = ((x / pattern_size) + (y / pattern_size)) % 2 == 0;
            const value: u8 = if (is_white) 0xFF else 0x00;
            
            data[idx] = value;     // R
            data[idx + 1] = value; // G
            data[idx + 2] = value; // B
            data[idx + 3] = 0xFF;  // A
        }
    }
    
    return data;
}

pub fn main() !void {
    std.debug.print("Starting pattern matching test...\n", .{});
    
    // Initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Vulkan context
    std.debug.print("Initializing Vulkan context...\n", .{});
    var vulkan_context = try VulkanContext.init(allocator);
    defer vulkan_context.deinit();

    // Initialize pattern matcher
    std.debug.print("Initializing pattern matcher...\n", .{});
    var matcher = try PatternMatcher.init(allocator, &vulkan_context);
    defer matcher.deinit();

    // Create a test image (256x256)
    const width: u32 = 256;
    const height: u32 = 256;
    std.debug.print("Creating test image ({}x{})...\n", .{width, height});
    
    // Generate test pattern (large checkerboard)
    const image_data = try generateTestPattern(width, height, 16);
    defer std.heap.page_allocator.free(image_data);
    
    // Create Vulkan image from pixel data
    var image = try VulkanImage.createStorageImage(
        &vulkan_context,
        allocator,
        width,
        height,
        vk.VK_FORMAT_R8G8B8A8_UNORM,
    );
    defer image.deinit();

    // Create a pattern to search for (16x16)
    const pattern_width: u32 = 16;
    const pattern_height: u32 = 16;
    std.debug.print("Creating pattern ({}x{})...\n", .{pattern_width, pattern_height});
    
    // Generate pattern (small checkerboard)
    const pattern_data = try generateTestPattern(pattern_width, pattern_height, 4);
    defer std.heap.page_allocator.free(pattern_data);
    
    // Create Vulkan image for the pattern
    var pattern_image = try VulkanImage.createStorageImage(
        &vulkan_context,
        allocator,
        pattern_width,
        pattern_height,
        vk.VK_FORMAT_R8G8B8A8_UNORM,
    );
    defer pattern_image.deinit();
    
    // Create output image for the results
    var output_image = try VulkanImage.createStorageImage(
        &vulkan_context,
        allocator,
        width,
        height,
        vk.VK_FORMAT_R32_SFLOAT, // Single channel float for scores
    );
    defer output_image.deinit();

    // Upload image data to GPU
    {
        // Create a temporary buffer to hold the image data
        const staging_buffer = try VulkanBuffer.init(
            vulkan_context.device.?, 
            vulkan_context.physical_device.?, 
            image_data.len,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
        );
        defer staging_buffer.deinit(vulkan_context.device.?);
        
        // Copy image data to staging buffer
        try staging_buffer.upload(vulkan_context.device.?, 0, image_data);
        
        // Upload to GPU
        const command_buffer = try VulkanBuffer.beginSingleTimeCommands(
            vulkan_context.device.?, 
            vulkan_context.command_pool.?
        );
        
        // Transition image layout for transfer
        image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
        );
        
        // Copy from staging buffer to image
        const region = vk.VkBufferImageCopy{
            .bufferOffset = 0,
            .bufferRowLength = 0,
            .bufferImageHeight = 0,
            .imageSubresource = .{
                .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = 0,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
            .imageExtent = .{ .width = width, .height = height, .depth = 1 },
        };
        
        vk.vkCmdCopyBufferToImage(
            command_buffer,
            staging_buffer.vk_buffer,
            image.image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &region
        );
        
        // Transition image layout for shader access
        image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            vk.VK_IMAGE_LAYOUT_GENERAL
        );
        
        // Submit the command buffer
        try VulkanBuffer.endSingleTimeCommands(
            vulkan_context.device.?,
            vulkan_context.compute_queue.?, 
            vulkan_context.command_pool.?, 
            command_buffer
        );
    }
    
    // Upload pattern data to GPU
    {
        // Create a temporary buffer to hold the pattern data
        const staging_buffer = try VulkanBuffer.init(
            vulkan_context.device.?, 
            vulkan_context.physical_device.?, 
            pattern_data.len,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
        );
        defer staging_buffer.deinit(vulkan_context.device.?);
        
        // Copy pattern data to staging buffer
        try staging_buffer.upload(vulkan_context.device.?, 0, pattern_data);
        
        // Upload to GPU
        const command_buffer = try VulkanBuffer.beginSingleTimeCommands(
            vulkan_context.device.?, 
            vulkan_context.command_pool.?
        );
        
        // Transition image layout for transfer
        pattern_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
        );
        
        // Copy from staging buffer to image
        const region = vk.VkBufferImageCopy{
            .bufferOffset = 0,
            .bufferRowLength = 0,
            .bufferImageHeight = 0,
            .imageSubresource = .{
                .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = 0,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
            .imageExtent = .{ .width = pattern_width, .height = pattern_height, .depth = 1 },
        };
        
        vk.vkCmdCopyBufferToImage(
            command_buffer,
            staging_buffer.vk_buffer,
            pattern_image.image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &region
        );
        
        // Transition image layout for shader access
        pattern_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            vk.VK_IMAGE_LAYOUT_GENERAL
        );
        
        // Submit the command buffer
        try VulkanBuffer.endSingleTimeCommands(
            vulkan_context.device.?,
            vulkan_context.compute_queue.?, 
            vulkan_context.command_pool.?, 
            command_buffer
        );
    }
    
    // Initialize the output image
    {
        const command_buffer = try VulkanBuffer.beginSingleTimeCommands(
            vulkan_context.device.?, 
            vulkan_context.command_pool.?
        );
        
        // Transition image layout for general use
        output_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_GENERAL
        );
        
        // Submit the command buffer
        try VulkanBuffer.endSingleTimeCommands(
            vulkan_context.device.?,
            vulkan_context.compute_queue.?, 
            vulkan_context.command_pool.?, 
            command_buffer
        );
    }
    
    // Run pattern matching
    std.debug.print("Running pattern matching...\n", .{});
    try matcher.match(
        image,
        pattern_image,
        output_image,
        .{
            .scale = 1.0,
            .rotation = 0.0,
            .threshold = 0.5,
            .method = .ncc,
        },
    );
    
    // Read back results (optional)
    {
        // Create a buffer to read back results
        const buffer_size = width * height * @sizeOf(f32);
        const staging_buffer = try VulkanBuffer.init(
            vulkan_context.device.?, 
            vulkan_context.physical_device.?, 
            buffer_size,
            vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
        );
        defer staging_buffer.deinit(vulkan_context.device.?);
        
        // Copy image to buffer
        const command_buffer = try VulkanBuffer.beginSingleTimeCommands(
            vulkan_context.device.?, 
            vulkan_context.command_pool.?
        );
        
        // Transition image layout for transfer
        output_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_GENERAL,
            vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
        );
        
        // Copy image to buffer
        const region = vk.VkBufferImageCopy{
            .bufferOffset = 0,
            .bufferRowLength = 0,
            .bufferImageHeight = 0,
            .imageSubresource = .{
                .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = 0,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
            .imageExtent = .{ .width = width, .height = height, .depth = 1 },
        };
        
        vk.vkCmdCopyImageToBuffer(
            command_buffer,
            output_image.image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            staging_buffer.vk_buffer,
            1,
            &region
        );
        
        // Submit the command buffer
        try VulkanBuffer.endSingleTimeCommands(
            vulkan_context.device.?,
            vulkan_context.compute_queue.?, 
            vulkan_context.command_pool.?, 
            command_buffer
        );
        
        // Map the buffer and find the best match
        var mapped_ptr: *anyopaque = undefined;
        try vk.checkSuccess(vk.vkMapMemory(
            vulkan_context.device.?, 
            staging_buffer.memory, 
            0, 
            buffer_size, 
            0, 
            @ptrCast(&mapped_ptr)
        ), error.FailedToMapMemory);
        
        defer vk.vkUnmapMemory(vulkan_context.device.?, staging_buffer.memory);
        
        const scores = @as([*]align(1) const f32, @ptrCast(mapped_ptr))[0 .. buffer_size / @sizeOf(f32)];
        
        var max_score: f32 = 0;
        var best_x: u32 = 0;
        var best_y: u32 = 0;
        
        for (0..height) |y| {
            for (0..width) |x| {
                const idx = y * width + x;
                const score = scores[idx];
                
                if (score > max_score) {
                    max_score = score;
                    best_x = @intCast(x);
                    best_y = @intCast(y);
                }
            }
        }
        
        std.debug.print("Best match at ({}, {}) with score: {}\n", .{
            best_x, best_y, max_score
        });
        
        // Validate the results
        const is_valid = validateResults(best_x, best_y, width, height);
        if (is_valid) {
            std.debug.print("Test PASSED! Pattern found at expected location.\n", .{});
        } else {
            std.debug.print("Test FAILED! Pattern not found at expected location.\n", .{});
            return error.PatternMatchFailed;
        }
    }
}

// Helper function to check if the test passed
fn validateResults(best_x: u32, best_y: u32, width: u32, height: u32) bool {
    // Since we placed the pattern at (0,0), the best match should be near there
    const expected_x = 0;
    const expected_y = 0;
    
    // Calculate squared distance
    const dx = @as(i32, @intCast(best_x)) - expected_x;
    const dy = @as(i32, @intCast(best_y)) - expected_y;
    const distance_squared = @as(f32, @floatFromInt(dx * dx + dy * dy));
    const distance = std.math.sqrt(distance_squared);
    
    // Allow for some tolerance in the match position
    const max_distance = @min(width, height) / 4;
    return distance <= @as(f32, @floatFromInt(max_distance));
}
