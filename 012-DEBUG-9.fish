@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-19 11:26:01",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./012-DEBUG-9.fish",
    "type": "fish",
    "hash": "3e8cb2a77df9af000b8370ef1b088f11b35b634c"
  }
}
@pattern_meta@

#!/usr/bin/env fish

set_color FF69B4
echo "🌟 MAYA Debug Script (012-DEBUG-10) - Add dummy _start for Zig 0.14.1 (GLIMMER/STARWEAVE)"
set_color normal

set_color cyan
echo "🔹 Zig 0.14.1 does not support '--no-entry'."
echo "🔹 Patching src/wasm.zig with a dummy _start function to satisfy the linker..."
set_color normal

if not grep -q 'export fn _start()' src/wasm.zig
    echo -e 'export fn _start() void {}\n' | cat - src/wasm.zig > src/wasm.zig.glimmer && mv src/wasm.zig.glimmer src/wasm.zig
    set_color green
    echo "🌈 Dummy _start added in src/wasm.zig!"
else
    set_color yellow
    echo "🌟 Dummy _start already present in src/wasm.zig."
end

set_color cyan
echo "💫 Attempting standard build (GLIMMER/STARWEAVE)..."
set_color normal
zig build

set build_status $status

if test $build_status -eq 0
    set_color green
    echo "🌈 Build succeeded! Your WASM is GLIMMER/STARWEAVE valid for Zig 0.14.1."
else
    set_color red
    echo "❌ Build still failing. Check the error above, or upgrade to Zig >= 0.15.0 for native '--no-entry' support."
end

set_color normal
echo "✨ Debug script complete (GLIMMER/STARWEAVE) ✨"
