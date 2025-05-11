#!/bin/bash
set -e

# Build script for VocalLiquid

# Create necessary directories
mkdir -p VocalLiquid/Resources

# Copy model file to Resources directory
cp references/Cava/Cava/ggml-base.en.bin VocalLiquid/Resources/

# Copy framework if it's not already in the project
if [ ! -d "VocalLiquid/whisper.xcframework" ]; then
  cp -R references/whisper.xcframework VocalLiquid/
fi

# Fix framework structure - ensure proper embedding for the macOS framework
echo "Ensuring proper framework structure..."
FRAMEWORK_PATH="VocalLiquid/whisper.xcframework/macos-arm64_x86_64/whisper.framework"

# Make sure Versions directory is properly set up
if [ -d "$FRAMEWORK_PATH/Versions/A" ]; then
  # Always recreate symlinks to ensure they are correct
  echo "Recreating framework symlinks..."

  # Remove existing symlinks
  rm -f "$FRAMEWORK_PATH/Versions/Current"
  rm -f "$FRAMEWORK_PATH/whisper"
  rm -f "$FRAMEWORK_PATH/Headers"

  # Create symlinks
  ln -sf A "$FRAMEWORK_PATH/Versions/Current"
  ln -sf Versions/Current/whisper "$FRAMEWORK_PATH/whisper"
  ln -sf Versions/Current/Headers "$FRAMEWORK_PATH/Headers"

  echo "Framework symlinks created successfully"

  # Verify frameworks
  echo "Verifying framework structure:"
  ls -la "$FRAMEWORK_PATH/Versions/"
  ls -la "$FRAMEWORK_PATH/"
fi

echo "Resources prepared successfully"
echo "Now open VocalLiquid.xcodeproj in Xcode and build the project"