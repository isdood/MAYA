#!/usr/bin/env fish

# GLIMMER-Enhanced MAYA Debug Script for Zig build.zig.zon enum error

# GLIMMER color codes for Fish (using set_color directly)
set color_error (set_color --bold --background=red white)
set color_info (set_color --bold magenta)
set color_success (set_color --bold cyan)
set color_reset (set_color normal)

# GLIMMER: Backup step
echo -n "$color_info✨ [GLIMMER] Backing up build.zig.zon...$color_reset"
cp build.zig.zon build.zig.zon.bak
echo "$color_success [DONE]$color_reset"

# GLIMMER: Show current problematic lines
echo "$color_info✨ [GLIMMER] Showing lines containing .name in build.zig.zon:$color_reset"
grep -n '\.name' build.zig.zon

# GLIMMER: Apply enum literal fix (.name = .maya,)
echo "$color_info✨ [GLIMMER] Applying enum literal fix: .name = .maya,$color_reset"
# Replace both .name = "maya" and .name = maya with .name = .maya
sed -i 's/\.name = "maya"/.name = .maya/' build.zig.zon
sed -i 's/\.name = maya/\.name = .maya/' build.zig.zon

# GLIMMER: Show fixed line
echo "$color_info✨ [GLIMMER] Updated .name line:$color_reset"
grep '\.name' build.zig.zon

# GLIMMER: Try building again
echo "$color_info✨ [GLIMMER] Running: zig build$color_reset"
zig build

# GLIMMER: Show build result
if test $status -eq 0
    echo "$color_success✨ [GLIMMER] Build succeeded!$color_reset"
else
    echo "$color_error✨ [GLIMMER] Build failed. Please review the error output above.$color_reset"
    echo "$color_info✨ [GLIMMER] If the error persists, check Zig's .zon enum syntax: https://ziglang.org/documentation/0.14.1/#The-zon-Format$color_reset"
end
