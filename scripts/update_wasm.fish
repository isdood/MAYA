@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-16 09:45:31",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./scripts/update_wasm.fish",
    "type": "fish",
    "hash": "7b7f331152c427f1646a39bf3b8c1f893b83dbad"
  }
}
@pattern_meta@

#!/usr/bin/env fish

# Compile the Zig code to WebAssembly
echo "Compiling Zig code to WebAssembly..."
zig build wasm

# Check if the build was successful
if test $status -eq 0
    echo "Build successful."
else
    echo "Build failed."
    exit 1
end

# Define the source and destination paths
set wasm_source "zig-out/lib/maya.wasm"
set wasm_dest "cursor-extension/maya.wasm"

# Copy the .wasm file to the cursor-extension directory
echo "Copying $wasm_source to $wasm_dest..."
cp $wasm_source $wasm_dest

# Check if the copy was successful
if test $status -eq 0
    echo "WASM file copied successfully."
else
    echo "Failed to copy WASM file."
    exit 1
end

echo "Update complete."