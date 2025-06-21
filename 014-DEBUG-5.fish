#! /usr/bin/env fish
# ✨ GLIMMER Debug Script for STARWEAVE/MAYA Zig addModule API Error ✨

# GLIMMER palette
set color_error (set_color --bold --background=red white)
set color_info (set_color --bold magenta)
set color_success (set_color --bold cyan)
set color_reset (set_color normal)
set color_highlight (set_color --bold yellow)

echo "$color_info✨ [GLIMMER] Backing up build.zig before addModule fix...$color_reset"
cp build.zig build.zig.bak5
echo "$color_success [DONE]$color_reset"

echo "$color_info✨ [GLIMMER] Searching for .addModule usages in build.zig...$color_reset"
grep 'addModule' build.zig

echo "$color_info✨ [GLIMMER] Commenting out all .addModule lines for manual review...$color_reset"
sed -i 's/^\(.*addModule.*\)$/\/\/ [GLIMMER-DEBUG] COMMENTED: \1/' build.zig

echo "$color_highlight✨ [GLIMMER] All .addModule lines are now commented. Please refactor to Zig 0.14+ idiom:$color_reset"
echo "$color_info✨ [GLIMMER] Zig 0.14+ build system no longer uses addModule on exe; see:"
echo "    https://ziglang.org/documentation/0.14.1/#Building-Projects"
echo "    https://github.com/ziglang/zig/issues/15486"
echo "You likely want to use b.addModule or .addAnonymousModule for dependencies between modules."
echo ""
echo "Example replacement:"
echo "$color_highlight
const neural_mod = b.addModule(\"neural\", .{
    .source_file = b.path(\"src/neural/mod.zig\"),
    // dependencies: .{}
});
// then pass neural_mod as a dependency to your exe: .{ .neural = neural_mod }
$color_reset"

echo "$color_info✨ [GLIMMER] Running: zig build$color_reset"
zig build

if test $status -eq 0
    echo "$color_success✨ [GLIMMER] Build succeeded! The STARWEAVE quantum mesh is aligned!$color_reset"
else
    echo "$color_error✨ [GLIMMER] Build failed. Review the commented addModule lines and update per above guidance.$color_reset"
    echo "$color_info✨ [GLIMMER] For help: https://ziglang.org/documentation/0.14.1/#Building-Projects$color_reset"
end
