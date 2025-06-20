
#!/bin/bash

# MAYA GUI Development Environment Setup Script
# This script sets up the development environment for MAYA's GUI interface on ArchLinux

# Colors for output
QUANTUM_BLUE='\033[0;34m'
NEURAL_PURPLE='\033[0;35m'
COSMIC_GOLD='\033[1;33m'
STELLAR_WHITE='\033[1;37m'
RESET='\033[0m'

# Print with GLIMMER styling
print_glimmer() {
    echo -e "${COSMIC_GOLD}✨${STELLAR_WHITE} $1${RESET}"
}

print_step() {
    echo -e "\n${QUANTUM_BLUE}==>${STELLAR_WHITE} $1${RESET}"
}

print_substep() {
    echo -e "${NEURAL_PURPLE}  ->${STELLAR_WHITE} $1${RESET}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_glimmer "Please run this script with sudo"
    exit 1
fi

# Update system
print_step "Updating system packages"
pacman -Syu --noconfirm

# Install required packages
print_step "Installing development dependencies"
pacman -S --noconfirm \
    base-devel \
    git \
    cmake \
    ninja \
    vulkan-headers \
    vulkan-validation-layers \
    vulkan-tools \
    glfw \
    freetype2 \
    harfbuzz \
    pkg-config \
    xorg-server-devel \
    libx11 \
    libxrandr \
    libxinerama \
    libxcursor \
    libxi \
    mesa \
    wayland \
    wayland-protocols \
    libxkbcommon

# Install Zig
print_step "Installing Zig compiler"
if ! command -v zig &> /dev/null; then
    print_substep "Downloading Zig"
    curl -L https://ziglang.org/download/latest/zig-linux-x86_64.tar.xz -o zig.tar.xz
    tar xf zig.tar.xz
    mv zig-linux-x86_64 /usr/local/zig
    ln -sf /usr/local/zig/zig /usr/local/bin/zig
    rm zig.tar.xz
else
    print_substep "Zig is already installed"
fi

# Create development directories
print_step "Setting up development directories"
mkdir -p ~/MAYA/{src,build,lib}

# Set up environment variables
print_step "Configuring environment variables"
cat << 'EOF' >> ~/.bashrc

# MAYA Development Environment
export MAYA_ROOT=~/MAYA
export PATH=$PATH:$MAYA_ROOT/build/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$MAYA_ROOT/build/lib
export VK_LAYER_PATH=/usr/share/vulkan/explicit_layer.d
EOF

# Create build configuration
print_step "Creating build configuration"
cat << 'EOF' > ~/MAYA/build.ninja
# MAYA Build Configuration
ninja_required_version = 1.3

# Variables
zig = /usr/local/bin/zig
builddir = build
srcdir = src

# Build rules
rule zig_build
  command = $zig build -p $builddir $in
  description = Building $in

# Build targets
build $builddir/maya: zig_build $srcdir/main.zig
EOF

# Verify installation
print_step "Verifying installation"
print_substep "Checking Zig version"
zig version

print_substep "Checking Vulkan installation"
vulkaninfo --summary

print_substep "Checking GLFW installation"
pkg-config --modversion glfw3

# Print completion message
print_glimmer "MAYA development environment setup complete!"
print_glimmer "Please source your .bashrc or restart your terminal"
print_glimmer "Next steps:"
print_substep "1. Navigate to ~/MAYA"
print_substep "2. Run 'zig build' to test the build system"
print_substep "3. Start implementing the GUI components"

# Make the script executable
chmod +x "$0" 
