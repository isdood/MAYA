# Window Resizing Issue

## Problem Description
The application crashes when the window is resized. The crash is accompanied by Vulkan validation errors indicating a mismatch between the depth buffer dimensions and the framebuffer dimensions.

### Validation Errors
```
Validation Error: [ VUID-VkFramebufferCreateInfo-flags-04533 ]
vkCreateFramebuffer(): pCreateInfo->pAttachments[1] mip level 0 has width (1280) smaller than the corresponding framebuffer width (1287).

Validation Error: [ VUID-VkFramebufferCreateInfo-flags-04534 ]
vkCreateFramebuffer(): pCreateInfo->pAttachments[1] mip level 0 has height (720) smaller than the corresponding framebuffer height (724).
```

## Technical Details
- The issue occurs during the swapchain recreation process
- The depth buffer (attachment[1]) dimensions don't match the new framebuffer dimensions
- Current depth buffer size: 1280x720
- Required framebuffer size: 1287x724

## Attempted Solutions
1. Updated framebuffer resize callback setup
2. Modified drawFrame function to handle resize events more robustly
3. Ensured proper cleanup of resources during swapchain recreation
4. Verified that depth buffer creation uses swapchain extent

## Current Status
- Issue persists despite attempted fixes
- The root cause appears to be in the timing or synchronization of resource recreation
- May be related to how the window dimensions are queried during resize

## Next Steps
1. Investigate window dimension querying during resize
2. Consider adding debug logging for dimension changes
3. Review the swapchain recreation sequence
4. Consider implementing a more robust resize handling mechanism

## Related Files
- `src/renderer/vulkan.zig`
  - `createDepthResources()`
  - `recreateSwapChain()`
  - `drawFrame()`
  - `framebufferResizeCallback()`

## Notes
- The issue may be related to how GLFW reports window dimensions during resize
- Consider implementing a resize queue or delay mechanism
- May need to investigate if the issue is platform-specific 