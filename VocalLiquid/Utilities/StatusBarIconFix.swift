import Cocoa

// This extension provides an emergency fallback to fix icon tint issues
// by completely replacing the status bar item when needed
extension StatusBarController {
    // Add a complete icon reset method that creates a new status item
    @objc func nuclearResetIcon() {
        // Store the recording state
        let wasRecording = isRecording
        
        // Get menu items we want to keep
        let oldMenu = statusBarMenu
        
        // Remove the existing status item
        NSStatusBar.system.removeStatusItem(statusItem)
        
        // Create a new status item
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        // Set up the new icon
        if let button = statusItem.button {
            var iconSet = false
            
            if #available(macOS 11.0, *) {
                let imageName = wasRecording ? "waveform.circle.fill" : "waveform"
                if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Voice Recording") {
                    button.image = image
                    // Only set tint if recording
                    button.contentTintColor = wasRecording ? .systemRed : nil
                    iconSet = true
                }
            }
            
            if !iconSet {
                button.title = wasRecording ? "🔴" : "🎤"
            }
            
            // Set image position
            button.imagePosition = .imageLeft
            
            // Force update to ensure visibility
            button.needsDisplay = true
        }
        
        // Restore menu
        statusItem.menu = oldMenu
        
        print("DEBUG: Nuclear reset of status bar icon complete - recording state: \(wasRecording)")
        logService.log(message: "Replaced status bar item to fix icon state", level: .info)
    }
}

// Add this method to ForceResetIcon
extension StatusBarController {
    @objc func enhancedForceResetIcon() {
        // Try normal reset first
        forceResetIcon()
        
        // Schedule nuclear option after a short delay if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            
            // Check if the icon is still orange
            if let button = self.statusItem.button, 
               #available(macOS 11.0, *),
               button.contentTintColor != nil {
                
                // If still orange, use the nuclear option
                self.nuclearResetIcon()
            }
        }
    }
}
