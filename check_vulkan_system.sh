#!/bin/bash

# Check Vulkan installation
echo "=== Vulkan System Check ==="
echo ""

# Check if vulkaninfo is installed
if ! command -v vulkaninfo &> /dev/null; then
    echo "ERROR: vulkaninfo is not installed."
    echo "Please install the Vulkan development packages for your distribution:"
    echo "  Ubuntu/Debian: sudo apt install vulkan-tools"
    echo "  Fedora: sudo dnf install vulkan-tools"
    echo "  Arch: sudo pacman -S vulkan-tools"
    exit 1
fi

# Run vulkaninfo with error handling
echo "=== Running vulkaninfo (summary) ==="
if ! vulkaninfo --summary; then
    echo "ERROR: Failed to run vulkaninfo"
    echo "This suggests there might be an issue with your Vulkan installation."
    exit 1
fi

# Check ICDs
echo -e "\n=== Checking Vulkan ICDs ==="

check_icds() {
    local path=$1
    if [ -d "$path" ]; then
        echo "Checking $path:"
        for f in "$path"/*.json; do
            if [ -f "$f" ]; then
                echo "  Found: $(basename "$f")"
                echo "    $(head -n 1 "$f")"
            fi
        done
    else
        echo "Directory not found: $path"
    fi
}

check_icds "/usr/share/vulkan/icd.d"
check_icds "/usr/local/share/vulkan/icd.d"
check_icds "/etc/vulkan/icd.d"

# Check environment variables
echo -e "\n=== Environment Variables ==="
for var in VK_LOADER_DEBUG VK_ICD_FILENAMES VK_LAYER_PATH VK_INSTANCE_LAYERS; do
    if [ -n "${!var}" ]; then
        echo "$var=${!var}"
    else
        echo "$var is not set"
    fi
done

# Check GPU information
echo -e "\n=== GPU Information ==="
if command -v lspci &> /dev/null; then
    echo "PCI Devices:"
    lspci | grep -i vga
    lspci | grep -i 3d
else
    echo "lspci not found. Install pciutils to see GPU information."
fi

# Check Vulkan loader debug info
echo -e "\n=== Vulkan Loader Debug ==="
VK_LOADER_DEBUG=all vulkaninfo --summary 2>&1 | head -n 20 | grep -i -E 'loader|vulkan|gpu|device'

echo -e "\n=== Vulkan Check Complete ==="
