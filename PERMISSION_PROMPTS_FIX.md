# Fixing Multiple Microphone Permission Prompts in VocalLiquid

## The Problem

VocalLiquid was requesting microphone permissions multiple times (up to seven prompts on startup), causing a poor user experience. This problem was caused by several factors:

1. **Universal App Architecture**: VocalLiquid is built as a Universal app (for both Intel and Apple Silicon), which can trigger multiple permission requests for different architectures.

2. **Bundle Identifier Issues**: Using variable references (`$(PRODUCT_BUNDLE_IDENTIFIER)`) in Info.plist instead of hardcoded values can lead to inconsistent permission tracking.

3. **Multiple Components Requesting Access**: Both the AudioManager and other components were potentially requesting microphone access independently.

4. **Permissions Not Being Properly Cached**: Each launch was triggering new permission checks instead of respecting previously granted permissions.

## The Solution

We've implemented several fixes to address these issues:

### 1. Hardcoded Bundle Identifier

We've updated the Info.plist file to use a hardcoded bundle identifier instead of a variable:

```xml
<key>CFBundleIdentifier</key>
<string>com.example.VocalLiquid</string>
<key>CFBundleDisplayName</key>
<string>VocalLiquid</string>
```

This ensures consistent permission tracking across builds and launches.

### 2. Improved AudioManager Permission Handling

We've enhanced the AudioManager.swift file to:

- Add debugging information to track the exact bundle ID being used
- Provide an environment variable escape hatch (`VOCAL_LIQUID_SKIP_PERMISSIONS`) to bypass permission checks during testing
- Ensure permissions are properly cached in UserDefaults

### 3. Permission Reset Script

We've created a `fix_multiple_permissions.sh` script that:

- Kills any running instances of VocalLiquid
- Resets the TCC database entries for the specific bundle ID
- Sets up UserDefaults to avoid unnecessary permission checks
- Runs the app with environment variables to skip permission prompts

## Technical Background

### How macOS Tracks Permissions

macOS uses the Transparency, Consent, and Control (TCC) database to track app permissions. This database associates permissions with bundle identifiers. When an app is built as a Universal binary, or if the bundle ID is inconsistent, it can confuse the TCC system and lead to multiple permission prompts.

The TCC database files are located at:
- Global: `/Library/Application Support/com.apple.TCC/TCC.db`
- User: `~/Library/Application Support/com.apple.TCC/TCC.db`

### Why Multiple Permission Prompts Occur

1. **Different Architectures**: A Universal app contains both Intel and Apple Silicon binaries, which might each trigger permission requests.

2. **Development vs. Release Builds**: Development builds might use different signing certificates or bundle identifiers than release builds.

3. **Framework vs. App Permissions**: If both your app and a framework it uses (like whisper.xcframework) try to access the microphone, you might get multiple prompts.

## Using the Fix Script

Run the `fix_multiple_permissions.sh` script to apply all the fixes:

```bash
./fix_multiple_permissions.sh
```

This script will:
1. Reset all microphone permissions for VocalLiquid
2. Configure UserDefaults to bypass unnecessary permission checks
3. Run the app with special environment settings

If you still experience multiple permission prompts after using this script, try:
1. Going to System Settings → Privacy & Security → Microphone
2. Toggling VocalLiquid off and on
3. Restarting your Mac

## For Developers

When working on VocalLiquid, remember:

1. Keep the bundle identifier consistent
2. Test permission handling with the environment variable:
   ```bash
   VOCAL_LIQUID_SKIP_PERMISSIONS=1 ./build_background.sh
   ```
3. Be careful when creating a Release build to ensure proper signing

By following these guidelines, VocalLiquid should only ask for microphone permission once, as intended.