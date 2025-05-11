import SwiftUI
import AppKit
import UserNotifications
import AVFoundation

@main
struct VocalLiquidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We don't need any visible windows since this is a background-only app
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // Use StatusBarController to handle menu bar icon
    private var statusBarController: StatusBarController?
    private var whisperManager: WhisperManager?
    private var isRecording = false
    private let logger = LoggingService()
    
    // Using a manual implementation since we can't access PermissionManager yet
    // We'll duplicate the basic functionality here until we can properly organize the code
    private var hasNotificationPermission: Bool {
        let defaults = UserDefaults.standard
        let kNotificationPermissionCheckedKey = "VocalLiquid.NotificationPermissionChecked"
        let kNotificationPermissionGrantedKey = "VocalLiquid.NotificationPermissionGranted"

        // Check if we should skip permissions (for testing)
        if ProcessInfo.processInfo.environment["VOCAL_LIQUID_SKIP_PERMISSIONS"] == "1" ||
           UserDefaults.standard.bool(forKey: "VocalLiquid.ForcePermissions") {
            return true
        }

        // Return cached result if available
        if defaults.bool(forKey: kNotificationPermissionCheckedKey) {
            return defaults.bool(forKey: kNotificationPermissionGrantedKey)
        }

        return false
    }

    private var shouldSkipPermissions: Bool {
        return ProcessInfo.processInfo.environment["VOCAL_LIQUID_SKIP_PERMISSIONS"] == "1" ||
               UserDefaults.standard.bool(forKey: "VocalLiquid.ForcePermissions")
    }

    private func requestNotificationPermissionIfNeeded(_ completion: @escaping (Bool) -> Void) {
        let defaults = UserDefaults.standard
        let kNotificationPermissionCheckedKey = "VocalLiquid.NotificationPermissionChecked"
        let kNotificationPermissionGrantedKey = "VocalLiquid.NotificationPermissionGranted"

        // Skip if we're forcing permissions
        if shouldSkipPermissions {
            logger.log(message: "Skipping notification permission request (forced grant)", level: .info)

            // Ensure we have the permission saved
            defaults.set(true, forKey: kNotificationPermissionCheckedKey)
            defaults.set(true, forKey: kNotificationPermissionGrantedKey)
            defaults.synchronize()

            // Complete with success
            completion(true)
            return
        }

        // Check if we've already determined the permission
        if defaults.bool(forKey: kNotificationPermissionCheckedKey) {
            let granted = defaults.bool(forKey: kNotificationPermissionGrantedKey)
            logger.log(message: "Using cached notification permission: \(granted ? "granted" : "denied")", level: .info)
            completion(granted)
            return
        }

        // Request permission (we can't check status without requesting on macOS)
        logger.log(message: "Requesting notification permission", level: .info)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            guard let self = self else { return }

            // Save the result
            defaults.set(true, forKey: kNotificationPermissionCheckedKey)
            defaults.set(granted, forKey: kNotificationPermissionGrantedKey)
            defaults.synchronize()

            if let error = error {
                self.logger.log(message: "Notification permission error: \(error.localizedDescription)", level: .error)
            } else {
                self.logger.log(message: "Notification permission request completed: \(granted ? "granted" : "denied")", level: .info)
            }

            // Notify on main thread
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NotificationPermissionStatusChanged"),
                    object: nil,
                    userInfo: ["granted": granted]
                )
                completion(granted)
            }
        }
    }

    private func forceSetPermissions(microphone: Bool, notification: Bool) {
        let defaults = UserDefaults.standard
        let kMicPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
        let kMicPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"
        let kNotificationPermissionCheckedKey = "VocalLiquid.NotificationPermissionChecked"
        let kNotificationPermissionGrantedKey = "VocalLiquid.NotificationPermissionGranted"

        defaults.set(true, forKey: kMicPermissionCheckedKey)
        defaults.set(microphone, forKey: kMicPermissionGrantedKey)

        defaults.set(true, forKey: kNotificationPermissionCheckedKey)
        defaults.set(notification, forKey: kNotificationPermissionGrantedKey)

        defaults.synchronize()

        logger.log(message: "Force-set permissions - Microphone: \(microphone), Notifications: \(notification)", level: .info)
    }

    private func logPermissionStatus() {
        let defaults = UserDefaults.standard
        let kMicPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
        let kMicPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"
        let kNotificationPermissionCheckedKey = "VocalLiquid.NotificationPermissionChecked"
        let kNotificationPermissionGrantedKey = "VocalLiquid.NotificationPermissionGranted"

        let micChecked = defaults.bool(forKey: kMicPermissionCheckedKey)
        let micGranted = defaults.bool(forKey: kMicPermissionGrantedKey)
        let notifChecked = defaults.bool(forKey: kNotificationPermissionCheckedKey)
        let notifGranted = defaults.bool(forKey: kNotificationPermissionGrantedKey)

        logger.log(message: "===== PERMISSION STATUS =====", level: .info)
        logger.log(message: "Microphone checked: \(micChecked)", level: .info)
        logger.log(message: "Microphone granted: \(micGranted)", level: .info)
        logger.log(message: "Notification checked: \(notifChecked)", level: .info)
        logger.log(message: "Notification granted: \(notifGranted)", level: .info)
        logger.log(message: "===========================", level: .info)
    }
    
    // Using the singleton AudioManager
    private var audioManager: AudioManager {
        return AudioManager.shared
    }
    
    // Track shown notifications by type
    private var notificationsShown: Set<String> = []
    private let maxNotificationsPerSession = 5  // Limit total notifications
    private let kNotificationsShownKey = "VocalLiquid.NotificationsShown"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the logger first
        logger.log(message: "VocalLiquid application started", level: .info)
        print("VocalLiquid started as background application")
        
        // Log the current bundle ID for debugging permission issues
        if let bundleID = Bundle.main.bundleIdentifier {
            logger.log(message: "App bundle identifier: \(bundleID)", level: .info)
        } else {
            logger.log(message: "WARNING: No bundle identifier found!", level: .warning)
        }
        
        // Log current permission status
        logPermissionStatus()

        // Force test mode permissions to avoid multiple permission prompts during testing/debugging
        #if DEBUG
        // Option to force permissions in debug mode
        if UserDefaults.standard.bool(forKey: "VocalLiquid.ForcePermissions") {
            logger.log(message: "DEBUG mode: Force-setting permissions", level: .info)
            forceSetPermissions(microphone: true, notification: true)
        }
        #endif
        
        // Clear old notification tracking data
        // This helps prevent accumulation of old notification types between app launches
        // but keeps the permission status
        UserDefaults.standard.set([String](), forKey: kNotificationsShownKey)
        notificationsShown.removeAll()
        
        // Initialize managers (don't request permissions on init)
        print("Initializing managers...")
        whisperManager = WhisperManager()
        
        // Create the status bar controller to handle menu bar icon
        print("Creating status bar controller...")
        statusBarController = StatusBarController()
        
        // Set up notification listeners
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingToggle),
            name: Notification.Name("RecordingStatusChanged"),
            object: nil
        )
        
        // Hide the dock icon since this is a background app
        // Use a less restrictive mode during debugging
        #if DEBUG
        print("DEBUG: Setting activation policy to .accessory for better debugging visibility")
        NSApp.setActivationPolicy(.accessory) // More visible during debugging
        #else
        print("RELEASE: Setting activation policy to .prohibited for production")
        NSApp.setActivationPolicy(.prohibited) // Most invisible mode for production
        #endif
        
        // Prevent the app from showing any windows at launch
        for window in NSApplication.shared.windows {
            window.close()
        }
        
        // Only request notification permission when we need to show a notification
        // Instead of requesting on launch, request when we need to show the first notification
        // This avoids unnecessary permission prompts on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Check if we need to show the welcome notification
            if !self.notificationsShown.contains("app_launch") {
                // Only request notification permission if we're actually going to show a notification
                // and don't already have permission
                if self.hasNotificationPermission {
                    // Already have permission, show notification directly
                    self.showNotification(
                        title: "VocalLiquid Ready",
                        body: "Press Command-Shift-R to start/stop recording.",
                        type: "app_launch"
                    )
                } else if !self.shouldSkipPermissions {
                    // Only request permission if not in bypass mode
                    self.requestNotificationPermissionIfNeeded { granted in
                        if granted {
                            self.showNotification(
                                title: "VocalLiquid Ready",
                                body: "Press Command-Shift-R to start/stop recording.",
                                type: "app_launch"
                            )
                        }
                    }
                }
            }
            print("VocalLiquid is running in background mode")
            self.logger.log(message: "VocalLiquid ready - using Command-Shift-R hotkey", level: .info)
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up resources
        logger.log(message: "VocalLiquid application will terminate", level: .info)
        
        // Proper shutdown of audio engine
        audioManager.shutdown()
    }
    
    // Show a notification with deduplication and rate limiting
    private func showNotification(title: String, body: String, type: String? = nil, force: Bool = false) {
        // Skip if notification permission not granted
        if !hasNotificationPermission && !shouldSkipPermissions {
            logger.log(message: "Skipping notification - permission not granted", level: .info)
            return
        }
        
        // Deduplicate notifications by type if type is provided
        if let type = type, !force {
            // If we've already shown this type of notification and it's not forced, skip it
            if notificationsShown.contains(type) {
                logger.log(message: "Skipping duplicate notification of type: \(type)", level: .info)
                return
            }
            // Mark this notification type as shown
            notificationsShown.insert(type)
            
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(Array(notificationsShown), forKey: kNotificationsShownKey)
        }
        
        // Check if we're within our notification limit
        // Critical notifications (force=true) always get shown
        if !force && notificationsShown.count > maxNotificationsPerSession {
            logger.log(message: "Notification limit reached. Skipping notification: \(title)", level: .info)
            return
        }
        
        logger.log(message: "Showing notification: \(title)", level: .info)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        // Use a consistent identifier for notifications of the same type to replace
        // any existing notification of that type
        let identifier = type ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        // Remove pending notifications to avoid overwhelming the user
        if !force && identifier != "recording_status" {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    // Toggle recording functionality (moved from StatusBarController)
    // Handler for recording status notifications from StatusBarController
    @objc private func handleRecordingToggle(_ notification: Notification) {
        if let isRec = notification.userInfo?["isRecording"] as? Bool {
            print("Received recording state change notification: \(isRec)")
            isRecording = isRec
            
            // Clear recording status notification
            clearNotificationType("recording_status")
            
            // Show appropriate notification
            if isRec {
                showNotification(
                    title: "Recording Started",
                    body: "Speak now. Press Command-Shift-R to stop.",
                    type: "recording_status",
                    force: true
                )
            } else {
                // If we're stopping recording, handle the transcription
                handleTranscription()
            }
        }
    }
    
    private func handleTranscription() {
        showNotification(
            title: "Recording Stopped",
            body: "Transcribing audio...",
            type: "recording_status",
            force: true
        )
        
        // Get audio samples
        let samples = audioManager.getSamplesForTranscription()
        
        // Check if we have samples
        if samples.isEmpty {
            showNotification(
                title: "Transcription Failed",
                body: "No audio was recorded. Please try again.",
                type: "transcription_error",
                force: true
            )
            logger.log(message: "Transcription failed: No audio samples collected", level: .error)
            return
        }
        
        // Transcribe the audio
        whisperManager?.transcribeAudio(samples: samples) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let transcription):
                self.copyToClipboard(text: transcription)
                self.showNotification(
                    title: "Transcription Complete",
                    body: "Text copied to clipboard: \(transcription.prefix(50))...",
                    type: "transcription_result",
                    force: true
                )
                self.logger.log(message: "Transcription complete", level: .info)
                
            case .failure(let error):
                self.showNotification(
                    title: "Transcription Failed",
                    body: "Error: \(error.localizedDescription)",
                    type: "transcription_error",
                    force: true
                )
                self.logger.log(message: "Transcription error: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    // Helper to clear notification tracking for specific types
    private func clearNotificationType(_ type: String) {
        notificationsShown.remove(type)
        
        // Persist changes to UserDefaults
        UserDefaults.standard.set(Array(notificationsShown), forKey: kNotificationsShownKey)
        
        logger.log(message: "Cleared notification type: \(type)", level: .info)
    }
    
    // Clear all notification tracking
    private func clearAllNotificationTypes() {
        notificationsShown.removeAll()
        
        // Persist changes to UserDefaults
        UserDefaults.standard.set(Array(notificationsShown), forKey: kNotificationsShownKey)
        
        logger.log(message: "Cleared all notification types", level: .info)
    }
}