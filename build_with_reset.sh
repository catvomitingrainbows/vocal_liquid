#!/bin/bash
set -e

echo "=== VocalLiquid Build With Reset ==="

# First, kill any running instances and reset permissions
echo "Killing any existing instances and resetting settings..."
pkill -f VocalLiquid 2>/dev/null || true

# Reset specific UserDefaults keys related to permissions
echo "Removing UserDefaults for permissions..."
defaults delete com.example.VocalLiquid 2>/dev/null || true

# Remove the existing PermissionTestManager file if it exists (which may cause conflicts)
echo "Removing conflicts..."
rm -f /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/PermissionTestManager.swift 2>/dev/null || true

# Run the fix framework script
echo "Fixing framework structure..."
./fix_framework.sh

# Build the app
echo "Building the app..."
./build_background.sh

# Launch directly with our debug logger
echo "App built successfully. Now you can run:"
echo "  ./debug_logging.sh"
echo "to launch the app with debug output."