#!/bin/bash
set -e

# Kill any existing instances
echo "Killing any existing VocalLiquid instances..."
pkill -f VocalLiquid 2>/dev/null || true

# Run the app with logging directly to console
echo "Running VocalLiquid with debug logging..."
/Users/almonds/repo/claude/vocal_liquid/build/Debug/VocalLiquid.app/Contents/MacOS/VocalLiquid