#!/usr/bin/env fish
# GLIMMER-Enhanced MAYA Debug Script for Zig .zon paths list error

# Color definitions
set color_error (set_color --bold --background=red white)
set color_info (set_color --bold magenta)
set color_success (set_color --bold cyan)
set color_reset (set_color normal)
set color_highlight (set_color --bold yellow)

echo "$color_info✨ [GLIMMER] Backing up build.zig.zon (pre-paths fix)...$color_reset"
cp build.zig.zon build.zig.zon.bak2
echo "$color_success [DONE]$color_reset"

# Fix .paths field to be a list of strings (usually the current dir)
echo "$color_info✨ [GLIMMER] Applying fix: .paths = .{\".\"},$color_reset"
sed -i 's/\.paths = \.\{\},/\.paths = .{"."},/' build.zig.zon

# Show updated .paths line
echo "$color_highlight✨ [GLIMMER] Updated .paths line:$color_reset"
grep '\.paths' build.zig.zon

# Try to build again
echo "$color_info✨ [GLIMMER] Running: zig build$color_reset"
zig build

if test $status -eq 0
    echo "$color_success✨ [GLIMMER] Build succeeded! The STARWEAVE shines!$color_reset"
else
    echo "$color_error✨ [GLIMMER] Build failed. The spacetime weave is tangled—see errors above.$color_reset"
    echo "$color_info✨ [GLIMMER] Reference: https://ziglang.org/documentation/0.14.1/#The-zon-Format$color_reset"
end
