#!/bin/bash
set -e

echo "=== VocalLiquid Permission Fix Implementation ==="
echo "This script will apply the optimized audio permission fixes"

# Kill any running instances first
echo "Stopping any running instances..."
pkill -f VocalLiquid 2>/dev/null || true

# Backup existing files
echo "Backing up existing files..."
cp -f VocalLiquid/Managers/AudioManager.swift VocalLiquid/Managers/AudioManager.swift.bak
cp -f VocalLiquid/VocalLiquidApp.swift VocalLiquid/VocalLiquidApp.swift.bak

# Apply the fixes
echo "Applying fixed AudioManager implementation..."
cp -f VocalLiquid/Managers/AudioManager.swift.fixed VocalLiquid/Managers/AudioManager.swift

echo "Applying fixed VocalLiquidApp implementation..."
cp -f VocalLiquid/VocalLiquidApp.swift.fixed VocalLiquid/VocalLiquidApp.swift

# Reset permissions to ensure clean testing
echo "Resetting permissions for testing..."
./reset_permissions.sh

# Build and run
echo "Building and running with fixes applied..."
./build_background.sh

echo ""
echo "Fixes applied successfully!"
echo "The key changes made were:"
echo "1. Synchronized mic permission requests to avoid multiple prompts"
echo "2. Fixed the audio session setup with proper categories"
echo "3. Improved audio tap handling to avoid permission prompts"
echo "4. Fixed toggle recording to properly track recording state"
echo "5. Added empty audio sample detection to avoid transcription errors"
echo ""
echo "Test by pressing Command-Shift-R to start and stop recording."
echo "You should only get ONE permission prompt on first run."
echo ""
echo "If you need to restore the original files, run:"
echo "cp VocalLiquid/Managers/AudioManager.swift.bak VocalLiquid/Managers/AudioManager.swift"
echo "cp VocalLiquid/VocalLiquidApp.swift.bak VocalLiquid/VocalLiquidApp.swift"