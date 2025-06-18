#!/usr/bin/env fish

# MAYA Debug Script 2: Widget and ImGui Error Resolution
# Author: isdood
# Date: 2025-06-18 20:10:30
# Purpose: Address widget parameter and ImGui integration issues

# GLIMMER color scheme for output
set -l ERROR_COLOR (set_color FF69B4) # GLIMMER pink
set -l SUCCESS_COLOR (set_color 00FFB4) # GLIMMER cyan
set -l INFO_COLOR (set_color B469FF) # GLIMMER purple
set -l WARNING_COLOR (set_color FFB400) # GLIMMER amber
set -l RESET_COLOR (set_color normal)

# Define widget files to check
set widget_file "src/renderer/widgets.zig"
set imgui_file "src/renderer/imgui.zig"
set layout_file "src/renderer/layout.zig"

function check_cimgui_headers
    set -l cimgui_paths \
        "/usr/include/cimgui.h" \
        "/usr/local/include/cimgui.h" \
        "./vendor/cimgui/cimgui.h"

    echo "$INFO_COLOR\n=== Checking cimgui Headers ===$RESET_COLOR"

    set -l found false
    for path in $cimgui_paths
        if test -f $path
            echo "$SUCCESS_COLOR✓ Found cimgui.h at: $path$RESET_COLOR"
            set found true
            # Check for C++ templates in header
            if grep -q "ImGuiTextFilter::ImGuiTextRange" $path
                echo "$WARNING_COLOR⚠ C++ templates found in cimgui.h - may need C-compatible version$RESET_COLOR"
            end
        end
    end

    if test $found = false
        echo "$ERROR_COLOR✗ cimgui.h not found in standard locations$RESET_COLOR"
        echo "$INFO_COLOR➜ Consider installing cimgui or updating include paths$RESET_COLOR"
    end
end

function fix_widget_parameters
    echo "$INFO_COLOR\n=== Fixing Unused Widget Parameters ===$RESET_COLOR"

    if not test -f $widget_file
        echo "$ERROR_COLOR✗ Widget file not found: $widget_file$RESET_COLOR"
        return 1
    end

    # Create backup
    cp $widget_file "$widget_file.bak"
    echo "$SUCCESS_COLOR✓ Created backup: $widget_file.bak$RESET_COLOR"

    # Fix unused parameters by adding _ prefix
    sed -i 's/fn render(widget: \*Widget)/fn render(_widget: *Widget)/g' $widget_file
    echo "$SUCCESS_COLOR✓ Updated unused widget parameters$RESET_COLOR"

    # Check if any render functions still have unused parameters
    set -l unused_params (grep -n "fn render(widget: \*Widget)" $widget_file)
    if test -n "$unused_params"
        echo "$WARNING_COLOR⚠ Some widget parameters still need fixing:$RESET_COLOR"
        echo $unused_params
    end
end

function setup_imgui_bindings
    echo "$INFO_COLOR\n=== Setting up ImGui Bindings ===$RESET_COLOR"

    # Create vendor directory if it doesn't exist
    if not test -d vendor/cimgui
        mkdir -p vendor/cimgui
        echo "$INFO_COLOR➜ Created vendor/cimgui directory$RESET_COLOR"
    end

    # Check if we need to download cimgui
    if not test -f vendor/cimgui/cimgui.h
        echo "$INFO_COLOR➜ Downloading cimgui...$RESET_COLOR"
        git clone https://github.com/cimgui/cimgui.git vendor/cimgui-temp
        and mv vendor/cimgui-temp/* vendor/cimgui/
        and rm -rf vendor/cimgui-temp
        echo "$SUCCESS_COLOR✓ Downloaded cimgui$RESET_COLOR"
    end

    # Update build.zig to include vendor paths
    if test -f build.zig
        # Add vendor include path if not present
        if not grep -q "vendor/cimgui" build.zig
            echo "$INFO_COLOR➜ Adding vendor include path to build.zig$RESET_COLOR"
            sed -i '/addIncludePath/ a\    exe.addIncludePath("vendor/cimgui");' build.zig
        end
    end
end

function check_vulkan_deps
    echo "$INFO_COLOR\n=== Checking Vulkan Dependencies ===$RESET_COLOR"

    # Check for Vulkan SDK
    if test -n "$VULKAN_SDK"
        echo "$SUCCESS_COLOR✓ Vulkan SDK found: $VULKAN_SDK$RESET_COLOR"
    else
        echo "$ERROR_COLOR✗ Vulkan SDK not found in environment$RESET_COLOR"
        echo "$INFO_COLOR➜ Consider installing Vulkan SDK or setting VULKAN_SDK$RESET_COLOR"
    end

    # Check for required libraries
    for lib in glfw vulkan freetype harfbuzz
        if pkg-config --exists $lib
            echo "$SUCCESS_COLOR✓ Found $lib (version "(pkg-config --modversion $lib)")$RESET_COLOR"
        else
            echo "$ERROR_COLOR✗ Missing library: $lib$RESET_COLOR"
        end
    end
end

# Main execution
echo "$INFO_COLOR\nMAYA Widget and ImGui Debug$RESET_COLOR"
echo "============================\n"

# Run all checks
check_cimgui_headers
fix_widget_parameters
setup_imgui_bindings
check_vulkan_deps

# Final recommendations
echo "$INFO_COLOR\n=== Recommendations ===$RESET_COLOR"
echo "1. Ensure all widget render functions use parameters or prefix unused ones with _"
echo "2. Update cimgui bindings to use C-compatible declarations"
echo "3. Verify Vulkan and GLFW integration in build script"
echo "\nTo apply fixes, run:"
echo "$SUCCESS_COLOR➜ zig build maya-test$RESET_COLOR"

# Create helper script for cimgui fixes if needed
if not test -f fix_cimgui.sh
    echo "#!/bin/bash
sed -i 's/ImGuiTextFilter::ImGuiTextRange/ImGuiTextFilterRange/g' vendor/cimgui/cimgui.h
sed -i 's/ImStb::STB_TexteditState/ImStbTextEditState/g' vendor/cimgui/cimgui.h
sed -i 's/ImChunkStream<.*>/ImChunkStream_Generic/g' vendor/cimgui/cimgui.h
sed -i 's/ImPool<.*>/ImPool_Generic/g' vendor/cimgui/cimgui.h
sed -i 's/ImSpan<.*>/ImSpan_Generic/g' vendor/cimgui/cimgui.h" > fix_cimgui.sh
    chmod +x fix_cimgui.sh
    echo "$INFO_COLOR➜ Created fix_cimgui.sh to handle C++ template issues$RESET_COLOR"
end
