#!/bin/bash

echo "=== Checking Vulkan Installation ==="

# Check if vulkaninfo is available
if ! command -v vulkaninfo &> /dev/null; then
    echo "vulkaninfo is not installed. Please install the Vulkan development packages for your distribution."
    echo "On Ubuntu/Debian: sudo apt install vulkan-tools"
    echo "On Fedora: sudo dnf install vulkan-tools"
    echo "On Arch: sudo pacman -S vulkan-tools"
    exit 1
fi

echo -e "\n=== Vulkan Information ==="
# Run vulkaninfo and display the first 20 lines
vulkaninfo --summary | head -n 20

echo -e "\n=== Checking Vulkan ICDs ==="
# Check common Vulkan ICD locations
for path in "/usr/share/vulkan/icd.d" "/usr/local/share/vulkan/icd.d" "/etc/vulkan/icd.d"; do
    if [ -d "$path" ]; then
        echo -e "\nFound Vulkan ICDs in $path:"
        ls -l "$path/"*.json 2>/dev/null || echo "  No JSON files found in $path"
    else
        echo -e "\nDirectory not found: $path"
    fi
done

echo -e "\n=== Checking Vulkan Layers ==="
# Check common Vulkan layer locations
for path in "/usr/share/vulkan/explicit_layer.d" "/usr/local/share/vulkan/explicit_layer.d" "/etc/vulkan/explicit_layer.d"; do
    if [ -d "$path" ]; then
        echo -e "\nFound Vulkan layers in $path:"
        ls -l "$path/"*.json 2>/dev/null || echo "  No JSON files found in $path"
    fi
done

echo -e "\n=== Checking Environment Variables ==="
echo "VK_LAYER_PATH: ${VK_LAYER_PATH:-Not set}"
echo "VK_ICD_FILENAMES: ${VK_ICD_FILENAMES:-Not set}"

echo -e "\n=== Checking GPU Information ==="
# Try to get GPU information
if command -v lspci &> /dev/null; then
    echo "GPU Information:"
    lspci | grep -i vga
    lspci | grep -i 3d
else
    echo "lspci not found. Install pciutils to see GPU information."
fi

echo -e "\nTest completed."
