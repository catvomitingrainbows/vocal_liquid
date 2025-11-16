# Building VocalLiquid for macOS Sequoia 15.6.1

## Quick Fix (Command Line)

Run these commands in Terminal to fix the existing app:

```bash
# Remove quarantine attributes from the existing app
xattr -cr /Applications/VocalLiquid.app

# Ad-hoc sign the app for local use
codesign --force --deep --sign - /Applications/VocalLiquid.app

# Verify the signature
codesign --verify --verbose /Applications/VocalLiquid.app
```

## Building from Source in Xcode

### Prerequisites
1. Xcode 15.0 or later installed
2. macOS Sequoia 15.6.1

### Step-by-Step Instructions

1. **Open the project in Xcode**
   ```bash
   cd /Users/almonds/repo/claude/vocal_liquid
   open VocalLiquid.xcodeproj
   ```

2. **Configure Signing (in Xcode)**
   - Select the VocalLiquid project in the navigator
   - Select the VocalLiquid target
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Set Team to "None" or your Apple ID (personal team is fine)
   - Bundle Identifier should be: `com.local.VocalLiquid`

3. **Set Build Configuration**
   - Product menu → Scheme → Edit Scheme
   - Set Build Configuration to "Release"
   - Close the scheme editor

4. **Build the Application**
   - Product menu → Build (⌘B)
   - Wait for build to complete

5. **Archive and Export**
   - Product menu → Archive
   - When Archive completes, Organizer window opens
   - Select your archive and click "Distribute App"
   - Choose "Copy App" 
   - Select a location to save (e.g., Desktop)
   - Click "Export"

6. **Install the Application**
   ```bash
   # Remove old version
   rm -rf /Applications/VocalLiquid.app
   
   # Copy new version (adjust path as needed)
   cp -R ~/Desktop/VocalLiquid.app /Applications/
   
   # Remove quarantine
   xattr -cr /Applications/VocalLiquid.app
   
   # Ad-hoc sign for local use
   codesign --force --deep --sign - /Applications/VocalLiquid.app
   ```

## Handling macOS Security Warnings

### First Launch
1. Open System Settings → Privacy & Security
2. Look for a message about VocalLiquid being blocked
3. Click "Open Anyway"
4. Enter your password when prompted

### Permissions
When you first run VocalLiquid, you'll need to grant:
- **Microphone access**: For recording audio
- **Accessibility access**: For global hotkeys (if prompted)

### Adding to Login Items
1. System Settings → General → Login Items
2. Click the + button
3. Navigate to /Applications
4. Select VocalLiquid.app
5. Click Add

## Troubleshooting

### "Malware Detected" Error
This happens because the app isn't notarized by Apple. The ad-hoc signing above should resolve this.

### "App is Damaged" Error
Run these commands:
```bash
xattr -cr /Applications/VocalLiquid.app
codesign --force --deep --sign - /Applications/VocalLiquid.app
```

### Developer Tools Not Set
If you get xcodebuild errors, run:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Alternative: Quick Build Script

Save this as `quick_build.sh` and run it:

```bash
#!/bin/bash
# Open Xcode with the project
open -a Xcode VocalLiquid.xcodeproj

echo "Build instructions:"
echo "1. In Xcode: Product → Build (⌘B)"
echo "2. Product → Show Build Folder in Finder"
echo "3. Navigate to Products/Release/VocalLiquid.app"
echo "4. Drag VocalLiquid.app to Applications"
echo "5. Run: xattr -cr /Applications/VocalLiquid.app"
echo "6. Run: codesign --force --deep --sign - /Applications/VocalLiquid.app"
```