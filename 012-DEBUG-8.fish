@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-19 08:48:26",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./012-DEBUG-8.fish",
    "type": "fish",
    "hash": "2315ddc3b8181f8cac7a8bebea7f556a9f698f70"
  }
}
@pattern_meta@

#!/usr/bin/env fish

# 012-DEBUG-8.fish
# GLIMMER Pattern: Hot Pink (#FF69B4) and Cyan for STARWEAVE debugging

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-8) - WASM .link_args for Zig 0.14.1 (GLIMMER/STARWEAVE)"
set_color normal

function backup_buildzig
    set_color cyan
    echo "🔹 Backing up build.zig..."
    set_color normal
    cp build.zig build.zig.012-debug8-backup
end

function try_link_args_field
    set_color FF69B4
    echo "💡 Trying '.link_args' field in maya_wasm addExecutable struct..."
    set_color normal
    awk '
    /maya_wasm = b.addExecutable\(\.\{/ {
        print $0
        print "        .link_args = &[_][]const u8{\"--no-entry\"}, // [GLIMMER PATCH]"
        next
    }
    {print $0}
    ' build.zig.012-debug8-backup > build.zig
end

function clean_and_build
    set_color cyan
    echo "💫 Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
    set_color FF69B4
    echo "🚀 Rebuilding with .link_args patch (GLIMMER/STARWEAVE)..."
    set_color normal
    zig build
end

function show_maya_wasm_block
    set_color cyan
    echo "🔍 If .link_args fails, displaying your maya_wasm block (lines 10 before and after assignment)..."
    set_color normal
    awk '
    /maya_wasm = b.addExecutable/ {found=1; start=NR-10; end=NR+10}
    (NR >= start && NR <= end) && found {print NR ": " $0}
    ' build.zig
end

backup_buildzig
try_link_args_field
clean_and_build

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Build succeeded with .link_args in addExecutable! STARWEAVE/GLIMMER brilliance shines."
    exit 0
else
    set_color red
    echo "❌ .link_args patch failed."
    set_color normal
    show_maya_wasm_block
    echo "Please copy the displayed maya_wasm block here, so we can weave the next patch with GLIMMER precision."
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
