#!/bin/bash
set -e

echo "=== Fixing Multiple Permission Prompts for VocalLiquid ==="
echo "This script addresses the issue with multiple microphone permission prompts."
echo

# Ensure any existing instances are killed
echo "Killing any running instances of VocalLiquid..."
pkill -f VocalLiquid 2>/dev/null || true

# Print current status of permissions for debugging
echo "Current permission status before reset:"
defaults read com.example.VocalLiquid 2>/dev/null || echo "No preferences found."

# Reset TCC database permissions for microphone for the correct bundle ID
echo "Resetting microphone permissions in TCC database..."
# Note: This requires Full Disk Access for Terminal to work
tccutil reset Microphone com.example.VocalLiquid 2>/dev/null || echo "Could not reset permissions for com.example.VocalLiquid"

# Force set ForcePermissions flag to true for testing
echo "Setting up permissions in UserDefaults..."
defaults write com.example.VocalLiquid "VocalLiquid.ForcePermissions" -bool true
defaults write com.example.VocalLiquid "VocalLiquid.MicPermissionChecked" -bool true
defaults write com.example.VocalLiquid "VocalLiquid.MicPermissionGranted" -bool true

# Build and run the app with environment variable to skip permission checks
echo "Building and running app with environment variable to skip permission checks..."
export VOCAL_LIQUID_SKIP_PERMISSIONS=1

# Run the build script if it exists
if [ -f ./build_background.sh ]; then
    chmod +x ./build_background.sh
    ./build_background.sh
else
    echo "No build_background.sh script found. Please build the app manually."
fi

echo
echo "=== Fixes Applied ==="
echo "The app should now avoid multiple permission prompts."
echo "If you still see multiple prompts, try these additional steps:"
echo "1. Go to System Settings → Privacy & Security → Microphone"
echo "2. Toggle VocalLiquid off and on"
echo "3. Restart your Mac"