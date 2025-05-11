#!/bin/bash
set -e

echo "=== Building SuperDebug Version of VocalLiquid ==="
echo "This will create a special debug build with enhanced logging"

# Kill any running instances
pkill -f VocalLiquid 2>/dev/null || true

# Create a debug utilities file for advanced logging and diagnostics
mkdir -p /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Utilities

cat > /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Utilities/DebugUtils.swift << 'EOF'
import Cocoa
import AVFoundation

// Global debug function
func DEBUG_LOG(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    print("🔍 DEBUG [\(fileName):\(line) \(function)] \(message)")
}

// Extension to track NSStatusBarButton state changes
extension NSStatusBarButton {
    // Track when contentTintColor changes
    open override var contentTintColor: NSColor? {
        get {
            return super.contentTintColor
        }
        set {
            DEBUG_LOG("Setting contentTintColor: \(newValue == nil ? "nil" : newValue.debugDescription)")
            super.contentTintColor = newValue
            
            // Force a redraw
            self.needsDisplay = true
            self.superview?.needsDisplay = true
            
            // Schedule another redraw to ensure it takes effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                DEBUG_LOG("Forcing redraw after contentTintColor change")
                self.needsDisplay = true
                self.superview?.needsDisplay = true
            }
        }
    }
}

// Extension to track permission requests
extension AVCaptureDevice {
    // Track when authorization status is checked
    @available(macOS 10.14, *)
    class func debugAuthorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        let status = AVCaptureDevice.authorizationStatus(for: mediaType)
        DEBUG_LOG("Checked authorization status for \(mediaType): \(status.debugDescription)")
        return status
    }
    
    // Track when access is requested
    @available(macOS 10.14, *)
    class func debugRequestAccess(for mediaType: AVMediaType, completionHandler handler: @escaping (Bool) -> Void) {
        DEBUG_LOG("Requesting access for \(mediaType)")
        AVCaptureDevice.requestAccess(for: mediaType) { granted in
            DEBUG_LOG("Access request for \(mediaType) completed: \(granted ? "GRANTED" : "DENIED")")
            handler(granted)
        }
    }
}

// Extension to provide debug description for AVAuthorizationStatus
extension AVAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
}
EOF

# Modify the AudioManager to use the debug functions
grep -q "debugAuthorizationStatus" /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/AudioManager.swift || sed -i '' 's/AVCaptureDevice.authorizationStatus(for: .audio)/AVCaptureDevice.debugAuthorizationStatus(for: .audio)/g' /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/AudioManager.swift

grep -q "debugRequestAccess" /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/AudioManager.swift || sed -i '' 's/AVCaptureDevice.requestAccess(for: .audio)/AVCaptureDevice.debugRequestAccess(for: .audio)/g' /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/AudioManager.swift

# Add debug log statements to key functions in StatusBarController
cat > /tmp/debug_patching.sed << 'EOF'
# Add DEBUG_LOG to forceResetIcon
/func forceResetIcon/a\
        DEBUG_LOG("Explicitly resetting status bar icon - START")

# Add DEBUG_LOG at the end of forceResetIcon
/print("ICON: Reset status bar icon/a\
        DEBUG_LOG("Explicitly resetting status bar icon - COMPLETE")

# Add DEBUG_LOG to stopRecording
/func stopRecording/a\
        DEBUG_LOG("Stopping recording - START")

# Add DEBUG_LOG at the end of stopRecording
/Post notification for transcription failure/a\
                    DEBUG_LOG("Recording fully stopped and transcription complete")
EOF

sed -i.debugbak -f /tmp/debug_patching.sed /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/StatusBarController.swift

# Reset TCC database for VocalLiquid
echo "Resetting permission database for VocalLiquid..."
tccutil reset Microphone com.example.VocalLiquid 2>/dev/null || echo "Could not reset TCC database (may need sudo)"

# Clean UserDefaults
echo "Cleaning UserDefaults settings..."
defaults delete com.example.VocalLiquid 2>/dev/null || true

# Run the standard build script with a DEBUG flag
echo "Building and running VocalLiquid with debug logging..."
DEBUG_VOCAL_LIQUID=1 ./build_background.sh