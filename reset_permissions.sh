#!/bin/bash
set -e

echo "=== Reset macOS Security Permissions for VocalLiquid ==="
echo "WARNING: This will reset all microphone and notification permissions."
echo "         You will need to grant them again when you restart the app."
echo

# Ensure any existing instances are killed
echo "Killing any running instances of VocalLiquid..."
pkill -f VocalLiquid 2>/dev/null || true

# Print current status of permissions for debugging
echo "Current permission status before reset:"
defaults read com.example.VocalLiquid 2>/dev/null || echo "No preferences found."

# Reset TCC database permissions for microphone
echo "Resetting microphone permissions in TCC database..."
# Note: This requires Full Disk Access for Terminal to work
tccutil reset Microphone com.example.VocalLiquid 2>/dev/null || tccutil reset Microphone || echo "Could not reset microphone permissions. You may need to grant Full Disk Access to Terminal."

# Clear any existing preferences
echo "Clearing VocalLiquid preferences..."
defaults delete com.example.VocalLiquid 2>/dev/null || echo "No preferences found to delete."

# Force set ForcePermissions flag to true for testing
echo "Setting up test mode with forced permissions..."
defaults write com.example.VocalLiquid "VocalLiquid.ForcePermissions" -bool true
defaults write com.example.VocalLiquid "VocalLiquid.MicPermissionChecked" -bool true
defaults write com.example.VocalLiquid "VocalLiquid.MicPermissionGranted" -bool true
defaults write com.example.VocalLiquid "VocalLiquid.NotificationPermissionChecked" -bool true
defaults write com.example.VocalLiquid "VocalLiquid.NotificationPermissionGranted" -bool true

# Verify the settings were applied
echo "Current permission status after reset and force:"
defaults read com.example.VocalLiquid 2>/dev/null || echo "No preferences found."

echo
echo "=== Permission Reset Complete ==="
echo "The next time you run VocalLiquid, it will use the forced permissions"
echo "to avoid showing multiple permission prompts."
echo
echo "To run the app with the fixed permissions, execute:"
echo "  ./build_background.sh"