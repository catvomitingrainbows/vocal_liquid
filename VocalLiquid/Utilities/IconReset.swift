import Cocoa

// An extension that overrides contentTintColor to ensure it never stays orange
extension NSStatusBarButton {
    // Track the original implementation
    private static var originalSetterImplementation: Method?
    
    // This will run when the class is loaded
    public static func swizzleTintColor() {
        // Only run once
        if originalSetterImplementation != nil {
            return
        }
        
        // Get the original setter method
        if let originalMethod = class_getInstanceMethod(NSStatusBarButton.self, 
                                 NSSelectorFromString("setContentTintColor:")) {
            originalSetterImplementation = originalMethod
            
            // Create new implementation
            let newImplementation: @convention(block) (NSStatusBarButton, NSColor?) -> Void = { button, color in
                // Call original implementation with possibly modified color
                let originalImp = unsafeBitCast(
                    method_getImplementation(originalMethod),
                    to: (@convention(c) (NSStatusBarButton, Selector, NSColor?) -> Void).self
                )
                
                // Only allow setting to nil or .systemRed
                if color == NSColor.systemRed {
                    print("ICON: Setting to RED")
                    originalImp(button, NSSelectorFromString("setContentTintColor:"), color)
                } else {
                    print("ICON: Forcing to NIL")
                    originalImp(button, NSSelectorFromString("setContentTintColor:"), nil)
                }
                
                // Force redraw
                button.needsDisplay = true
                button.superview?.needsDisplay = true
            }
            
            // Create a new method implementation
            let newMethodImplementation = imp_implementationWithBlock(newImplementation)
            
            // Replace the method implementation
            method_setImplementation(originalMethod, newMethodImplementation)
            
            print("ICON: Swizzled contentTintColor setter")
        }
    }
}

// Actually perform the swizzling when this file is loaded
extension NSApplication {
    // This will run when NSApplication is first accessed
    open override class func initialize() {
        // Swizzle the tint color method
        NSStatusBarButton.swizzleTintColor()
    }
}
