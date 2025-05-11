#!/bin/bash
set -e

echo "=== VocalLiquid Build and Run Script ==="
echo "This script will build, fix, and run the VocalLiquid app without code signing issues"

# Step 1: Prepare resources using the build script
echo
echo "Step 1: Preparing resources..."
./build.sh

# Step 2: Build the app using xcodebuild without code signing
echo
echo "Step 2: Building the app..."
# Kill any running instances first
pkill -f VocalLiquid 2>/dev/null || true

# Build the app without code signing
xcodebuild -project VocalLiquid.xcodeproj -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO ENABLE_HARDENED_RUNTIME=NO

# Step 3: Fix the frameworks and code signing
echo
echo "Step 3: Fixing frameworks and code signing..."
./fix_app.sh build/Debug/VocalLiquid.app

# Step 4: Launch the app
echo
echo "Step 4: Launching VocalLiquid..."
open build/Debug/VocalLiquid.app

echo
echo "The app should now be running with an icon in your menu bar!"
echo "If you don't see it, check Console.app for any error messages."
echo "Use Command-Shift-R to start/stop recording."