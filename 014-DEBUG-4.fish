#! /usr/bin/env fish
# ✨ GLIMMER Debug Script for STARWEAVE/MAYA Zig .root_source_file Batch Fix ✨

# GLIMMER palette
set color_error (set_color --bold --background=red white)
set color_info (set_color --bold magenta)
set color_success (set_color --bold cyan)
set color_reset (set_color normal)
set color_highlight (set_color --bold yellow)

echo "$color_info✨ [GLIMMER] Backing up build.zig (prior to batch path fix)...$color_reset"
cp build.zig build.zig.bak4
echo "$color_success [DONE]$color_reset"

echo "$color_info✨ [GLIMMER] Searching for all .root_source_file assignments in build.zig...$color_reset"
grep 'root_source_file' build.zig

# Batch fix: Replace ALL .root_source_file = "anything.zig" with .root_source_file = b.path("anything.zig")
echo "$color_info✨ [GLIMMER] Applying batch fix for .root_source_file assignments...$color_reset"
sed -i -E 's/\.root_source_file = "([^"]+)"/.root_source_file = b.path("\1")/g' build.zig

echo "$color_highlight✨ [GLIMMER] Preview of all .root_source_file after fix:$color_reset"
grep 'root_source_file' build.zig

echo "$color_info✨ [GLIMMER] Running: zig build$color_reset"
zig build

if test $status -eq 0
    echo "$color_success✨ [GLIMMER] Build succeeded! The STARWEAVE is radiant!$color_reset"
else
    echo "$color_error✨ [GLIMMER] Build failed. Consult the cosmic log above and keep weaving!$color_reset"
end
