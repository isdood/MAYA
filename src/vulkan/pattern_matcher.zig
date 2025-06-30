const std = @import("std");
const vk = @import("vk");

const Context = @import("vulkan_context").VulkanContext;
const VulkanImage = @import("vulkan_image").VulkanImage;
const VulkanBuffer = @import("buffer").VulkanBuffer;
const PatternMatchingPipeline = @import("vulkan_pattern_matching_pipeline").PatternMatchingPipeline;
const PatternMatchingConfig = @import("vulkan_pattern_matching_pipeline").PatternMatchingConfig;

/// High-level interface for GPU-accelerated pattern matching
pub const PatternMatcher = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    context: *Context,
    pipeline: PatternMatchingPipeline,
    
    /// Initialize the pattern matcher with a Vulkan context
    pub fn init(allocator: std.mem.Allocator, context: *Context) !Self {
        // Initialize the compute pipeline
        const pipeline = try PatternMatchingPipeline.init(
            context,
            allocator,
            1, // max_descriptor_sets
        );
        
        return Self{
            .allocator = allocator,
            .context = context,
            .pipeline = pipeline,
        };
    }
    
    /// Match a pattern in an image
    pub fn match(
        self: *Self,
        input_image: *VulkanImage,
        pattern_image: *VulkanImage,
        output_image: *VulkanImage,
        config: PatternMatchingConfig,
    ) !void {
        const device = self.context.device.?;
        const command_pool = self.context.command_pool.?;
        const queue = self.context.compute_queue.?;
        
        // Create a staging buffer for intermediate results
        const buffer_size = @as(vk.VkDeviceSize, @intCast(output_image.width * output_image.height * @sizeOf(f32)));
        var staging_buffer = try VulkanBuffer.createStaging(
            self.context,
            self.allocator,
            buffer_size,
        );
        defer {
            staging_buffer.deinit(self.context.device);
        }
        
        // Create a device-local buffer for the intermediate results
        var intermediate_buffer = try VulkanBuffer.createDeviceLocal(
            self.context,
            self.allocator,
            buffer_size,
            vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
        );
        defer {
            intermediate_buffer.deinit(self.context.device);
        }
        
        // Update descriptor sets
        try self.pipeline.updateDescriptorSets(
            0, // set_index
            input_image.view,
            pattern_image.view,
            output_image.view,
            intermediate_buffer.buffer,
            buffer_size
        );
        
        // Begin a command buffer
        const command_buffer = try VulkanBuffer.beginSingleTimeCommands(device, command_pool);
        
        // Transition input image layout
        input_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_GENERAL
        );
        
        // Transition pattern image layout
        pattern_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_GENERAL
        );
        
        // Transition output image layout
        output_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_UNDEFINED,
            vk.VK_IMAGE_LAYOUT_GENERAL
        );
        
        // Bind pipeline and dispatch compute shader
        self.pipeline.dispatch(
            command_buffer,
            0, // set_index
            output_image.width,
            output_image.height,
            pattern_image.width,
            pattern_image.height,
            config
        );
        
        // Transition output image for reading
        output_image.transitionLayout(
            command_buffer,
            vk.VK_IMAGE_LAYOUT_GENERAL,
            vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
        );
        
        // Copy results to staging buffer
        const copy_region = vk.VkBufferImageCopy{
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
            .imageExtent = .{ 
                .width = output_image.width, 
                .height = output_image.height, 
                .depth = 1 
            },
        };
        
        vk.vkCmdCopyImageToBuffer(
            command_buffer,
            output_image.image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            staging_buffer.buffer,
            1,
            &copy_region
        );
        
        // End and submit the command buffer
        try VulkanBuffer.endSingleTimeCommands(
            device,
            command_pool,
            queue,
            command_buffer
        );
        
        // Map the staging buffer to read results if needed
        // const mapped = try staging_buffer.map();
        // defer staging_buffer.unmap();
        // ... process results ...
    }
    
    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.pipeline.deinit();
    }
};

/// Helper function to create an image from pixel data
pub fn createImageFromPixels(
    context: *Context,
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    pixels: []const u8,
) !VulkanImage {
    const image_size = width * height * 4; // Assuming RGBA8
    
    // Create staging buffer
    const staging_buffer = try VulkanBuffer.createStaging(
        context,
        allocator,
        image_size,
    );
    defer staging_buffer.deinit();
    
    // Copy pixel data to staging buffer
    try staging_buffer.upload(pixels);
    
    // Create device-local image
    const image = try VulkanImage.createStorageImage(
        context,
        allocator,
        width,
        height,
        vk.VK_FORMAT_R8G8B8A8_UNORM,
    );
    
    // Begin a command buffer
    const command_buffer = try VulkanBuffer.beginSingleTimeCommands(
        context.device.?, 
        context.command_pool.?
    );
    
    // Transition image layout
    image.transitionLayout(
        command_buffer,
        vk.VK_IMAGE_LAYOUT_UNDEFINED,
        vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
    );
    
    // Copy buffer to image
    image.copyFromBuffer(command_buffer, staging_buffer.buffer, width, height);
    
    // Transition image layout for shader access
    image.transitionLayout(
        command_buffer,
        vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        vk.VK_IMAGE_LAYOUT_GENERAL
    );
    
    // End and submit the command buffer
    try VulkanBuffer.endSingleTimeCommands(
        context.device.?,
        context.compute_queue.?, 
        context.command_pool.?, 
        command_buffer
    );
    
    return image;
}
