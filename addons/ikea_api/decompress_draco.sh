#!/bin/bash
# Script to decompress Draco-compressed GLB files
# Requires: npm install -g @gltf-transform/cli

if [ $# -eq 0 ]; then
    echo "Usage: $0 <input.glb> [output.glb]"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.glb}_uncompressed.glb}"

if ! command -v gltf-transform &> /dev/null; then
    echo "Error: gltf-transform not found. Install with:"
    echo "  npm install -g @gltf-transform/cli"
    exit 1
fi

echo "Decompressing $INPUT to $OUTPUT..."
gltf-transform draco "$INPUT" "$OUTPUT" --decode

if [ $? -eq 0 ]; then
    echo "Success! Decompressed model saved to: $OUTPUT"
else
    echo "Error: Failed to decompress model"
    exit 1
fi
