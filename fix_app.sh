#!/bin/bash
set -e

# This script fixes code signing issues after building the app
# Usage: ./fix_app.sh [path_to_app]

APP_PATH=${1:-"build/Debug/VocalLiquid.app"}
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "Fixing app at $APP_PATH..."

# Create frameworks directory if missing
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
if [ ! -d "$FRAMEWORKS_DIR" ]; then
    echo "Creating Frameworks directory..."
    mkdir -p "$FRAMEWORKS_DIR"
fi

# Check if whisper framework is missing from the app
if [ ! -d "$FRAMEWORKS_DIR/whisper.framework" ]; then
    echo "Copying whisper framework to app bundle..."
    cp -R "VocalLiquid/whisper.xcframework/macos-arm64_x86_64/whisper.framework" "$FRAMEWORKS_DIR/"

    # Make sure framework is correctly structured
    if [ -d "$FRAMEWORKS_DIR/whisper.framework/Versions/A" ]; then
        if [ ! -L "$FRAMEWORKS_DIR/whisper.framework/Versions/Current" ]; then
            ln -sf A "$FRAMEWORKS_DIR/whisper.framework/Versions/Current"
        fi
        if [ ! -L "$FRAMEWORKS_DIR/whisper.framework/whisper" ]; then
            ln -sf Versions/Current/whisper "$FRAMEWORKS_DIR/whisper.framework/whisper"
        fi
        if [ ! -L "$FRAMEWORKS_DIR/whisper.framework/Headers" ]; then
            ln -sf Versions/Current/Headers "$FRAMEWORKS_DIR/whisper.framework/Headers"
        fi
    fi
fi

# Check if the resource model file exists
RESOURCES_DIR="$APP_PATH/Contents/Resources"
if [ ! -f "$RESOURCES_DIR/ggml-base.en.bin" ]; then
    echo "Copying model file to app bundle..."
    cp "VocalLiquid/Resources/ggml-base.en.bin" "$RESOURCES_DIR/"
fi

# Update the app's rpath to ensure it can find the framework
MACOS_BIN="$APP_PATH/Contents/MacOS/VocalLiquid"
if [ -f "$MACOS_BIN" ]; then
    echo "Updating rpath in main executable..."
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_BIN" 2>/dev/null || true

    # Make sure executable is properly set as executable
    echo "Ensuring executable permissions..."
    chmod +x "$MACOS_BIN"
fi

# Sign with ad-hoc signature (more permissive than no signature)
echo "Adding ad-hoc signature..."
codesign --force --deep --sign - "$APP_PATH"

echo "App fixed successfully!"
echo "Open the app with: open $APP_PATH"