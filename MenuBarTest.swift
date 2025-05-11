import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching")

        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            print("Got status item button")
            button.title = "🎤"
            print("Set button title to microphone icon")
        } else {
            print("Failed to get status item button")
        }

        // Create a menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Hello World", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        print("Menu set up")

        print("Application setup complete")
    }
}

// Main function to run the app
func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)

    // Force the app to go to the menu bar
    NSApp.finishLaunching()

    // Run the app
    app.run()
}

// Call the main function
main()