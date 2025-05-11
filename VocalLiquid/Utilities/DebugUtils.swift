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
