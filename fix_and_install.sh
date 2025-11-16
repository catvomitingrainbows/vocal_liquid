#!/bin/bash

echo "🔧 Fixing and Installing VocalLiquid for macOS Sequoia"
echo "======================================================="

# Check if we have an archived build
ARCHIVE_APP="/Users/almonds/Library/Developer/Xcode/Archives/2025-05-13/VocalLiquid 5-13-25, 4.59 PM.xcarchive/Products/Applications/VocalLiquid.app"

if [ -d "$ARCHIVE_APP" ]; then
    echo "✅ Found archived build"
    APP_SOURCE="$ARCHIVE_APP"
else
    echo "❌ No archived build found. Please build in Xcode first."
    echo ""
    echo "To build in Xcode:"
    echo "1. Open VocalLiquid.xcodeproj in Xcode"
    echo "2. Product → Build (⌘B)"
    echo "3. Product → Archive"
    echo "4. Run this script again"
    exit 1
fi

# Create a working copy
echo "📋 Creating working copy..."
TEMP_APP="/tmp/VocalLiquid.app"
rm -rf "$TEMP_APP"
cp -R "$APP_SOURCE" "$TEMP_APP"

# Remove all extended attributes (including quarantine)
echo "🧹 Removing quarantine and extended attributes..."
xattr -cr "$TEMP_APP"

# Ad-hoc sign the application
echo "🔏 Ad-hoc signing the application..."
codesign --force --deep --sign - "$TEMP_APP"

# Verify the signature
echo "🔍 Verifying signature..."
codesign --verify --verbose "$TEMP_APP" 2>&1

# Install to Applications
echo "📦 Installing to Applications folder..."
DEST="/Applications/VocalLiquid.app"

# Remove old version if exists
if [ -d "$DEST" ]; then
    echo "🗑️ Removing old version..."
    rm -rf "$DEST"
fi

# Copy to Applications
cp -R "$TEMP_APP" "$DEST"

# Set proper permissions
chmod -R 755 "$DEST"

# Final verification
echo ""
echo "🎉 Installation Complete!"
echo "========================"
echo "📍 Location: $DEST"
echo ""

# Check signature
echo "📝 Final signature check:"
codesign -dv "$DEST" 2>&1 | grep -E "Signature|Identifier"

echo ""
echo "🚀 Next Steps:"
echo "1. Try launching the app: open /Applications/VocalLiquid.app"
echo "2. If you see a security warning:"
echo "   - Go to System Settings → Privacy & Security"
echo "   - Look for VocalLiquid and click 'Open Anyway'"
echo "3. Grant microphone permission when prompted"
echo "4. To add to Login Items:"
echo "   - System Settings → General → Login Items → Add VocalLiquid"

# Try to open the app
echo ""
read -p "Would you like to try opening the app now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open /Applications/VocalLiquid.app
    echo "✅ App launch attempted. Check for any security prompts."
fi