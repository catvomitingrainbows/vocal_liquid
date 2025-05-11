#!/bin/bash
set -e

echo "=== VocalLiquid Background App Build Script ==="
echo "This script will build the background-only version of VocalLiquid"

# First, clean everything
echo "Step 1: Cleaning build products..."
rm -rf build/
xcodebuild clean -project VocalLiquid.xcodeproj

# Run the framework fix script
echo "Running framework fix script..."
./fix_framework.sh

# Ensure resources are prepared
echo "Step 2: Preparing resources..."
./build.sh

# Build with minimal signing requirements
echo "Step 3: Building background app..."
# Kill any running instances first
pkill -f VocalLiquid 2>/dev/null || true

# Build the app with proper entitlements
xcodebuild -project VocalLiquid.xcodeproj -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_HARDENED_RUNTIME=YES \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  CODE_SIGN_ENTITLEMENTS="VocalLiquid.entitlements" \
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
echo "Step 5: Launching background app..."
open build/Debug/VocalLiquid.app

echo 
echo "VocalLiquid is now running as a background application!"
echo "Use Command-Shift-R to start/stop recording."
echo "Notifications will appear when recording starts, stops, and when transcription is complete."
echo "Check the notification center for a confirmation message."
echo
echo "If you want to quit the app, run: pkill -f VocalLiquid"
echo
echo "To see debug output, run:"
echo "  /Users/almonds/repo/claude/vocal_liquid/build/Debug/VocalLiquid.app/Contents/MacOS/VocalLiquid"