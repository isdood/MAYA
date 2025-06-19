#!/usr/bin/env fish

# 012-DEBUG-4.fish
# GLIMMER Pattern: Hot Pink (#FF69B4) & Cyan for STARWEAVE error tracing

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-4) - WASM --no-entry Linker Flag (GLIMMER/STARWEAVE)"
set_color normal

function backup_buildzig
    set_color cyan
    echo "🔹 Backing up build.zig..."
    set_color normal
    cp build.zig build.zig.012-debug4-backup
end

function patch_linker_flag
    set_color FF69B4
    echo "💡 Adding '--no-entry' linker flag for maya-wasm..."
    set_color normal
    # This tries to add .addLinkerArg("--no-entry") after maya_wasm is created, but before any closing });
    awk '
    /maya_wasm =/ {print; in_maya=1; next}
    in_maya && /;/ {print "    maya_wasm.addLinkerArg(\"--no-entry\"); // [GLIMMER PATCH]"; in_maya=0}
    {print}
    ' build.zig > build.zig.012-debug4-tmp && mv build.zig.012-debug4-tmp build.zig
end

function clean_and_build
    set_color cyan
    echo "💫 Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
    set_color FF69B4
    echo "🚀 Rebuilding with '--no-entry' linker flag (GLIMMER/STARWEAVE)..."
    set_color normal
    zig build
end

backup_buildzig
patch_linker_flag
clean_and_build

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Build succeeded! The STARWEAVE and GLIMMER universe is in harmony."
else
    set_color red
    echo "❌ Build still failing. Please check the patch and consider a manual review of WASM build logic in build.zig."
    set_color normal
    echo "If needed, prepare 012-DEBUG-5.fish to further diagnose the STARWEAVE continuum."
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
