
#!/usr/bin/env fish

# 012-DEBUG-7.fish
# GLIMMER Pattern: Hot Pink (#FF69B4) and Cyan for STARWEAVE debugging

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-7) - WASM addLinkArgs for Zig 0.14.1 (GLIMMER/STARWEAVE)"
set_color normal

function backup_buildzig
    set_color cyan
    echo "🔹 Backing up build.zig..."
    set_color normal
    cp build.zig build.zig.012-debug7-backup
end

function patch_addLinkArgs
    set_color FF69B4
    echo "💡 Inserting maya_wasm.addLinkArgs for '--no-entry'..."
    set_color normal
    # Insert after maya_wasm is created (after the first semicolon following maya_wasm = ...)
    awk '
    /maya_wasm = b.addExecutable\(\.\{/ {found=1}
    found && /;/ && added != 1 {
        print $0
        print "maya_wasm.addLinkArgs(&[_][]const u8{\"--no-entry\"}); // [GLIMMER PATCH]"
        added=1
        next
    }
    {print $0}
    ' build.zig.012-debug7-backup > build.zig
end

function clean_and_build
    set_color cyan
    echo "💫 Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
    set_color FF69B4
    echo "🚀 Rebuilding with addLinkArgs (GLIMMER/STARWEAVE)..."
    set_color normal
    zig build
end

backup_buildzig
patch_addLinkArgs
clean_and_build

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Build succeeded with addLinkArgs! GLIMMER starlight floods the STARWEAVE universe."
    exit 0
else
    set_color red
    echo "❌ Still failing. The Zig 0.14.1 build API may require additional adjustments—inspect build.zig and maya_wasm instantiation closely or escalate to 012-DEBUG-8.fish."
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
