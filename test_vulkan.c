#include <vulkan/vulkan.h>
#include <stdio.h>

int main() {
    printf("Testing Vulkan initialization...\n");
    
    // Initialize Vulkan
    VkApplicationInfo appInfo = {0};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Vulkan Test";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_0;

    VkInstanceCreateInfo createInfo = {0};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;

    // Check Vulkan version
    uint32_t instanceVersion = 0;
    VkResult result = vkEnumerateInstanceVersion(&instanceVersion);
    if (result != VK_SUCCESS) {
        printf("Failed to get Vulkan instance version: %d\n", result);
        return 1;
    }
    printf("Vulkan instance version: %d.%d.%d\n", 
           VK_VERSION_MAJOR(instanceVersion),
           VK_VERSION_MINOR(instanceVersion),
           VK_VERSION_PATCH(instanceVersion));

    // Create Vulkan instance
    VkInstance instance;
    result = vkCreateInstance(&createInfo, NULL, &instance);
    if (result != VK_SUCCESS) {
        printf("Failed to create Vulkan instance: %d\n", result);
        return 1;
    }

    printf("Successfully created Vulkan instance!\n");

    // Cleanup
    vkDestroyInstance(instance, NULL);
    
    return 0;
}
