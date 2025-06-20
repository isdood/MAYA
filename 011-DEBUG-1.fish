
#!/usr/bin/env fish

# MAYA Debug Script 1: File Structure Verification
# Author: isdood
# Date: 2025-06-18
# Purpose: Verify and report on required file structure for MAYA compilation

# Set GLIMMER colors for output
set -l ERROR_COLOR (set_color FF0000)
set -l SUCCESS_COLOR (set_color 00FF00)
set -l INFO_COLOR (set_color 00FFFF)
set -l RESET_COLOR (set_color normal)

# Required files array
set required_files \
    "src/wasm.zig" \
    "src/test/main.zig" \
    "src/core/main.zig" \
    "src/main.zig" \
    "src/glimmer/patterns.zig" \
    "src/neural/bridge.zig" \
    "src/starweave/protocol.zig" \
    "src/glimmer/colors.zig"

function check_file
    set -l file $argv[1]
    if test -f $file
        echo "$SUCCESS_COLOR✓ Found: $file$RESET_COLOR"
        return 0
    else
        echo "$ERROR_COLOR✗ Missing: $file$RESET_COLOR"
        return 1
    end
end

function create_missing_structure
    set -l file $argv[1]
    set -l dir (dirname $file)

    if not test -d $dir
        mkdir -p $dir
        echo "$INFO_COLOR➜ Created directory: $dir$RESET_COLOR"
    end

    if not test -f $file
        touch $file
        echo "$INFO_COLOR➜ Created empty file: $file$RESET_COLOR"
    end
end

# Main execution
echo "$INFO_COLOR\nMAYA File Structure Verification$RESET_COLOR"
echo "==========================================\n"

set -l missing_count 0
set -l found_count 0

# First pass: Check all required files
for file in $required_files
    if not check_file $file
        set missing_count (math $missing_count + 1)
    else
        set found_count (math $found_count + 1)
    end
end

# Report summary
echo "\n$INFO_COLOR=== Summary ===$RESET_COLOR"
echo "Files found: $SUCCESS_COLOR$found_count$RESET_COLOR"
echo "Files missing: $ERROR_COLOR$missing_count$RESET_COLOR"

# Ask user if they want to create missing structure
if test $missing_count -gt 0
    echo "\n$INFO_COLOR Would you like to create the missing file structure? [y/N]$RESET_COLOR"
    read -l response

    if test "$response" = "y" -o "$response" = "Y"
        for file in $required_files
            if not test -f $file
                create_missing_structure $file
            end
        end
        echo "\n$SUCCESS_COLOR✓ File structure created$RESET_COLOR"
    else
        echo "\n$INFO_COLOR Operation cancelled$RESET_COLOR"
    end
end

# Check Zig cache directories
echo "\n$INFO_COLOR=== Cache Directories ===$RESET_COLOR"
for cache_dir in "/home/shimmer/MAYA/.zig-cache" "/home/shimmer/.cache/zig"
    if test -d $cache_dir
        echo "$SUCCESS_COLOR✓ Found: $cache_dir$RESET_COLOR"
    else
        echo "$ERROR_COLOR✗ Missing: $cache_dir$RESET_COLOR"
        echo "$INFO_COLOR➜ Try running: mkdir -p $cache_dir$RESET_COLOR"
    end
end

# Verify Zig installation
echo "\n$INFO_COLOR=== Zig Installation ===$RESET_COLOR"
if command -v zig >/dev/null
    set -l zig_version (zig version)
    echo "$SUCCESS_COLOR✓ Zig installed: $zig_version$RESET_COLOR"
else
    echo "$ERROR_COLOR✗ Zig not found in PATH$RESET_COLOR"
end
