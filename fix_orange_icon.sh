#!/bin/bash
set -e

echo "=== Fixing Orange Icon Issue for VocalLiquid ==="
echo "This script addresses the issue with the menu bar icon staying orange after recording stops."
echo

# Ensure any existing instances are killed
echo "Killing any running instances of VocalLiquid..."
pkill -f VocalLiquid 2>/dev/null || true

# Create a temporary patch file to force hardcoded icon state
echo "Creating a temporary NSStatusButton extension to force icon state..."
cat > /tmp/VocalLiquid_icon_fix.swift << 'EOF'
import Cocoa

extension NSStatusBarButton {
    // Override contentTintColor to ensure it can't stay orange
    open override var contentTintColor: NSColor? {
        get {
            return super.contentTintColor
        }
        set {
            // Only allow setting to nil or .systemRed
            // If recording stops, force to nil
            if newValue == .systemRed {
                super.contentTintColor = .systemRed
                print("DEBUG: Setting status bar icon to RED")
            } else {
                super.contentTintColor = nil
                print("DEBUG: Forcing status bar icon to NORMAL")
            }
            // Force a redraw
            self.needsDisplay = true
            self.superview?.needsDisplay = true
        }
    }
}
EOF

echo "The fix has been prepared."
echo
echo "Next steps:"
echo "1. Build VocalLiquid with this extension included"
echo "2. Test to ensure the icon properly resets when recording stops"
echo
echo "To run the app with this fix:"
echo "  cat /tmp/VocalLiquid_icon_fix.swift >> VocalLiquid/Utilities/UIExtensions.swift"
echo "  ./build_background.sh"
echo
echo "NOTE: This is a temporary debugging solution. The proper fix is already"
echo "implemented in the StatusBarController.swift file with the resetStatusBarIcon method."