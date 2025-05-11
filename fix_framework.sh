#!/bin/bash
set -e

echo "=== Fixing Framework Structure ==="

# Define framework path
FRAMEWORK_PATH="VocalLiquid/whisper.xcframework/macos-arm64_x86_64/whisper.framework"

echo "Checking framework at: $FRAMEWORK_PATH"

# Ensure Versions/A exists
if [ ! -d "$FRAMEWORK_PATH/Versions/A" ]; then
  echo "ERROR: Versions/A directory not found. Cannot fix framework structure."
  exit 1
fi

# Check if directories exist that should be symlinks, and remove them
for item in "Headers" "Modules" "Resources" "whisper"; do
  if [ -d "$FRAMEWORK_PATH/$item" ] && [ ! -L "$FRAMEWORK_PATH/$item" ]; then
    echo "Removing $item directory (it should be a symlink)..."
    rm -rf "$FRAMEWORK_PATH/$item"
  fi
done

# Check if Current is a directory, not a symlink
if [ -d "$FRAMEWORK_PATH/Versions/Current" ] && [ ! -L "$FRAMEWORK_PATH/Versions/Current" ]; then
  echo "Removing Current directory (it should be a symlink)..."
  rm -rf "$FRAMEWORK_PATH/Versions/Current"
fi

# Create proper symlinks
echo "Creating correct symlinks..."
ln -sf A "$FRAMEWORK_PATH/Versions/Current"
ln -sf Versions/Current/Headers "$FRAMEWORK_PATH/Headers"
ln -sf Versions/Current/whisper "$FRAMEWORK_PATH/whisper"

# Create the Modules symlink if the directory exists in A
if [ -d "$FRAMEWORK_PATH/Versions/A/Modules" ]; then
  ln -sf Versions/Current/Modules "$FRAMEWORK_PATH/Modules"
fi

# Create the Resources symlink if the directory exists in A
if [ -d "$FRAMEWORK_PATH/Versions/A/Resources" ]; then
  ln -sf Versions/Current/Resources "$FRAMEWORK_PATH/Resources"
fi

echo "Framework symlinks fixed!"
echo "Checking final structure:"
ls -la "$FRAMEWORK_PATH"
ls -la "$FRAMEWORK_PATH/Versions"

echo "Fix complete. Now run build_background.sh to build the app."