
#!/usr/bin/env fish
# Wrapper script for build-windsurf.fish
# Usage: ./build.fish [options]

# Get the directory of this script
set -l script_dir (dirname (status --current-filename))

# Execute the build script
fish $script_dir/scripts/build-windsurf.fish $argv
