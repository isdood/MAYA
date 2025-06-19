#!/usr/bin/env fish

# 012-DEBUG-6.fish
# GLIMMER Pattern: Hot Pink (#FF69B4) and Cyan for STARWEAVE debugging

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-6) - WASM Linker Args for Zig 0.14.1 (GLIMMER/STARWEAVE)"
set_color normal

function backup_buildzig
    set_color cyan
    echo "🔹 Backing up build.zig..."
    set_color normal
    cp build.zig build.zig.012-debug6-backup
end

function try_linker_args_field
    set_color FF69B4
    echo "💡 Trying '.linker_args' field in maya_wasm addExecutable struct..."
    set_color normal
    cp build.zig.012-debug6-backup build.zig
    awk '
    /maya_wasm = b.addExecutable\(\.\{/ {
        print $0
        print "        .linker_args = &[_][]const u8{\"--no-entry\"}, // [GLIMMER PATCH]"
        next
    }
    {print $0}
    ' build.zig.012-debug6-backup > build.zig
end

function clean_and_build
    set_color cyan
    echo "💫 Cleaning build artifacts..."
    set_color normal
    rm -rf zig-cache zig-out
    set_color FF69B4
    echo "🚀 Rebuilding with .linker_args patch (GLIMMER/STARWEAVE)..."
    set_color normal
    zig build
end

function try_addArgs_call
    set_color cyan
    echo "💡 If .linker_args fails, trying maya_wasm.addArgs after creation..."
    set_color normal
    cp build.zig.012-debug6-backup build.zig
    awk '
    /maya_wasm = b.addExecutable\(\.\{/ {found=1}
    found && /\};/ && added != 1 {
        print $0
        print "maya_wasm.addArgs(&[_][]const u8{\"--no-entry\"}); // [GLIMMER PATCH]"
        added=1
        next
    }
    {print $0}
    ' build.zig.012-debug6-backup > build.zig
end

backup_buildzig
try_linker_args_field
clean_and_build

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Build succeeded with .linker_args in addExecutable! GLIMMER brilliance shines."
    exit 0
else
    set_color red
    echo "⚠️ .linker_args patch failed, trying addArgs after maya_wasm creation..."
    set_color normal
    try_addArgs_call
    clean_and_build
    set build_status2 $status

    if test $build_status2 -eq 0
        set_color green
        echo "🌈 Build succeeded with maya_wasm.addArgs! GLIMMER brilliance shines."
    else
        set_color red
        echo "❌ Both approaches failed. Please consult the Zig 0.14.1 build API for the correct way to add linker args for WASM, or escalate to 012-DEBUG-7.fish."
    end
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
