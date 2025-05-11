#!/bin/bash
set -e

echo "=== VocalLiquid Clean Rebuild Script ==="
echo "This script will completely rebuild the app with minimal signing requirements"

# First, clean everything
echo "Step 1: Cleaning build products..."
rm -rf build/
xcodebuild clean -project VocalLiquid.xcodeproj

# Ensure resources are prepared
echo "Step 2: Preparing resources..."
./build.sh

# Build with minimal signing requirements
echo "Step 3: Building with minimal signing..."
xcodebuild -project VocalLiquid.xcodeproj -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_HARDENED_RUNTIME=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp=none"

# Fix any remaining issues
echo "Step 4: Applying final fixes..."
FRAMEWORKS_DIR="build/Debug/VocalLiquid.app/Contents/Frameworks"
mkdir -p "$FRAMEWORKS_DIR"

# Copy framework manually
echo "Copying whisper framework to app bundle..."
cp -R VocalLiquid/whisper.xcframework/macos-arm64_x86_64/whisper.framework "$FRAMEWORKS_DIR/"

# Ensure permissions are correct
echo "Setting permissions..."
chmod -R +x build/Debug/VocalLiquid.app/Contents/MacOS/
chmod -R +x "$FRAMEWORKS_DIR/whisper.framework/"

# Launch the app
echo "Step 5: Launching app..."
open build/Debug/VocalLiquid.app

echo 
echo "The app should now be running with an icon in your menu bar."
echo "If you continue to experience issues, try running these commands:"
echo "  pkill -f VocalLiquid"
echo "  /Users/almonds/repo/claude/vocal_liquid/build/Debug/VocalLiquid.app/Contents/MacOS/VocalLiquid"
echo "This will show any errors directly in the terminal."