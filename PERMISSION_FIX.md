# Fixing Multiple Permission Prompts in VocalLiquid

This document explains the solution implemented to fix the issue with multiple microphone permission prompts in VocalLiquid.

## Problem

The app was experiencing multiple permission prompts for microphone access, both at launch and when pressing the hotkey to start recording. This is due to how macOS handles audio session permissions and how the app was initializing/deinitializing audio components.

## Solution Overview

1. **Fixed Entitlements**: Added proper audio-input entitlement for hardened runtime
2. **Persistent Audio Engine**: Created a singleton AudioManager that keeps a single AVAudioEngine instance alive
3. **Improved Audio Session Lifecycle**: Only install/remove tap without stopping/starting the engine each time
4. **Explicit Permission Handling**: Request permission once at app launch using AVCaptureDevice API
5. **Improved Error Handling**: Added better error handling and user feedback for permission issues

## Key Files Changed

- **VocalLiquid.entitlements**: Added proper audio-input entitlement
- **AudioManager.swift**: New singleton manager for persistent audio engine
- **VocalLiquidApp.swift**: Updated to use the new AudioManager
- **build_background.sh**: Updated to include entitlements during build

## Utility Scripts

- **reset_permissions.sh**: Resets TCC database permissions for microphone (useful for testing)
- **build_background.sh**: Builds the app with correct entitlements

## Technical Details

### Audio Engine Lifecycle

The old implementation was creating and destroying audio sessions repeatedly, which was triggering multiple permission requests. The new implementation:

1. Creates the audio engine once at app startup
2. Keeps the engine initialized but not running until needed
3. Only starts the engine when first recording
4. Only installs/removes taps for recording without stopping the engine
5. Properly shuts down the engine only when the app terminates

### Permission Handling

The new implementation:

1. Explicitly requests permissions once at app startup using AVCaptureDevice.requestAccess
2. Checks permission status before attempting to record
3. Provides user feedback when permissions are missing
4. Persists permission state in UserDefaults
5. Avoids triggering new permission checks by reusing the audio engine

## How to Verify the Fix

1. Run `./reset_permissions.sh` to clear any existing permissions
2. Run `./build_background.sh` to build and launch the app
3. Grant permission when prompted (should only happen once)
4. Test the hotkey (Cmd+Shift+R) - it should not trigger additional permission prompts

If you still encounter permission issues, try running `./reset_permissions.sh` again and ensure you have granted permissions in System Settings > Privacy & Security > Microphone.

## References

1. [Apple TCC Database](https://developer.apple.com/documentation/security/transparency_consent_and_control)
2. [AVAudioEngine Documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
3. [macOS Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)