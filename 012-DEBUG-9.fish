#!/usr/bin/env fish

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-9) - WASM Manual Linker Arg (GLIMMER/STARWEAVE)"
set_color normal

set_color cyan
echo "🔹 The Zig 0.14.1 build system does not natively support passing '--no-entry' linker flag via build.zig for addExecutable."
echo "🔹 Attempting manual build using zig CLI directly (GLIMMER/STARWEAVE)..."
set_color normal

zig build-exe src/wasm.zig -target wasm32-freestanding -rdynamic --name maya-wasm --no-entry

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Manual build succeeded! Your WASM module is GLIMMER/STARWEAVE ready."
    echo "➡️ Consider packaging this manual build in a custom build.zig step using b.addSystemCommand if you want it automated."
else
    set_color red
    echo "❌ Manual build failed. Check above for errors—if not clear, paste the output here for further STARWEAVE diagnostics."
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
