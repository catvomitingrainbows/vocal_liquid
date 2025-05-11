#!/bin/bash
set -e

echo "=== Building Diagnostic App ==="

# Create a simple Info.plist for the app
cat > Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.example.VocalLiquidDiagnostic</string>
	<key>CFBundleName</key>
	<string>VocalLiquidDiagnostic</string>
	<key>CFBundleDisplayName</key>
	<string>VocalLiquid Diagnostic</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>This diagnostic app needs microphone access for testing permission behaviors.</string>
</dict>
</plist>
EOF

# Compile the Swift file
echo "Compiling diagnose_app.swift..."
swiftc -o DiagnoseApp \
       -framework Cocoa \
       -framework AVFoundation \
       diagnose_app.swift

# Make it executable
chmod +x DiagnoseApp

echo
echo "=== Running Diagnostic App ==="
echo "This app will test permissions and menu bar icon state"
echo "Watch the console for diagnostic output"
echo

# Clean up any previous UserDefaults settings
defaults delete com.example.VocalLiquidDiagnostic 2>/dev/null || true

# Run it
./DiagnoseApp