import Cocoa
import AVFoundation

class DiagnoseApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=== Starting Diagnostic App for VocalLiquid ===")
        
        // Set up the status bar item
        setupStatusBarItem()
        
        // Schedule status bar tests
        scheduleTests()
        
        // Check permission status and log values
        checkPermissionStatus()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Use SF Symbol for icon
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                    button.image = image
                    print("✅ Set initial status bar icon")
                } else {
                    print("❌ Failed to load SF Symbol")
                    button.title = "🎤"
                }
            } else {
                button.title = "🎤"
            }
            
            // Create menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Make Icon Orange", action: #selector(makeOrange), keyEquivalent: "o"))
            menu.addItem(NSMenuItem(title: "Reset Icon", action: #selector(resetIcon), keyEquivalent: "r"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Request Microphone Permission", action: #selector(requestMicPermission), keyEquivalent: "m"))
            menu.addItem(NSMenuItem(title: "Show Permission Status", action: #selector(checkPermissionStatus), keyEquivalent: "p"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            
            print("✅ Status bar menu set up")
        } else {
            print("❌ Failed to get status item button")
        }
    }
    
    private func scheduleTests() {
        // Test 1: Make icon orange after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.makeOrange()
        }
        
        // Test 2: Reset icon after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.resetIcon()
        }
        
        // Test 3: Check permissions after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkPermissionStatus()
        }
    }
    
    @objc func makeOrange() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording") {
                    button.image = image
                    button.contentTintColor = .systemRed
                    print("🟠 Set status bar icon to ORANGE")
                }
            } else {
                button.title = "🔴"
            }
            
            // Force update
            button.needsDisplay = true
            button.superview?.needsDisplay = true
        }
    }
    
    @objc func resetIcon() {
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                    button.image = image
                    
                    // Try several ways to reset color
                    button.contentTintColor = nil
                    button.layer?.backgroundColor = nil
                    button.superview?.layer?.backgroundColor = nil
                    
                    print("⚪ Reset status bar icon to NORMAL")
                }
            } else {
                button.title = "🎤"
            }
            
            // Force update
            button.needsDisplay = true
            button.superview?.needsDisplay = true
            
            // Due to potential race conditions in the redraw cycle, schedule another redraw
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let button = self?.statusItem.button {
                    button.contentTintColor = nil
                    button.needsDisplay = true
                    button.superview?.needsDisplay = true
                }
            }
        }
    }
    
    @objc func requestMicPermission() {
        print("📣 Requesting microphone permission...")
        
        // Check current status first
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("   Current permission status: \(statusToString(currentStatus))")
        
        // Only request if not determined
        if currentStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    print("   Permission request result: \(granted ? "GRANTED" : "DENIED")")
                    self.checkPermissionStatus()
                }
            }
        } else {
            print("   Cannot request - status already determined")
        }
    }
    
    @objc func checkPermissionStatus() {
        print("📋 Checking permission status...")
        
        // Check AudioCaptureDevice status
        let captureStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("   AVCaptureDevice status: \(statusToString(captureStatus))")
        
        // Check UserDefaults values
        let defaults = UserDefaults.standard
        print("   UserDefaults values:")
        print("   - VocalLiquid.MicPermissionChecked: \(defaults.bool(forKey: "VocalLiquid.MicPermissionChecked"))")
        print("   - VocalLiquid.MicPermissionGranted: \(defaults.bool(forKey: "VocalLiquid.MicPermissionGranted"))")
        print("   - VocalLiquid.ForcePermissions: \(defaults.bool(forKey: "VocalLiquid.ForcePermissions"))")
        
        // Check microphone devices
        print("   Microphone devices:")
        if #available(macOS 10.15, *) {
            let discoverySession = AVCaptureDeviceDiscoverySession(
                deviceTypes: [.builtInMicrophone],
                mediaType: .audio,
                position: .unspecified
            )
            if let devices = discoverySession?.devices {
                print("   - Found \(devices.count) audio devices")
                devices.forEach { device in
                    print("   - Device: \(device.localizedName)")
                }
            }
        } else {
            // Fallback for older macOS
            let devices = AVCaptureDevice.devices(for: .audio)
            print("   - Found \(devices.count) audio devices")
            devices.forEach { device in
                print("   - Device: \(device.localizedName)")
            }
        }
        
        // Check bundle ID
        if let bundleID = Bundle.main.bundleIdentifier {
            print("   Current app bundle ID: \(bundleID)")
        } else {
            print("   ❌ No bundle identifier found!")
        }
    }
    
    private func statusToString(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
}

// Start the app
let app = NSApplication.shared
let delegate = DiagnoseApp()
app.delegate = delegate
app.run()