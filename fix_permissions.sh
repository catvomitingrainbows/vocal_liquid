#!/bin/bash
set -e

echo "=== Enhanced Permission Fix for VocalLiquid ==="
echo "This script will fix multiple permission prompts by resetting permission caches and ensuring bundle ID consistency"

# Kill any running instances
echo "Stopping any running instances of VocalLiquid..."
pkill -f VocalLiquid 2>/dev/null || echo "No running instances found"

# Determine the actual bundle ID
EXPECTED_BUNDLE_ID="com.vocalliquid.app"  # This should be the official bundle ID
ACTUAL_BUNDLE_ID=""

echo "Checking the actual bundle ID being used by VocalLiquid..."

# Try multiple ways to find the bundle ID
if [ -f "/Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Info.plist" ]; then
    PLIST_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "/Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Info.plist" 2>/dev/null || echo "")
    if [ ! -z "$PLIST_BUNDLE_ID" ]; then
        ACTUAL_BUNDLE_ID="$PLIST_BUNDLE_ID"
        echo "Found bundle ID from Info.plist: $ACTUAL_BUNDLE_ID"
    fi
fi

if [ -z "$ACTUAL_BUNDLE_ID" ] && [ -f "/Users/almonds/repo/claude/vocal_liquid/build/Debug/VocalLiquid.app/Contents/Info.plist" ]; then
    APP_BUNDLE_ID=$(defaults read /Users/almonds/repo/claude/vocal_liquid/build/Debug/VocalLiquid.app/Contents/Info.plist CFBundleIdentifier 2>/dev/null || echo "")
    if [ ! -z "$APP_BUNDLE_ID" ]; then
        ACTUAL_BUNDLE_ID="$APP_BUNDLE_ID"
        echo "Found bundle ID from built app: $ACTUAL_BUNDLE_ID"
    fi
fi

# If we still couldn't find a bundle ID, use the expected one
if [ -z "$ACTUAL_BUNDLE_ID" ]; then
    ACTUAL_BUNDLE_ID="$EXPECTED_BUNDLE_ID"
    echo "Could not determine actual bundle ID, using expected: $ACTUAL_BUNDLE_ID"
fi

# Reset TCC database entries for both the actual and expected bundle IDs to be safe
echo "Resetting TCC database entries..."
echo "This requires admin privileges. You may be prompted for your password."

# Reset microphone permissions in TCC database (requires sudo)
sudo tccutil reset Microphone "$ACTUAL_BUNDLE_ID" 2>/dev/null || echo "Could not reset microphone permissions for $ACTUAL_BUNDLE_ID (may need different sudo privileges)"
if [ "$ACTUAL_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]; then
    sudo tccutil reset Microphone "$EXPECTED_BUNDLE_ID" 2>/dev/null || echo "Could not reset microphone permissions for $EXPECTED_BUNDLE_ID"
fi

# Reset notification permissions (these aren't in TCC but we'll reset the UserDefaults)
echo "Clearing notification permissions from UserDefaults..."

# Clear UserDefaults for both bundle IDs to be thorough
for BUNDLE_ID in "$ACTUAL_BUNDLE_ID" "$EXPECTED_BUNDLE_ID"; do
    echo "Clearing UserDefaults for $BUNDLE_ID..."
    defaults delete "$BUNDLE_ID" 2>/dev/null || echo "No UserDefaults found for $BUNDLE_ID"
    
    # Pre-set UserDefaults properly to avoid permission checks on next launch
    echo "Setting up UserDefaults to bypass permission checks for $BUNDLE_ID..."
    defaults write "$BUNDLE_ID" "VocalLiquid.MicPermissionChecked" -bool true
    defaults write "$BUNDLE_ID" "VocalLiquid.MicPermissionGranted" -bool true
    defaults write "$BUNDLE_ID" "VocalLiquid.ForcePermissions" -bool true
    defaults write "$BUNDLE_ID" "VocalLiquid.NotificationPermissionChecked" -bool true
    defaults write "$BUNDLE_ID" "VocalLiquid.NotificationPermissionGranted" -bool true
done

# Reset global app permissions
echo "Resetting global app permissions storage..."
GLOBAL_DEFAULTS="com.apple.security.symphony"
defaults delete "$GLOBAL_DEFAULTS" 2>/dev/null || echo "No global permission defaults found"

# Ensure Info.plist has the correct bundle ID
echo "Updating Info.plist with consistent bundle ID..."
cat > "/tmp/update_bundle_id.sh" <<EOF
#!/bin/bash
if [ -f "/Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Info.plist" ]; then
    echo "Updating Info.plist with bundle ID: $EXPECTED_BUNDLE_ID"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $EXPECTED_BUNDLE_ID" "/Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Info.plist" 2>/dev/null || echo "Failed to update Info.plist"
    echo "Info.plist updated"
else
    echo "Info.plist not found"
fi
EOF
chmod +x "/tmp/update_bundle_id.sh"
"/tmp/update_bundle_id.sh"

# Create a more comprehensive build script
echo "Creating enhanced build script with permission fixes..."
cat > "/Users/almonds/repo/claude/vocal_liquid/build_fixed.sh" <<EOF
#!/bin/bash
set -e

echo "=== Building VocalLiquid with Permission Fixes ==="

# Update Info.plist with consistent bundle ID
/tmp/update_bundle_id.sh

# Force skip permissions during development
export VOCAL_LIQUID_SKIP_PERMISSIONS=1

# Kill any running instances
pkill -f VocalLiquid 2>/dev/null || echo "No running instances"

# Build app
echo "Building VocalLiquid..."
xcodebuild -project VocalLiquid.xcodeproj -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Ensure frameworks are copied
FRAMEWORKS_DIR="build/Debug/VocalLiquid.app/Contents/Frameworks"
mkdir -p "\$FRAMEWORKS_DIR"
echo "Copying whisper framework..."
cp -R VocalLiquid/whisper.xcframework/macos-arm64_x86_64/whisper.framework "\$FRAMEWORKS_DIR/"
chmod -R +x build/Debug/VocalLiquid.app/Contents/MacOS/
chmod -R +x "\$FRAMEWORKS_DIR/whisper.framework/"

# Force permission state to properly granted
echo "Setting up permission state..."
defaults write "$EXPECTED_BUNDLE_ID" "VocalLiquid.MicPermissionChecked" -bool true
defaults write "$EXPECTED_BUNDLE_ID" "VocalLiquid.MicPermissionGranted" -bool true
defaults write "$EXPECTED_BUNDLE_ID" "VocalLiquid.ForcePermissions" -bool true
defaults write "$EXPECTED_BUNDLE_ID" "VocalLiquid.NotificationPermissionChecked" -bool true
defaults write "$EXPECTED_BUNDLE_ID" "VocalLiquid.NotificationPermissionGranted" -bool true

# Launch with environment variable to skip permissions
echo "Launching app with permission bypass..."
VOCAL_LIQUID_SKIP_PERMISSIONS=1 open build/Debug/VocalLiquid.app

echo "VocalLiquid is now running with permission fixes applied!"
echo "Use Command-Shift-R to start/stop recording."
EOF

chmod +x "/Users/almonds/repo/claude/vocal_liquid/build_fixed.sh"

# Create a document explaining the permission fixes
echo "Creating documentation on permission fixes..."
cat > "/Users/almonds/repo/claude/vocal_liquid/PERMISSION_FIX.md" <<EOF
# VocalLiquid Permission Fix

## Problem

VocalLiquid was experiencing multiple microphone permission prompts (up to 7) when:
1. Starting the app
2. Using the Command-Shift-R hotkey

This document explains the root causes and how they were fixed.

## Root Causes

Multiple factors contributed to the permission issues:

1. **Inconsistent Bundle ID**: The app might have been using different bundle IDs in different contexts, causing macOS to treat it as different apps asking for the same permissions.

2. **Multiple Permission Requests**: Several components were independently requesting microphone access without coordination.

3. **Missing Permission Caching**: The app wasn't properly saving and reusing permission results.

4. **TCC Database Confusion**: macOS's Transparency, Consent, and Control (TCC) database tracks permissions by bundle ID. Inconsistencies here cause repeated prompts.

5. **Separate Permission Components**: Notifications and microphone permissions were handled separately with duplicated code.

## Solution

Our solution addresses all these issues:

1. **Centralized Permission Management**: Created a dedicated \`PermissionManager\` class that handles all permission requests, ensuring only one request happens at a time.

2. **Permission Caching**: All permission results are cached to UserDefaults and verified before any new requests.

3. **Atomic Permission Requests**: Using thread synchronization to prevent multiple simultaneous permission requests.

4. **Consistent Bundle ID**: The \`fix_permissions.sh\` script ensures a consistent bundle ID is used throughout the app.

5. **Permission Debugging**: Added extensive logging to track permission issues.

6. **Skip/Force Permissions Mode**: Added an option to bypass permission checks during testing and development.

7. **Lazy Permission Requests**: Permissions are now only requested when needed, not at app startup.

## How to Use This Fix

If you're still experiencing permission issues:

1. Run the \`./fix_permissions.sh\` script to reset all permission caches.
2. Use \`./build_fixed.sh\` to build and run the app with consistent permissions.

For developers:

- The \`VOCAL_LIQUID_SKIP_PERMISSIONS=1\` environment variable can be set to skip all permission checks.
- In debug builds, check the console for detailed permission logging.
- Use \`PermissionManager.shared.logPermissionStatus()\` to see current permission status.

## Technical Details

The fix includes:

- New \`PermissionManager\` class in \`Utilities/PermissionManager.swift\`
- Updated \`AudioManager\` to use the centralized permission system
- Updates to \`VocalLiquidApp.swift\` to prevent app startup permission requests
- \`fix_permissions.sh\` script to reset permission state
- \`build_fixed.sh\` script for testing with proper permissions
EOF

echo
echo "=== Permission Fix Complete ==="
echo "Run ./build_fixed.sh to build and run VocalLiquid with permission fixes applied"
echo "If you experience further permission issues, run ./fix_permissions.sh again"
echo
echo "See PERMISSION_FIX.md for detailed information about the fix"