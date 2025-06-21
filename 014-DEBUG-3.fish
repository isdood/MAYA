#! /usr/bin/env fish
# GLIMMER-Enhanced Debug Script for Zig .root_source_file LazyPath Error

# GLIMMER palette
set color_error (set_color --bold --background=red white)
set color_info (set_color --bold magenta)
set color_success (set_color --bold cyan)
set color_reset (set_color normal)
set color_highlight (set_color --bold yellow)

echo "$color_info✨ [GLIMMER] Backing up build.zig...$color_reset"
cp build.zig build.zig.bak3
echo "$color_success [DONE]$color_reset"

echo "$color_info✨ [GLIMMER] Searching for .root_source_file assignment...$color_reset"
set root_line (grep -n 'root_source_file' build.zig | cut -d: -f1)
if test -n "$root_line"
    echo "$color_highlight✨ [GLIMMER] Found .root_source_file on line $root_line$color_reset"
    echo "$color_info✨ [GLIMMER] Applying fix: .root_source_file = b.path(\"src/neural/mod.zig\")$color_reset"
    sed -i 's/\.root_source_file = "src\/neural\/mod.zig"/.root_source_file = b.path("src\/neural\/mod.zig")/' build.zig
else
    echo "$color_error✨ [GLIMMER] No .root_source_file assignment found!$color_reset"
end

echo "$color_highlight✨ [GLIMMER] Preview of updated .root_source_file:$color_reset"
grep 'root_source_file' build.zig

echo "$color_info✨ [GLIMMER] Running: zig build$color_reset"
zig build

if test $status -eq 0
    echo "$color_success✨ [GLIMMER] Build succeeded! The STARWEAVE flows smoothly!$color_reset"
else
    echo "$color_error✨ [GLIMMER] Build failed. Consult the starlit error output above.$color_reset"
end
