#!/bin/bash
set -e

echo "=== VocalLiquid Startup Setup ==="
echo "This script will set up VocalLiquid to run at startup"
echo

# Check if the app exists in Applications folder
APP_PATH="/Applications/VocalLiquid.app"
if [ ! -d "$APP_PATH" ]; then
    APP_PATH="$HOME/Applications/VocalLiquid.app"
    if [ ! -d "$APP_PATH" ]; then
        echo "VocalLiquid.app not found in /Applications or ~/Applications"
        echo
        echo "Would you like to copy the built app to ~/Applications? (y/n)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # Find the most recent build
            BUILD_APP=$(find /Users/almonds/repo/claude/vocal_liquid/build -name "*.app" -type d | head -n 1)
            if [ -z "$BUILD_APP" ]; then
                echo "Error: No built app found. Please build the app first."
                exit 1
            fi
            
            # Create ~/Applications if it doesn't exist
            mkdir -p "$HOME/Applications"
            
            # Copy the app
            echo "Copying $BUILD_APP to $HOME/Applications/VocalLiquid.app"
            cp -R "$BUILD_APP" "$HOME/Applications/VocalLiquid.app"
            APP_PATH="$HOME/Applications/VocalLiquid.app"
        else
            echo "Please build and install VocalLiquid.app first, then run this script again."
            exit 1
        fi
    fi
fi

echo "Found VocalLiquid at: $APP_PATH"
echo

# Option 1: Modern Login Items approach
echo "Setting up modern Login Items..."
echo "NOTE: This requires manual confirmation in System Settings"
echo

# Using the osascript approach for modern Login Items
osascript <<EOD
tell application "System Events"
    make new login item at end with properties {path:"$APP_PATH", hidden:false}
end tell
EOD

echo "Login item added. You may need to approve it in:"
echo "System Settings → General → Login Items"
echo

# Option 2: LaunchAgents approach (traditional)
echo "Setting up Launch Agent (traditional approach)..."

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$HOME/Library/LaunchAgents"

# Create property list file
PLIST_PATH="$HOME/Library/LaunchAgents/com.vocalliquid.app.plist"

cat > "$PLIST_PATH" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vocalliquid.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH/Contents/MacOS/VocalLiquid</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/VocalLiquid.log</string>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/VocalLiquid.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOL

# Set permissions
chmod 644 "$PLIST_PATH"

# Load the LaunchAgent
launchctl load "$PLIST_PATH"

echo "LaunchAgent created at: $PLIST_PATH"
echo "VocalLiquid will now run at startup"
echo

echo "=== Setup Complete ==="
echo "VocalLiquid is now configured to launch at startup using:"
echo "1. Modern Login Items (requires approval in System Settings)"
echo "2. LaunchAgents (traditional approach)"
echo
echo "Logs will be available at: $HOME/Library/Logs/VocalLiquid.log"
echo
echo "To remove from startup:"
echo "1. System Settings → General → Login Items → Remove VocalLiquid"
echo "2. Run: launchctl unload $PLIST_PATH && rm $PLIST_PATH"