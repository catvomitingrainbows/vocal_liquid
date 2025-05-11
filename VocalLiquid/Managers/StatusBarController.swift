import Cocoa
import SwiftUI

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var statusBarMenu: NSMenu
    private var isRecording = false

    // Various services needed
    private let hotkeyManager = HotkeyManager()

    // Use the singleton AudioManager instead of AudioEngineManager
    private var audioManager: AudioManager {
        return AudioManager.shared
    }

    private let whisperManager = WhisperManager()
    private let logService = LoggingService()

    init() {
        print("DEBUG: Initializing StatusBarController")

        // Initialize the status bar and menu
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarMenu = NSMenu(title: "Vocal Liquid")

        print("DEBUG: Status bar item created - pointer: \(statusItem)")

        // Add more debugging
        if statusItem.button == nil {
            print("ERROR: Status item button is nil!")
        } else {
            print("DEBUG: Status item button is available")
        }

        // Configure the status bar icon
        if let button = statusItem.button {
            print("DEBUG: Got status item button")

            // Try using SF Symbol first
            var iconSet = false

            if #available(macOS 11.0, *) {
                print("DEBUG: macOS 11 or later, trying SF Symbol")
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                    print("DEBUG: Setting waveform image")
                    button.image = image
                    iconSet = true
                } else {
                    print("DEBUG: Failed to get waveform SF Symbol")
                }
            }

            // Fall back to a text-based icon if SF Symbols aren't available
            if !iconSet {
                print("DEBUG: Setting fallback emoji icon")
                button.title = "🎤"
            }

            // Make sure it's visible with proper positioning
            button.imagePosition = .imageLeft

            // Force update to ensure visibility
            button.needsDisplay = true
        } else {
            print("ERROR: Failed to get status item button!")
        }

        logService.log(message: "Status bar button configured", level: .info)
        logService.log(message: "Status bar controller initialized", level: .info)

        print("DEBUG: Setting up menu, hotkeys, notifications")
        setupMenu()
        setupHotkeys()
        setupNotifications()

        // Force the status bar to update
        DispatchQueue.main.async {
            print("DEBUG: Forcing status bar update on main thread")
            self.statusItem.button?.needsDisplay = true
        }
    }
    
    private func setupMenu() {
        // Recording status
        let recordingStatusItem = NSMenuItem(title: "Not Recording", action: nil, keyEquivalent: "")
        recordingStatusItem.isEnabled = false
        statusBarMenu.addItem(recordingStatusItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Add recording shortcut info
        let shortcutItem = NSMenuItem(title: "Shortcut: ⌘⇧R", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        statusBarMenu.addItem(shortcutItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Version info
        let versionItem = NSMenuItem(title: "Vocal Liquid v1.0", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        statusBarMenu.addItem(versionItem)

        statusBarMenu.addItem(NSMenuItem.separator())

        // Add various troubleshooting options
        statusBarMenu.addItem(NSMenuItem(title: "Force Release Microphone", action: #selector(forceReleaseMicrophone), keyEquivalent: "m"))
        statusBarMenu.addItem(NSMenuItem.separator())

        // Add icon reset options with multiple levels of strength
        statusBarMenu.addItem(NSMenuItem(title: "Gentle Reset Icon", action: #selector(forceResetIcon), keyEquivalent: "g"))
        statusBarMenu.addItem(NSMenuItem(title: "Nuclear Reset Icon", action: #selector(nuclearResetIcon), keyEquivalent: "n"))
        statusBarMenu.addItem(NSMenuItem(title: "ULTRA NUCLEAR Reset Icon", action: #selector(ultraNuclearResetIcon), keyEquivalent: "u"))

        statusBarMenu.addItem(NSMenuItem.separator())

        // Quit
        statusBarMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Set the menu for the status item
        statusItem.menu = statusBarMenu

        // Log menu setup
        logService.log(message: "Status bar menu setup complete", level: .info)
    }
    
    private func setupHotkeys() {
        print("DEBUG: Setting up hotkeys with Command-Shift-R (keyCode 15)")
        // Register for Command-Shift-R by default
        hotkeyManager.registerHotkey(keyCode: 15, modifiers: [.command, .shift]) { [weak self] in
            print("DEBUG: Hotkey callback triggered! ")
            self?.toggleRecording()
        }
        print("DEBUG: Hotkey registration complete")
    }
    
    private func setupNotifications() {
        // Listen for notifications from the audio manager and whisper service
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateRecordingStatus(_:)),
            name: Notification.Name("RecordingStatusChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTranscriptionComplete(_:)),
            name: Notification.Name("TranscriptionComplete"),
            object: nil
        )
    }
    
    private func toggleRecording() {
        print("DEBUG: toggleRecording called - current state: isRecording=\(isRecording)")
        if isRecording {
            print("DEBUG: Will stop recording")
            stopRecording()
        } else {
            print("DEBUG: Will start recording")
            startRecording()
        }
        print("DEBUG: toggleRecording completed - new state: isRecording=\(isRecording)")
    }
    
    private func startRecording() {
        logService.log(message: "Starting recording", level: .info)
        
        // First check if we have microphone permission before attempting to record
        if !audioManager.hasMicrophonePermission {
            logService.log(message: "Cannot start recording: No microphone permission", level: .warning)
            
            // Show an error in the menu to indicate why recording failed
            if let recordingStatusItem = statusBarMenu.item(at: 0) {
                recordingStatusItem.title = "Cannot Record: No Permission"
            }
            
            return
        }

        // Start the audio recording first - only update UI if successful
        let success = audioManager.startRecording()

        if success {
            isRecording = true

            // Update status bar icon to show recording state
            if let button = statusItem.button {
                if #available(macOS 11.0, *) {
                    if let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording Active") {
                        button.image = image
                        button.contentTintColor = .systemRed
                    }
                } else {
                    // Fallback for older macOS
                    button.title = "🔴"
                }
                
                // Force update
                button.needsDisplay = true
            }

            // Update menu
            if let recordingStatusItem = statusBarMenu.item(at: 0) {
                recordingStatusItem.title = "Recording..."
            }

            // Post notification that recording has started
            NotificationCenter.default.post(
                name: Notification.Name("RecordingStatusChanged"),
                object: nil,
                userInfo: ["isRecording": true]
            )
        } else {
            logService.log(message: "Failed to start recording", level: .error)
            
            // Update menu to show error
            if let recordingStatusItem = statusBarMenu.item(at: 0) {
                recordingStatusItem.title = "Failed to Start Recording"
            }
        }
    }
    
    private func stopRecording() {
        logService.log(message: "Stopping recording", level: .info)
        print("DEBUG: stopRecording called - will reset icon")

        // First, update UI to show we're stopping
        isRecording = false

        // Go directly to nuclear option for icon reset since it's causing issues
        print("DEBUG: Performing nuclear icon reset directly from stopRecording")
        self.nuclearResetIcon()

        // Schedule additional ultra nuclear reset after a delay for redundancy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            print("DEBUG: Performing second nuclear reset after delay")
            self.nuclearResetIcon()
        }

        // Update menu
        if let recordingStatusItem = statusBarMenu.item(at: 0) {
            recordingStatusItem.title = "Transcribing..."
        }

        // Stop the audio recording and completely shut down the audio engine to release microphone
        audioManager.stopRecording()

        // Extra check to release microphone system indicator
        print("DEBUG: Ensuring microphone is fully released")
        
        // Post notification that recording has stopped
        NotificationCenter.default.post(
            name: Notification.Name("RecordingStatusChanged"),
            object: nil,
            userInfo: ["isRecording": false]
        )

        // Get the audio samples for transcription
        let samples = audioManager.getSamplesForTranscription()

        // Check if we have samples
        if samples.isEmpty {
            if let recordingStatusItem = statusBarMenu.item(at: 0) {
                recordingStatusItem.title = "Not Recording"
            }
            logService.log(message: "No audio samples collected", level: .warning)
            return
        }

        // Transcribe the audio
        whisperManager.transcribeAudio(samples: samples) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let recordingStatusItem = self.statusBarMenu.item(at: 0) {
                    recordingStatusItem.title = "Not Recording"
                }

                // Ensure icon is reset after transcription completes
        self.enhancedForceResetIcon()

                switch result {
                case .success(let transcription):
                    self.copyToClipboard(text: transcription)
                    self.logService.log(message: "Transcription complete", level: .info)
                    
                    // Post notification for transcription completion
                    NotificationCenter.default.post(
                        name: Notification.Name("TranscriptionComplete"),
                        object: nil,
                        userInfo: ["transcription": transcription]
                    )

                case .failure(let error):
                    self.logService.log(message: "Transcription error: \(error.localizedDescription)", level: .error)
                    
                    // Post notification for transcription failure
                    NotificationCenter.default.post(
                        name: Notification.Name("TranscriptionFailed"),
                        object: nil,
                        userInfo: ["error": error.localizedDescription]
                    )
                }
                
                // Reset icon again after completion, using nuclear option to guarantee it works
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.nuclearResetIcon()
                }
            }
        }
    }
    
    // ADDED: Dedicated method to reset the status bar icon to normal state 
    @objc private func forceResetIcon() {
        guard let button = statusItem.button else {
            return
        }
        
        logService.log(message: "Explicitly resetting status bar icon", level: .info)
        
        // Try multiple approaches to reset the icon
        
        // 1. Reset image and tint for macOS 11+
        if #available(macOS 11.0, *) {
            if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                button.image = image
                button.contentTintColor = nil
            }
        } else {
            // 2. Fallback for older macOS
            button.title = "🎤"
        }
        
        // 3. Explicitly clear any highlight state
        button.isHighlighted = false
        
        // 4. Explicitly clear any possible tint
        button.contentTintColor = nil
        
        // 5. Force redraw
        button.needsDisplay = true
        
        // 6. Update parent view
        button.superview?.needsDisplay = true
        
        // 7. Extra forceful approach
        button.layer?.backgroundColor = nil
        
        // 8. Log that we did this
        print("ICON: Reset status bar icon - button.contentTintColor is now nil")
    }
    
    private func copyToClipboard(text: String) {
        print("DEBUG: Copying text to clipboard: \"\(text.prefix(50))...\"")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        if success {
            print("DEBUG: Successfully copied text to clipboard")
            logService.log(message: "Copied transcription to clipboard", level: .info)
        } else {
            print("ERROR: Failed to copy text to clipboard")
            logService.log(message: "Failed to copy transcription to clipboard", level: .error)
        }

        // Verify clipboard content
        if let clipboardContent = pasteboard.string(forType: .string) {
            print("DEBUG: Clipboard verification - content: \"\(clipboardContent.prefix(50))...\"")
        } else {
            print("ERROR: Clipboard verification failed - no string data on clipboard")
        }
    }
    
    @objc private func updateRecordingStatus(_ notification: Notification) {
        // Handle recording status change notification from other components
        if let isRec = notification.userInfo?["isRecording"] as? Bool {
            logService.log(message: "Received recording status change notification: \(isRec)", level: .info)
            
            // Only update UI if our internal state doesn't match
            if isRec != isRecording {
                isRecording = isRec
                
                // Update UI
                if isRec {
                    // Update to recording state - icon and menu
                    if let button = statusItem.button {
                        if #available(macOS 11.0, *) {
                            if let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording Active") {
                                button.image = image
                                button.contentTintColor = .systemRed
                            }
                        } else {
                            button.title = "🔴"
                        }
                        button.needsDisplay = true
                    }
                    
                    if let recordingStatusItem = statusBarMenu.item(at: 0) {
                        recordingStatusItem.title = "Recording..."
                    }
                } else {
                    // Update to stopped state using multiple nuclear resets for redundancy
                    print("DEBUG: updateRecordingStatus - performing nuclear resets")
                    nuclearResetIcon()

                    // Schedule multiple nuclear resets with increasing delays for redundancy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        print("DEBUG: First delayed nuclear reset")
                        self.nuclearResetIcon()
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let self = self else { return }
                        print("DEBUG: Second delayed nuclear reset")
                        self.nuclearResetIcon()
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        print("DEBUG: Final ultra nuclear reset")
                        self.ultraNuclearResetIcon()
                    }
                    
                    if let recordingStatusItem = statusBarMenu.item(at: 0) {
                        recordingStatusItem.title = "Not Recording"
                    }
                }
            }
        }
    }
    
    @objc private func handleTranscriptionComplete(_ notification: Notification) {
        guard let transcription = notification.userInfo?["transcription"] as? String else {
            return
        }
        
        // Make sure icon is reset when transcription completes
        forceResetIcon()
        
        logService.log(message: "Transcription completed: \(transcription.prefix(50))...", level: .info)
    }

    // Enhanced version that goes straight to nuclear option
    @objc func enhancedForceResetIcon() {
        // Skip gentle approach, go straight to nuclear option since we know it works
        nuclearResetIcon()
    }

    // Force release of the microphone for when the system indicator gets stuck
    @objc func forceReleaseMicrophone() {
        print("DEBUG: Force releasing microphone resources")

        // First make sure we're not recording
        isRecording = false

        // Tell audio manager to stop recording and release microphone
        audioManager.stopRecording()

        // Go the extra mile and shutdown/recreate the audio engine completely
        audioManager.shutdown()

        // For system menu bar feedback
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.contentTintColor = nil
            }
            button.needsDisplay = true
        }

        print("DEBUG: Microphone resources forcibly released")
        logService.log(message: "Forced release of microphone resources", level: .info)

        // Update recording status in menu
        if let recordingStatusItem = statusBarMenu.item(at: 0) {
            recordingStatusItem.title = "Not Recording"
        }

        // Also reset our icon
        self.nuclearResetIcon()
    }

    // This extension provides an emergency fallback to fix icon tint issues
    // by completely replacing the status bar item when needed
    @objc func nuclearResetIcon() {
        print("DEBUG: NUCLEAR RESET ICON called - forced icon replacement")

        // IMPORTANT: Force recording state to false to ensure icon is reset properly
        let wasRecording = false // Force to non-recording state
        isRecording = false // Ensure state is consistent

        print("DEBUG: Current status item pointer before removal: \(statusItem)")

        // Get menu items we want to keep
        let oldMenu = statusBarMenu

        // Remove the existing status item completely
        print("DEBUG: Removing status item from system status bar")
        NSStatusBar.system.removeStatusItem(statusItem)

        // Wait for a tiny moment to ensure removal completes
        usleep(10000) // 10ms delay

        // Create a completely new status item
        print("DEBUG: Creating new status item")
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        print("DEBUG: New status item created: \(statusItem)")

        // Set up the new icon - ALWAYS as non-recording state
        if let button = statusItem.button {
            print("DEBUG: Got new status item button")
            var iconSet = false

            if #available(macOS 11.0, *) {
                let imageName = "waveform" // Always use non-recording icon
                if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Voice Recording") {
                    print("DEBUG: Setting waveform image")
                    button.image = image

                    // CRITICAL: Explicitly set tint color to nil
                    button.contentTintColor = nil

                    // Explicitly clear any other state
                    button.layer?.backgroundColor = nil
                    button.layer?.opacity = 1.0

                    iconSet = true
                    print("DEBUG: Icon image and tint set")
                }
            }

            if !iconSet {
                print("DEBUG: Setting fallback emoji icon 🎤")
                button.title = "🎤"
            }

            // Set image position
            button.imagePosition = .imageLeft

            // Force update and redraw
            button.needsDisplay = true
            button.superview?.needsDisplay = true

            print("DEBUG: Final button appearance: image=\(String(describing: button.image)), tint=\(String(describing: button.contentTintColor))")
        } else {
            print("ERROR: Could not get button from new status item!")
        }

        // Restore menu
        statusItem.menu = oldMenu

        print("DEBUG: Nuclear reset of status bar icon complete - recording state forced to: \(wasRecording)")
        logService.log(message: "Completely replaced status bar item to fix icon state", level: .info)

        // Schedule another icon check after a delay to verify the reset worked
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            if let button = self.statusItem.button {
                print("DEBUG: Icon verification after 500ms - tint=\(String(describing: button.contentTintColor))")

                if #available(macOS 11.0, *), button.contentTintColor != nil {
                    print("WARNING: Tint color still persists after nuclear reset!")
                    // Try one more extreme reset
                    self.ultraNuclearResetIcon()
                }
            }
        }
    }

    // Absolute last resort - completely recreate the status bar controller
    @objc private func ultraNuclearResetIcon() {
        print("DEBUG: ULTRA NUCLEAR reset - completely recreating status bar")

        // Remove the existing status item
        NSStatusBar.system.removeStatusItem(statusItem)

        // Wait a bit longer
        usleep(50000) // 50ms delay

        // Create a new status item with different length first
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Remove that too
        NSStatusBar.system.removeStatusItem(statusItem)

        // Wait again
        usleep(50000) // 50ms delay

        // Now create the final one
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Set up everything from scratch
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                    button.image = image
                }
            } else {
                button.title = "🎤"
            }
            button.contentTintColor = nil
            button.imagePosition = .imageLeft
            button.needsDisplay = true
        }

        // Restore menu
        setupMenu()  // Recreate the entire menu

        logService.log(message: "Ultra nuclear icon reset performed", level: .info)
    }

}
