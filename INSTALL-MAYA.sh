#! /bin/bash

#!/bin/bash

# Error handling
set -e  # Exit on error
set -u  # Exit on undefined variable

echo "Starting MAYA installation script..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status messages
print_status() {
    echo "==> $1"
}

# Install Paru if not already installed
if ! command_exists paru; then
    print_status "Installing Paru AUR helper..."
    sudo pacman -S --needed base-devel --noconfirm
    cd ~/
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ..
    rm -rf paru
else
    print_status "Paru is already installed, skipping..."
fi

# Array of packages to install
packages=(
    "fish"
    "base-devel"
    "git"
    "zig-git"
    "cmake"
    "ninja"
    "rocm-opencl-runtime"
    "rocm-hip-runtime"
    "opencl-headers"
    "ocl-icd"
    "hip-runtime-amd"
    "clang"
    "lld"
    "llvm"
    "pkgconf"
    "python"
    "python-pip"
    "python-virtualenv"
    "glfw"
    "vulkan-headers"
    "vulkan-icd-loader"
    "libx11"
    "libxcb"
    "libxrandr"
    "libxi"
    "libxcursor"
    "libxinerama"
    "doxygen"
    "graphviz"
    "valgrind"
    "gdb"
)

# Install all packages
print_status "Installing required packages..."
paru -S --needed --noconfirm "${packages[@]}"

print_status "Installation complete! All required packages have been installed."
