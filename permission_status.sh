#!/bin/bash
set -e

echo "=== VocalLiquid Permission Status Checker ==="

# Helper function to check UserDefaults boolean value
check_default() {
    local domain="$1"
    local key="$2"
    local val=$(defaults read "$domain" "$key" 2>/dev/null || echo "NOT_SET")
    echo "$key: $val"
}

# Potential bundle IDs
BUNDLE_IDS=("com.vocalliquid.app" "com.example.VocalLiquid")
if [ -f "/Users/almonds/repo/claude/vocal_liquid/build/Debug/VocalLiquid.app/Contents/Info.plist" ]; then
    DETECTED_ID=$(defaults read /Users/almonds/repo/claude/vocal_liquid/build/Debug/VocalLiquid.app/Contents/Info.plist CFBundleIdentifier 2>/dev/null || echo "")
    if [ ! -z "$DETECTED_ID" ]; then
        BUNDLE_IDS+=("$DETECTED_ID")
        echo "Detected additional bundle ID from built app: $DETECTED_ID"
    fi
fi

# Check current Info.plist configuration
echo "Current Info.plist configuration:"
if [ -f "/Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Info.plist" ]; then
    INFO_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "/Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Info.plist" 2>/dev/null || echo "NOT_FOUND")
    echo "  Info.plist Bundle ID: $INFO_BUNDLE_ID"
else
    echo "  Info.plist file not found!"
fi

# Find the TCC database
echo "TCC Database locations:"
TCC_LOCATIONS=(
    "/Library/Application Support/com.apple.TCC/TCC.db"
    "$HOME/Library/Application Support/com.apple.TCC/TCC.db"
)

for TCC_DB in "${TCC_LOCATIONS[@]}"; do
    if [ -f "$TCC_DB" ]; then
        echo "Found TCC database at: $TCC_DB"
        
        # Check if we can query it (requires admin rights)
        for BUNDLE_ID in "${BUNDLE_IDS[@]}"; do
            echo "Checking TCC permissions for $BUNDLE_ID:"
            TCC_ENTRIES=$(sudo sqlite3 "$TCC_DB" "SELECT * FROM access WHERE client='$BUNDLE_ID'" 2>/dev/null || echo "ACCESS_DENIED")
            if [ "$TCC_ENTRIES" == "ACCESS_DENIED" ]; then
                echo "  Permission denied to read TCC database (this is normal)"
            elif [ -z "$TCC_ENTRIES" ]; then
                echo "  No entries found in TCC database for this bundle ID"
            else
                echo "  Found entries in TCC database:"
                echo "$TCC_ENTRIES"
            fi
        done
    else
        echo "TCC database not found at: $TCC_DB"
    fi
done

# Check UserDefaults for each potential bundle ID
for BUNDLE_ID in "${BUNDLE_IDS[@]}"; do
    echo "Checking UserDefaults for $BUNDLE_ID:"
    
    echo "  Permission-related keys:"
    check_default "$BUNDLE_ID" "VocalLiquid.MicPermissionChecked"
    check_default "$BUNDLE_ID" "VocalLiquid.MicPermissionGranted"
    check_default "$BUNDLE_ID" "VocalLiquid.NotificationPermissionChecked"
    check_default "$BUNDLE_ID" "VocalLiquid.NotificationPermissionGranted"
    check_default "$BUNDLE_ID" "VocalLiquid.ForcePermissions"
    
    echo "  Other important keys:"
    check_default "$BUNDLE_ID" "VocalLiquid.NotificationsShown"
done

# Check environment variables
echo "Environment variables:"
env | grep -i "permission\|vocal\|audio\|mic" || echo "No relevant environment variables found"

# Check if the app is currently running
APP_PID=$(ps aux | grep -v grep | grep -i "VocalLiquid" | awk '{print $2}' || echo "")
if [ ! -z "$APP_PID" ]; then
    echo "VocalLiquid is currently running with PID: $APP_PID"
else
    echo "VocalLiquid is not currently running"
fi

echo "=== Permission Status Check Complete ==="
echo "If you're experiencing issues, run ./fix_permissions.sh to reset permissions"