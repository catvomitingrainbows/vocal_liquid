#!/bin/bash

# Build and sign VocalLiquid for macOS Sequoia
# This script creates a properly signed build that won't be flagged as malware

echo "🔧 Building VocalLiquid with proper code signing..."

# Set variables
PROJECT_PATH="VocalLiquid.xcodeproj"
SCHEME="VocalLiquid"
BUILD_DIR="build"
CONFIGURATION="Release"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
xcodebuild clean -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION"

# Build the app with automatic code signing
echo "🏗️ Building application..."
xcodebuild build \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_STYLE="Automatic" \
    PRODUCT_BUNDLE_IDENTIFIER="com.local.VocalLiquid" \
    -allowProvisioningUpdates

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# Find the built app
APP_PATH=$(find "$BUILD_DIR" -name "VocalLiquid.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find built application"
    exit 1
fi

echo "✅ Build successful: $APP_PATH"

# Ad-hoc sign the application (for local use without Apple Developer account)
echo "🔏 Ad-hoc signing the application..."
codesign --force --deep --sign - "$APP_PATH"

# Verify the signature
echo "🔍 Verifying code signature..."
codesign --verify --verbose "$APP_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Code signature verified successfully"
else
    echo "⚠️ Code signature verification failed, but continuing..."
fi

# Remove quarantine attributes if they exist
echo "🧹 Removing quarantine attributes..."
xattr -cr "$APP_PATH"

# Copy to Applications folder
echo "📦 Copying to Applications folder..."
DEST_PATH="/Applications/VocalLiquid.app"

# Remove old version if it exists
if [ -d "$DEST_PATH" ]; then
    echo "🗑️ Removing old version..."
    rm -rf "$DEST_PATH"
fi

cp -R "$APP_PATH" "$DEST_PATH"

# Remove quarantine from the installed app as well
xattr -cr "$DEST_PATH"

# Set proper permissions
chmod -R 755 "$DEST_PATH"

echo "✨ Build complete!"
echo "📍 Application installed at: $DEST_PATH"
echo ""
echo "🚀 Next steps:"
echo "1. Open System Settings > Privacy & Security"
echo "2. If you see a security warning about VocalLiquid, click 'Open Anyway'"
echo "3. Grant microphone permission when prompted"
echo "4. The app should now work normally"
echo ""
echo "💡 To add to Login Items:"
echo "   System Settings > General > Login Items > Add VocalLiquid"