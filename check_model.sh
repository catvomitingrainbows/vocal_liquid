#!/bin/bash
set -e

echo "=== Checking Whisper Model Files ==="

# Find the location of the built app
APP_PATH="$(find /Users/almonds/repo/claude/vocal_liquid/build -name "*.app" | head -n 1)"

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find any built app in the build directory!"
    exit 1
fi

echo "Found app at: $APP_PATH"

# Check Resources directory
RESOURCES_PATH="$APP_PATH/Contents/Resources"
echo "Checking resources at: $RESOURCES_PATH"

echo "Files in resources directory:"
ls -la "$RESOURCES_PATH"

# Look for the model file
if [ -f "$RESOURCES_PATH/ggml-base.en.bin" ]; then
    echo "SUCCESS: Model file found in resources directory!"
    echo "Model file size: $(du -h "$RESOURCES_PATH/ggml-base.en.bin" | cut -f1)"
else
    echo "ERROR: Model file NOT FOUND in resources directory!"
    echo "Checking alternative locations..."
fi

# Look for model file in other locations
echo "Checking source location..."
SOURCE_MODEL="/Users/almonds/repo/claude/vocal_liquid/VocalLiquid/ggml-base.en.bin"
if [ -f "$SOURCE_MODEL" ]; then
    echo "Model exists in source directory: $SOURCE_MODEL"
    echo "File size: $(du -h "$SOURCE_MODEL" | cut -f1)"
    
    # Copy the model file to the Resources directory
    echo "Copying model to resources directory..."
    cp "$SOURCE_MODEL" "$RESOURCES_PATH/"
    echo "Model copied. Checking resources again:"
    ls -la "$RESOURCES_PATH/ggml-base.en.bin" || echo "Copy seems to have failed."
else
    echo "Model not found in source directory either."
fi

# Check Frameworks
FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"
echo "Checking frameworks at: $FRAMEWORKS_PATH"
ls -la "$FRAMEWORKS_PATH" || echo "No frameworks directory or not accessible"

echo "=== Check Complete ==="