import Cocoa

// A minimal test that focuses ONLY on the status bar icon issue
class IconTester: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Starting minimal icon test")
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Set up icon
        if let button = statusItem.button {
            // Create menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Make Icon Red", action: #selector(makeRed), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Make Icon Normal", action: #selector(makeNormal), keyEquivalent: "n"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Replace Status Item", action: #selector(replaceItem), keyEquivalent: "x"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            
            // Set initial icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Test Icon") {
                    button.image = image
                }
            } else {
                button.title = "T"
            }
        }
        
        // Run test sequence
        scheduleTest()
    }
    
    func scheduleTest() {
        // Change to red after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print("TEST: Making icon red")
            self.makeRed()
            
            // Change back to normal after 2 more seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("TEST: Making icon normal")
                self.makeNormal()
                
                // Check if it worked after 1 more second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let color = self.statusItem.button?.contentTintColor {
                        print("❌ FAILED: Icon color is still set to \(color)")
                        print("Try the 'Replace Status Item' menu option as a last resort")
                    } else {
                        print("✅ SUCCESS: Icon color reset successfully")
                    }
                }
            }
        }
    }
    
    @objc func makeRed() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Red Icon") {
                    button.image = image
                    button.contentTintColor = .systemRed
                }
            } else {
                button.title = "R"
            }
            button.needsDisplay = true
        }
    }
    
    @objc func makeNormal() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Normal Icon") {
                    button.image = image
                    button.contentTintColor = nil
                }
            } else {
                button.title = "N"
            }
            button.needsDisplay = true
        }
    }
    
    @objc func replaceItem() {
        // This is the nuclear option - completely remove and recreate the status item
        if let oldItem = statusItem {
            NSStatusBar.system.removeStatusItem(oldItem)
        }
        
        // Create a new one
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Set icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Test Icon") {
                    button.image = image
                }
            } else {
                button.title = "N"
            }
            
            // Recreate menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Make Icon Red", action: #selector(makeRed), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Make Icon Normal", action: #selector(makeNormal), keyEquivalent: "n"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Replace Status Item", action: #selector(replaceItem), keyEquivalent: "x"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
        }
        
        print("Status item completely replaced")
    }
}

// Run the app
let app = NSApplication.shared
let delegate = IconTester()
app.delegate = delegate
app.run()