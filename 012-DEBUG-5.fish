
#!/usr/bin/env fish

# 012-DEBUG-5.fish
# GLIMMER Pattern: Hot Pink (#FF69B4) and Cyan for STARWEAVE debugging

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-5) - WASM LinkerArg Placement Fix (GLIMMER/STARWEAVE)"
set_color normal

function backup_buildzig
    set_color cyan
    echo "🔹 Backing up build.zig..."
    set_color normal
    cp build.zig build.zig.012-debug5-backup
end

function patch_linker_flag
    set_color FF69B4
    echo "💡 Moving '--no-entry' linker flag after maya_wasm creation..."
    set_color normal
    # Find the maya_wasm assignment and insert the patch after its closing semicolon
    set temp_file build.zig.012-debug5-tmp
    set patched 0
    set maya_line 0
    set insert_line 0
    set i 0
    # Find maya_wasm assignment and first following semicolon on its own line
    awk '
    /maya_wasm =/ {in_block=1}
    in_block && /;/ {in_block=0; print $0; print "maya_wasm.addLinkerArg(\"--no-entry\"); // [GLIMMER PATCH]"; next}
    {print $0}
    ' build.zig > $temp_file
    mv $temp_file build.zig
end

function clean_and_build
    set_color cyan
    echo "💫 Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
    set_color FF69B4
    echo "🚀 Rebuilding with correct '--no-entry' placement (GLIMMER/STARWEAVE)..."
    set_color normal
    zig build
end

backup_buildzig
patch_linker_flag
clean_and_build

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Build succeeded! STARWEAVE and GLIMMER are in radiant harmony."
else
    set_color red
    echo "❌ Build still failing. Review where in build.zig the patch lands, and consider a manual review of maya_wasm build step."
    echo "Next step: deepen diagnostics in 012-DEBUG-6.fish."
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
