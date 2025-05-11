import Cocoa

// Simple app with single purpose: Test if menu bar icon can be reset by replacing the entire status item
class IconOnlyApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Launching IconOnly app")
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Set up menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Turn Red", action: #selector(turnRed), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Turn Normal", action: #selector(turnNormal), keyEquivalent: "n"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Replace Status Item", action: #selector(replaceStatusItem), keyEquivalent: "p"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            
            // Set initial icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Normal") {
                    button.image = image
                }
            } else {
                button.title = "N"
            }
            
            print("Status bar setup complete")
        }
    }
    
    @objc func turnRed() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Red") {
                    button.image = image
                    button.contentTintColor = .systemRed
                }
            } else {
                button.title = "R"
            }
            button.needsDisplay = true
            print("Set icon to RED")
        }
    }
    
    @objc func turnNormal() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Normal") {
                    button.image = image
                    button.contentTintColor = nil
                }
            } else {
                button.title = "N"
            }
            button.needsDisplay = true
            print("Set icon to NORMAL")
        }
    }
    
    @objc func replaceStatusItem() {
        print("Replacing entire status item")
        
        // Save old status item to remove it
        let oldItem = statusItem
        
        // Create new status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Set up normal icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "New") {
                    button.image = image
                }
            } else {
                button.title = "N"
            }
            
            // Set up menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Turn Red", action: #selector(turnRed), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Turn Normal", action: #selector(turnNormal), keyEquivalent: "n"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Replace Status Item", action: #selector(replaceStatusItem), keyEquivalent: "p"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
        }
        
        // Remove old status item
        if let old = oldItem {
            NSStatusBar.system.removeStatusItem(old)
        }
        
        print("Status item replaced")
    }
}

// Run the app
let app = NSApplication.shared
let delegate = IconOnlyApp()
app.delegate = delegate
app.run()