#include <vulkan/vulkan.h>
#include <stdio.h>

int main() {
    printf("1. Starting Vulkan test...\n");
    
    // 1. Application info
    VkApplicationInfo app_info = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = NULL,
        .pApplicationName = "VulkanTest",
        .applicationVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
        .pEngineName = "NoEngine",
        .engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0),
        .apiVersion = VK_API_VERSION_1_0
    };
    
    printf("2. Created application info\n");
    
    // 2. Instance create info
    VkInstanceCreateInfo create_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = NULL,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = NULL
    };
    
    printf("3. Created instance create info\n");
    
    // 3. Create instance
    VkInstance instance;
    printf("4. Creating Vulkan instance...\n");
    
    VkResult result = vkCreateInstance(&create_info, NULL, &instance);
    
    if (result != VK_SUCCESS) {
        printf("5. Failed to create Vulkan instance: %d\n", result);
        return 1;
    }
    
    printf("5. Successfully created Vulkan instance!\n");
    
    // Cleanup
    vkDestroyInstance(instance, NULL);
    printf("6. Cleaned up Vulkan instance\n");
    
    return 0;
}
