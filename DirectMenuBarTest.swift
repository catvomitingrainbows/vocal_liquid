import Cocoa

// Basic NSStatusItem creation test to verify menu bar functionality
class DirectMenuBar {
    var statusItem: NSStatusItem?
    
    init() {
        print("Creating direct status bar test item")
        // Create a status item with fixed width
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            print("Successfully got status item button")
            button.title = "🔈"
            print("Set button title to speaker emoji")
            
            // Create a basic menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Status Bar Item Working", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem?.menu = menu
            print("Menu configured with quit item")
        } else {
            print("ERROR: Failed to get button from status item")
        }
    }
}

func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    
    // Create our menu bar test item
    let menuBarTest = DirectMenuBar()
    print("Menu bar test item created")
    
    // Keep a reference to prevent deallocation
    _ = menuBarTest
    
    // Run the app
    print("Running application main loop")
    app.run()
}

print("Starting direct menu bar test")
main()