#!/usr/bin/env fish

# 012-DEBUG-1.fish
# GLIMMER Pattern Integration: Hot Pink (#FF69B4) for error detection
set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-1) - Zig Build Error Resolution"
set_color normal

# Store current directory
set current_dir (pwd)

# Function to check Zig version
function check_zig_version
    set_color cyan
    echo "✨ Checking Zig version..."
    set_color normal
    set zig_version (zig version)
    echo "Current Zig version: $zig_version"
end

# Function to backup build.zig
function backup_build_file
    set_color cyan
    echo "✨ Creating backup of build.zig..."
    set_color normal
    cp build.zig "build.zig.backup_(date +%Y%m%d_%H%M%S)"
end

# Function to update build.zig
function update_build_file
    set_color cyan
    echo "✨ Updating build.zig file..."
    set_color normal

    # Create temporary file
    set temp_file (mktemp)

    # Process build.zig line by line
    while read -l line
        # Replace deprecated no_entry with modern syntax
        if string match -q "*maya_wasm.no_entry*" -- $line
            echo "    maya_wasm.setEntryPoint(null);" >> $temp_file
        else
            echo $line >> $temp_file
        end
    end < build.zig

    # Replace original file with updated version
    mv $temp_file build.zig
end

# Function to clean build artifacts
function clean_build
    set_color cyan
    echo "✨ Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
end

# Function to attempt rebuild
function attempt_rebuild
    set_color cyan
    echo "✨ Attempting rebuild..."
    set_color normal
    zig build
end

# Main execution
echo "🔮 Starting MAYA build error resolution..."

# Execute steps
check_zig_version
backup_build_file
update_build_file
clean_build
attempt_rebuild

# Check if build succeeded
if test $status -eq 0
    set_color green
    echo "✨ Build successful! MAYA's quantum threads are aligned."
else
    set_color red
    echo "⚠️ Build still failing. Creating debug report..."

    # Create debug report
    set debug_report "debug_report_(date +%Y%m%d_%H%M%S).txt"
    echo "MAYA Debug Report" > $debug_report
    echo "==================" >> $debug_report
    echo "Timestamp: "(date)" UTC" >> $debug_report
    echo "Zig Version: "$zig_version >> $debug_report
    echo "Build Error Output:" >> $debug_report
    zig build 2>> $debug_report

    echo "Debug report saved to: $debug_report"
    echo "Please proceed with creating 012-DEBUG-2.fish if needed."
end

set_color normal
echo "✨ Debug script complete ✨"
