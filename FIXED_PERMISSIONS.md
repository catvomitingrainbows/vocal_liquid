# VocalLiquid Permission Fix

This document explains the solution to the multiple microphone permission prompt issue in VocalLiquid.

## Problem

The app was experiencing multiple permission prompts for microphone access:
1. Seven permission prompts when launching the app
2. Additional prompts when using the Command-Shift-R hotkey
3. Recording wouldn't stop properly when toggling the hotkey
4. Menu bar icon would remain in "recording" state even after stopping recording

## Root Causes

After investigating, we found the following issues:

1. **AVAudioSession API Misuse**: Trying to use iOS-specific AVAudioSession APIs on macOS, which aren't available
2. **Audio Engine Mismanagement**: Creating new engine instances or reconfiguring the engine between recordings
3. **State Tracking Issues**: Misalignment between various isRecording states
4. **Permission Handling**: Ineffective permission caching and synchronization
5. **Architectural Issues**: Two separate components (AppDelegate and StatusBarController) managing audio independently
6. **Asynchronous Permission Checks**: Multiple components requesting permissions asynchronously at the same time

## Solution

We implemented a comprehensive fix with the following components:

### 1. macOS-Compatible AudioManager

Created a singleton AudioManager that:
- Uses AVCaptureDevice for permission management (macOS compatible)
- Maintains a persistent audio engine instance
- Properly handles recording state
- Efficiently manages audio engine without unnecessary restarts
- Caches permission status in UserDefaults
- Checks current permission status before requesting it

### 2. Improved Recording Toggle Logic

Updated the toggle logic to:
- Check both local and AudioManager recording states
- Add proper empty audio sample detection
- Fix state tracking between stop/start operations
- Properly remove audio taps when stopping recording

### 3. Unified Architecture

Consolidated the audio management:
- Made StatusBarController use the singleton AudioManager
- Created notification-based communication between components
- Added proper state synchronization between UI and audio engine
- Connected the menu bar icon state to the AudioManager recording state

### 4. Proper Entitlements

Added proper entitlements for microphone access:
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

### 5. Permission Management

- Implemented reliable permission tracking using AVCaptureDevice API
- Added proper error handling for permission denied cases
- Created consistent permission checking in both the AudioManager and app delegate
- Made permission checking synchronous to avoid multiple permission dialogs
- Cache permission results in UserDefaults to avoid repeated checks
- Check current authorization status before requesting new permissions

## Key Code Changes

### AudioManager.swift

```swift
class AudioManager {
    // Singleton instance
    static let shared = AudioManager()

    // Audio components
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private var audioSamples: [Float] = []

    // State tracking
    private(set) var isRecording = false
    private var isEngineRunning = false
    private var isSetup = false

    // Permission keys
    private let kMicPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
    private let kMicPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"

    // Private initializer for singleton
    private init() {
        // Initial setup of audio components without activating
        setupAudioComponents()

        // For macOS, use AVCaptureDevice API to check permissions
        requestMicrophonePermissionIfNeeded()
    }

    // ...

    /// Request microphone permission if needed (macOS implementation)
    private func requestMicrophonePermissionIfNeeded() {
        let defaults = UserDefaults.standard

        // Skip if we've already checked
        if defaults.bool(forKey: kMicPermissionCheckedKey) {
            return
        }

        // Check if we already have permission (happens when the user has already granted it)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized {
            // Already authorized, just save the result
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(true, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            return
        } else if status == .denied || status == .restricted {
            // Permission already denied, save the result
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(false, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            return
        }

        // Only if status is .notDetermined, request permission explicitly
        if status == .notDetermined {
            // Use a semaphore to wait synchronously
            let semaphore = DispatchSemaphore(value: 0)
            var permissionGranted = false

            // Request on a background thread to not block the main thread
            DispatchQueue.global(qos: .userInitiated).async {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    permissionGranted = granted
                    semaphore.signal()
                }
            }

            // Wait for up to 1 second for permission dialog to complete
            _ = semaphore.wait(timeout: .now() + 1.0)

            // Save the result
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(permissionGranted, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
        }
    }

    /// Start recording audio
    func startRecording() -> Bool {
        guard !isRecording else {
            return false
        }

        // Only start the engine if not already running
        if !isEngineRunning {
            try audioEngine.start()
            isEngineRunning = true
        }

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, when) in
            guard let self = self, self.isRecording else { return }

            // Process audio...
        }

        isRecording = true
        // Post notification that recording started
        NotificationCenter.default.post(
            name: Notification.Name("RecordingStatusChanged"),
            object: nil,
            userInfo: ["isRecording": true]
        )
        return true
    }

    /// Stop recording audio
    func stopRecording() {
        guard isRecording else {
            return
        }

        // Set isRecording to false first to stop collecting samples
        isRecording = false

        // Remove tap but don't stop the engine
        inputNode?.removeTap(onBus: 0)

        // Post notification that recording stopped
        NotificationCenter.default.post(
            name: Notification.Name("RecordingStatusChanged"),
            object: nil,
            userInfo: ["isRecording": false]
        )
    }

    // ...
}
```

### VocalLiquidApp.swift

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    // Use StatusBarController to handle menu bar icon
    private var statusBarController: StatusBarController?
    private var whisperManager: WhisperManager?
    private var isRecording = false

    // Using the singleton AudioManager instead of creating instances
    private var audioManager: AudioManager {
        return AudioManager.shared
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize whisper
        whisperManager = WhisperManager()

        // Create the status bar controller to handle menu bar icon
        statusBarController = StatusBarController()

        // Listen for recording state changes from StatusBarController
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingToggle),
            name: Notification.Name("RecordingStatusChanged"),
            object: nil
        )
    }

    // Handler for recording status notifications from StatusBarController
    @objc private func handleRecordingToggle(_ notification: Notification) {
        if let isRec = notification.userInfo?["isRecording"] as? Bool {
            isRecording = isRec

            // Show appropriate notification
            if isRec {
                showNotification(title: "Recording Started", body: "Press Command-Shift-R to stop.")
            } else {
                // If we're stopping recording, handle the transcription
                handleTranscription()
            }
        }
    }

    private func handleTranscription() {
        // Get audio samples and check if empty
        let samples = audioManager.getSamplesForTranscription()
        if samples.isEmpty {
            showNotification(title: "Transcription Failed", body: "No audio was recorded")
            return
        }

        // Transcribe the audio
        whisperManager?.transcribeAudio(samples: samples) { result in
            switch result {
            case .success(let transcription):
                self.copyToClipboard(text: transcription)
                self.showNotification(title: "Transcription Complete",
                                      body: "Text copied to clipboard")
            case .failure(let error):
                self.showNotification(title: "Transcription Failed",
                                      body: "Error: \(error.localizedDescription)")
            }
        }
    }
}
```

### StatusBarController.swift

```swift
class StatusBarController {
    // Various services needed
    private let hotkeyManager = HotkeyManager()

    // Use the singleton AudioManager instead of AudioEngineManager
    private var audioManager: AudioManager {
        return AudioManager.shared
    }

    private let whisperManager = WhisperManager()
    private let logService = LoggingService()

    // Status bar components
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var statusBarMenu: NSMenu
    private var isRecording = false

    // Setup the hotkey
    private func setupHotkeys() {
        // Register for Command-Shift-R by default
        hotkeyManager.registerHotkey(keyCode: 15, modifiers: [.command, .shift]) { [weak self] in
            self?.toggleRecording()
        }
    }

    // Handle recording toggle
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Start the recording in AudioManager
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
                    button.title = "🔴"
                }
            }
        }
    }

    private func stopRecording() {
        // Stop the recording in AudioManager
        audioManager.stopRecording()
        isRecording = false

        // Update status bar icon to show idle state
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voice Recording") {
                    button.image = image
                    button.contentTintColor = nil
                }
            } else {
                button.title = "🎤"
            }
        }
    }
}
```

## Testing

To test the fix:
1. Run `./reset_permissions.sh` to reset permissions
2. Run `./build_background.sh` to build and launch the app
3. You should only get ONE permission prompt on first launch
4. Press Command-Shift-R to start recording - the menu bar icon should turn red
5. Press Command-Shift-R again to stop recording - the menu bar icon should return to normal
6. You should see a notification for the transcription

## Utility Scripts

- `debug_audio.sh`: Adds debug logging for troubleshooting
- `apply_fixes.sh`: Applies all the fixes
- `reset_permissions.sh`: Resets permissions in the TCC database for testing