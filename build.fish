@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-17 12:27:28",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./build.fish",
    "type": "fish",
    "hash": "e51d049eb5eff80f078a8f529162ab25bc13802a"
  }
}
@pattern_meta@

#!/usr/bin/env fish
# Wrapper script for build-windsurf.fish
# Usage: ./build.fish [options]

# Get the directory of this script
set -l script_dir (dirname (status --current-filename))

# Execute the build script
fish $script_dir/scripts/build-windsurf.fish $argv
