import Cocoa
import AVFoundation

class SimpleStatusBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var isRecording = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=== Starting SimpleStatusBar Test App ===")
        
        // Set up status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                    button.image = image
                    print("✅ Set initial icon")
                }
            } else {
                button.title = "🎤"
            }
            
            // Create menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "s"))
            menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "t"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Reset Icon", action: #selector(resetIcon), keyEquivalent: "r"))
            menu.addItem(NSMenuItem(title: "Force UI Update", action: #selector(forceUIUpdate), keyEquivalent: "f"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            
            // Set hotkey for Command-Shift-R
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 15 { // 15 is 'r'
                    self?.toggleRecording()
                }
            }
        }
        
        // Run automatic test after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            print("🧪 Running automatic icon test sequence...")
            self?.runAutomaticTest()
        }
    }
    
    private func runAutomaticTest() {
        // Start recording - should turn icon orange
        print("🧪 Test: Starting recording (icon should turn orange)")
        startRecording()
        
        // After 2 seconds, stop recording - should reset icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            print("🧪 Test: Stopping recording (icon should reset to normal)")
            self?.stopRecording()
            
            // After stopping, check if icon is still orange
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                if let button = self?.statusItem.button, button.contentTintColor != nil {
                    print("❌ TEST FAILED: Icon is still orange after stopping recording")
                    print("   Try using the 'Reset Icon' menu item to force it to reset")
                } else {
                    print("✅ TEST PASSED: Icon properly reset to normal color")
                }
            }
        }
    }
    
    @objc func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    @objc func startRecording() {
        isRecording = true
        print("▶️ Starting recording simulation")
        
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording") {
                    button.image = image
                    button.contentTintColor = .systemRed
                    print("🟠 Set icon to ORANGE")
                }
            } else {
                button.title = "🔴"
            }
            button.needsDisplay = true
        }
    }
    
    @objc func stopRecording() {
        print("⏹️ Stopping recording simulation")
        isRecording = false
        resetIcon()
    }
    
    @objc func resetIcon() {
        print("🔄 Resetting icon to normal state")
        
        if let button = statusItem.button {
            // Multiple different approaches to try to reset the icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                    button.image = image
                }
                button.contentTintColor = nil
            } else {
                button.title = "🎤"
            }
            
            // Force redraw
            button.needsDisplay = true
            if let superview = button.superview {
                superview.needsDisplay = true
            }
            
            print("⚪ Reset status bar icon")
        }
        
        // Try another reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.delayedResetIcon()
        }
    }
    
    private func delayedResetIcon() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.contentTintColor = nil
            }
            button.needsDisplay = true
        }
    }
    
    @objc func forceUIUpdate() {
        print("🔄 Forcing full UI update")

        // Option 1: Just remove and recreate the icon completely
        // First, get the old status item
        if let oldStatusItem = statusItem {
            // Remove it from status bar
            NSStatusBar.system.removeStatusItem(oldStatusItem)

            // Create a new status item
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = statusItem.button {
                if #available(macOS 11.0, *) {
                    if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                        button.image = image
                        button.contentTintColor = nil
                    }
                } else {
                    button.title = "🎤"
                }

                // Re-create menu
                let menu = NSMenu()
                menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "s"))
                menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "t"))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Reset Icon", action: #selector(resetIcon), keyEquivalent: "r"))
                menu.addItem(NSMenuItem(title: "Force UI Update", action: #selector(forceUIUpdate), keyEquivalent: "f"))
                menu.addItem(NSMenuItem.separator())
                menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
                statusItem.menu = menu

                print("✅ Created new status bar item")
            }
        } else {
            print("⚠️ Cannot update - no status item exists")
        }
    }
}

// Start the app
let app = NSApplication.shared
let delegate = SimpleStatusBarApp()
app.delegate = delegate
app.run()
