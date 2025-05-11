#!/bin/bash
set -e

echo "=== Fixing Orange Icon Issue for VocalLiquid ==="
echo "This script applies the nuclear option to fix the status bar icon"

# Kill any running instances
pkill -f VocalLiquid 2>/dev/null || true

# Create a patch to implement the nuclear option for the status bar icon
mkdir -p /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Utilities

cat > /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Utilities/StatusBarIconFix.swift << 'EOF'
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
EOF

# Create a patch to modify the stopRecording method to use our enhanced reset
cat > /Users/almonds/repo/claude/vocal_liquid/stoprecording_patch.sed << 'EOF'
# Find where stopRecording calls forceResetIcon and replace with the enhanced version
/self.forceResetIcon()/c\
        self.enhancedForceResetIcon()
EOF

# Apply the patches
cp /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/StatusBarController.swift /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/StatusBarController.swift.backup
sed -i.bak -f /Users/almonds/repo/claude/vocal_liquid/stoprecording_patch.sed /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/StatusBarController.swift

# Also modify the setupMenu method to add our nuclear reset option to the menu
cat > /Users/almonds/repo/claude/vocal_liquid/menu_patch.sed << 'EOF'
# Find the menu setup spot and add our nuclear reset option
/Add a force reset icon option/a\
        statusBarMenu.addItem(NSMenuItem(title: "Nuclear Reset Icon", action: #selector(nuclearResetIcon), keyEquivalent: "n"))
EOF

# Apply the menu patch
sed -i.bak2 -f /Users/almonds/repo/claude/vocal_liquid/menu_patch.sed /Users/almonds/repo/claude/vocal_liquid/VocalLiquid/Managers/StatusBarController.swift

echo
echo "=== Icon Fix Applied ==="
echo "The status bar icon color issue should now be fixed:"
echo
echo "1. The icon will be reset using the nuclear option if the normal reset fails"
echo "2. A 'Nuclear Reset Icon' menu option has been added to fix the icon manually"
echo 
echo "To build and run VocalLiquid with this fix:"
echo "  ./build_background.sh"