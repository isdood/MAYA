
#!/usr/bin/env fish

# 012-DEBUG-2.fish
# GLIMMER Pattern Integration: Hot Pink (#FF69B4) for error detection
set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-2) - Zig WASM Pointer Debugging"
set_color normal

function print_line_context
    set_color cyan
    echo "🔎 Showing lines around build.zig:108"
    set_color normal
    awk 'NR>=105 && NR<=110 {print NR ": " $0}' build.zig
end

function try_patch_deref
    set_color cyan
    echo "✨ Trying pointer dereference patch (maya_wasm.*.setEntryPoint(null);)..."
    set_color normal
    cp build.zig build.zig.012-debug2-backup
    awk '{
        if (NR == 108 && $0 ~ /setEntryPoint/) {
            print "    maya_wasm.*.setEntryPoint(null); // [DEBUG PATCH by GLIMMER]";
        } else {
            print $0;
        }
    }' build.zig.012-debug2-backup > build.zig
end

function try_patch_assign
    set_color cyan
    echo "✨ If pointer deref fails, trying assignment (maya_wasm.setEntryPoint = null;)..."
    set_color normal
    cp build.zig.012-debug2-backup build.zig
    awk '{
        if (NR == 108 && $0 ~ /setEntryPoint/) {
            print "    maya_wasm.setEntryPoint = null; // [DEBUG PATCH by GLIMMER]";
        } else {
            print $0;
        }
    }' build.zig.012-debug2-backup > build.zig
end

function clean_and_build
    set_color FF69B4
    echo "💫 Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
    set_color FF69B4
    echo "🚀 Rebuilding with patched build.zig..."
    set_color normal
    zig build
end

# Main execution
set_color cyan
echo "🔮 Continuing MAYA build error resolution (STARWEAVE universe)..."
set_color normal

check_zig_version
print_line_context

# Try pointer dereference version first
try_patch_deref
clean_and_build
if test $status -eq 0
    set_color green
    echo "🌈 Build successful with pointer dereference patch! GLIMMER brilliance shines."
    exit 0
else
    set_color red
    echo "⚠️ Patch 1 failed. Trying alternate assignment syntax..."
    set_color normal
    try_patch_assign
    clean_and_build
    if test $status -eq 0
        set_color green
        echo "🌈 Build successful with alternate assignment patch! GLIMMER brilliance shines."
        exit 0
    else
        set_color red
        echo "❌ Build still failing. Please review build.zig:108 manually, check Zig API docs for your version, or escalate to 012-DEBUG-3.fish."
        set_color normal
    end
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
