import Cocoa

// The absolute simplest test of status bar icon coloring
class MinimalTest: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Starting SUPER minimal test")

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Set up basic menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Turn Red", action: #selector(turnRed), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Turn Normal", action: #selector(turnNormal), keyEquivalent: "n"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Replace Status Item", action: #selector(replaceItem), keyEquivalent: "p"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu

            // Set icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Test") {
                    button.image = image
                }
            } else {
                button.title = "T"
            }
        }

        // Schedule test sequence
        print("Will turn red in 2 seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.turnRed()

            print("Will attempt to turn normal in 3 seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.turnNormal()

                print("Checking result in 1 second")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let button = self.statusItem.button,
                       #available(macOS 11.0, *),
                       button.contentTintColor != nil {
                        print("❌ FAILED: Icon still has color: \(button.contentTintColor!)")
                        print("Try the Replace Status Item menu option")
                    } else {
                        print("✅ SUCCESS: Icon returned to normal color")
                    }
                }
            }
        }
    }

    @objc func turnRed() {
        print("Turning icon RED")
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Red") {
                    button.image = image
                    button.contentTintColor = .systemRed
                }
            } else {
                button.title = "R"
            }
            button.needsDisplay = true
        }
    }

    @objc func turnNormal() {
        print("Turning icon NORMAL")
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Normal") {
                    button.image = image
                    button.contentTintColor = nil
                }
            } else {
                button.title = "N"
            }
            button.needsDisplay = true
            if let superview = button.superview {
                superview.needsDisplay = true
            }
        }
    }

    @objc func replaceItem() {
        print("Completely replacing status bar item")

        // Remember the old one to remove it
        let oldItem = statusItem

        // Create a brand new one
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Set up basic icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "circle", accessibilityDescription: "New") {
                    button.image = image
                }
            } else {
                button.title = "N"
            }

            // Recreate menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Turn Red", action: #selector(turnRed), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Turn Normal", action: #selector(turnNormal), keyEquivalent: "n"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Replace Status Item", action: #selector(replaceItem), keyEquivalent: "p"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
        }

        // Remove the old one
        if let oldStatusItem = oldItem {
            NSStatusBar.system.removeStatusItem(oldStatusItem)
        }
    }
}

// Run the app
let app = NSApplication.shared
let delegate = MinimalTest()
app.delegate = delegate
app.run()
