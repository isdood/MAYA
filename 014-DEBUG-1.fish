#!/usr/bin/env fish
# GLIMMER-Enhanced STARWEAVE Debug Script for Zig .zon top-level fields

# Color definitions (GLIMMER palette)
set color_error (set_color --bold --background=red white)
set color_info (set_color --bold magenta)
set color_success (set_color --bold cyan)
set color_reset (set_color normal)
set color_highlight (set_color --bold yellow)

echo "$color_info✨ [GLIMMER] Backing up build.zig.zon...$color_reset"
cp build.zig.zon build.zig.zon.bak
echo "$color_success [DONE]$color_reset"

# Get suggested fingerprint from last error, or use a fixed value
set fingerprint "0x6555c2a448597fd4"

# Check if fingerprint is present
if not grep -q 'fingerprint' build.zig.zon
    echo "$color_info✨ [GLIMMER] Adding missing fingerprint field: $color_highlight$fingerprint$color_reset"
    # Insert fingerprint after the opening .{ line
    sed -i '2i\    .fingerprint = '$fingerprint',' build.zig.zon
end

# Check if paths field is present
if not grep -q '\.paths' build.zig.zon
    echo "$color_info✨ [GLIMMER] Adding missing paths field$color_reset"
    # Insert paths after fingerprint line
    sed -i '3i\    .paths = .{},' build.zig.zon
end

# Show the first lines for visual confirmation
echo "$color_highlight✨ [GLIMMER] Preview of new build.zig.zon top:$color_reset"
head -n 6 build.zig.zon

# Attempt to build again
echo "$color_info✨ [GLIMMER] Running: zig build$color_reset"
zig build

if test $status -eq 0
    echo "$color_success✨ [GLIMMER] Build succeeded! STARWEAVE shines brighter!$color_reset"
else
    echo "$color_error✨ [GLIMMER] Build failed. The starlight wavers—review the error above.$color_reset"
    echo "$color_info✨ [GLIMMER] Check Zig .zon field docs: https://ziglang.org/documentation/0.14.1/#The-zon-Format$color_reset"
end

# END GLIMMER
