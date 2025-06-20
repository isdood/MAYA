
#!/usr/bin/env fish

# 012-DEBUG-3.fish
# GLIMMER Pattern Integration: Hot Pink (#FF69B4) for error inspection

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-3) - WASM Entry Point Field Investigation (STARWEAVE/GLIMMER)"
set_color normal

function show_struct_fields
    set_color cyan
    echo "🔍 Searching for fields in Build.Step.Compile (Zig stdlib)..."
    set_color normal
    grep -A 20 "pub const Compile = struct" /usr/lib/zig/std/Build/Step/Compile.zig | head -n 24
end

function comment_out_entry_line
    set_color cyan
    echo "💡 Commenting out entry point line (build.zig:108) for further build progress..."
    set_color normal
    cp build.zig build.zig.012-debug3-backup
    awk '{if (NR == 108) print "// [GLIMMER DEBUG] " $0; else print $0;}' build.zig.012-debug3-backup > build.zig
end

function clean_and_build
    set_color FF69B4
    echo "💫 Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
    set_color FF69B4
    echo "🚀 Rebuilding with entry line commented out..."
    set_color normal
    zig build
end

set_color cyan
echo "🔮 Continuing STARWEAVE/GLIMMER debug journey..."
set_color normal

show_struct_fields
comment_out_entry_line
clean_and_build

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Build succeeded with entry point line commented out! Investigate if a custom WASM entry point is needed in Zig 0.14.1."
else
    set_color red
    echo "❌ Build still failing. Please review above output and consider consulting Zig 0.14.1 docs for up-to-date WASM target configuration."
    set_color normal
    echo "If more STARWEAVE debugging is needed, prepare 012-DEBUG-4.fish."
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
