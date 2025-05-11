import Foundation
import AVFoundation
import UserNotifications

/// A dedicated manager for all permission-related functions, to ensure consistent permission handling
/// across the application and prevent multiple permission prompts.
class PermissionManager {
    // Singleton instance
    static let shared = PermissionManager()
    
    // Permission state tracking keys - consistent across the app
    private let kMicPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
    private let kMicPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"
    private let kNotificationPermissionCheckedKey = "VocalLiquid.NotificationPermissionChecked"
    private let kNotificationPermissionGrantedKey = "VocalLiquid.NotificationPermissionGranted"
    
    // Flag to prevent simultaneous permission requests
    private var isRequestingMicPermission = false
    private var isRequestingNotificationPermission = false
    
    // Logger
    private let logService = LoggingService()
    
    private init() {
        logService.log(message: "PermissionManager initialized", level: .info)
        
        // Log the current permission status at initialization
        let micStatus = hasMicrophonePermission ? "granted" : "not granted"
        let notificationStatus = hasNotificationPermission ? "granted" : "not granted"
        logService.log(message: "Initial permission status - Microphone: \(micStatus), Notifications: \(notificationStatus)", level: .info)
        
        // In debug mode, help identify permission issues
        #if DEBUG
        if let bundleID = Bundle.main.bundleIdentifier {
            logService.log(message: "App bundle identifier: \(bundleID)", level: .info)
        } else {
            logService.log(message: "WARNING: No bundle identifier found!", level: .warning)
        }
        #endif
    }
    
    // MARK: - Permission Checking
    
    /// Check if we should skip permission prompts (for debugging or testing)
    var shouldSkipPermissions: Bool {
        // Check environment variables first
        if ProcessInfo.processInfo.environment["VOCAL_LIQUID_SKIP_PERMISSIONS"] == "1" {
            logService.log(message: "Environment flag set to skip permission prompts", level: .info)
            return true
        }
        
        // Check UserDefaults force flag (set in debug mode)
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "VocalLiquid.ForcePermissions") {
            logService.log(message: "DEBUG mode: Force-skipping permission prompts", level: .info)
            return true
        }
        #endif
        
        return false
    }
    
    /// Check if the app has microphone permission based on cached status
    var hasMicrophonePermission: Bool {
        // If we should skip permissions, simply return true
        if shouldSkipPermissions {
            return true
        }
        
        let defaults = UserDefaults.standard
        
        // First check if we already know the permission status
        if defaults.bool(forKey: kMicPermissionCheckedKey) {
            return defaults.bool(forKey: kMicPermissionGrantedKey)
        }
        
        // If we've never checked, get the current system status without prompting
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        // If the status is determined (either way), cache it
        if status == .authorized {
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(true, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            return true
        } else if status == .denied || status == .restricted {
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(false, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            return false
        }
        
        // If undetermined, we'll need to request when appropriate, but for now return false
        return false
    }
    
    /// Check if the app has notification permission based on cached status
    var hasNotificationPermission: Bool {
        // If we should skip permissions, simply return true
        if shouldSkipPermissions {
            return true
        }
        
        let defaults = UserDefaults.standard
        
        // First check if we already know the permission status
        if defaults.bool(forKey: kNotificationPermissionCheckedKey) {
            return defaults.bool(forKey: kNotificationPermissionGrantedKey)
        }
        
        // For notifications, we unfortunately can't check status without requesting,
        // so we'll return false for now
        return false
    }
    
    // MARK: - Permission Requesting
    
    /// Request microphone permission only if needed
    /// - Parameter completion: Callback with permission result
    func requestMicrophonePermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        // Return cached result if available to prevent unnecessary prompts
        let defaults = UserDefaults.standard
        
        // Skip if we're forcing permissions
        if shouldSkipPermissions {
            logService.log(message: "Skipping microphone permission request (forced grant)", level: .info)
            
            // Ensure we have the permission saved
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(true, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            
            // Complete with success
            completion(true)
            return
        }
        
        // Check if we've already determined the permission
        if defaults.bool(forKey: kMicPermissionCheckedKey) {
            let granted = defaults.bool(forKey: kMicPermissionGrantedKey)
            logService.log(message: "Using cached microphone permission: \(granted ? "granted" : "denied")", level: .info)
            completion(granted)
            return
        }
        
        // Use atomic lock to prevent multiple simultaneous requests
        objc_sync_enter(self)
        // Skip if we're already requesting
        if isRequestingMicPermission {
            objc_sync_exit(self)
            logService.log(message: "Microphone permission request already in progress", level: .info)
            completion(false)
            return
        }
        isRequestingMicPermission = true
        objc_sync_exit(self)
        
        // Get current status without requesting
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            // Already authorized
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(true, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            logService.log(message: "Microphone permission already granted", level: .info)
            isRequestingMicPermission = false
            completion(true)
            
        case .notDetermined:
            // Need to request
            logService.log(message: "Requesting microphone permission", level: .info)
            
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard let self = self else { return }
                
                // Save the result
                defaults.set(true, forKey: self.kMicPermissionCheckedKey)
                defaults.set(granted, forKey: self.kMicPermissionGrantedKey)
                defaults.synchronize()
                
                self.logService.log(message: "Microphone permission request completed: \(granted ? "granted" : "denied")", level: .info)
                self.isRequestingMicPermission = false
                
                // Notify on main thread
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("MicrophonePermissionStatusChanged"),
                        object: nil,
                        userInfo: ["granted": granted]
                    )
                    completion(granted)
                }
            }
            
        case .denied, .restricted:
            // Already denied
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(false, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            logService.log(message: "Microphone permission previously denied", level: .warning)
            isRequestingMicPermission = false
            completion(false)
            
        @unknown default:
            // Handle unknown state (future-proofing)
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(false, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            logService.log(message: "Unknown microphone permission status", level: .warning)
            isRequestingMicPermission = false
            completion(false)
        }
    }
    
    /// Request notification permission only if needed
    /// - Parameter completion: Callback with permission result
    func requestNotificationPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        // Return cached result if available to prevent unnecessary prompts
        let defaults = UserDefaults.standard
        
        // Skip if we're forcing permissions
        if shouldSkipPermissions {
            logService.log(message: "Skipping notification permission request (forced grant)", level: .info)
            
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
            logService.log(message: "Using cached notification permission: \(granted ? "granted" : "denied")", level: .info)
            completion(granted)
            return
        }
        
        // Use atomic lock to prevent multiple simultaneous requests
        objc_sync_enter(self)
        // Skip if we're already requesting
        if isRequestingNotificationPermission {
            objc_sync_exit(self)
            logService.log(message: "Notification permission request already in progress", level: .info)
            completion(false)
            return
        }
        isRequestingNotificationPermission = true
        objc_sync_exit(self)
        
        // Request permission (we can't check status without requesting on macOS)
        logService.log(message: "Requesting notification permission", level: .info)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            guard let self = self else { return }
            
            // Save the result
            defaults.set(true, forKey: self.kNotificationPermissionCheckedKey)
            defaults.set(granted, forKey: self.kNotificationPermissionGrantedKey)
            defaults.synchronize()
            
            if let error = error {
                self.logService.log(message: "Notification permission error: \(error.localizedDescription)", level: .error)
            } else {
                self.logService.log(message: "Notification permission request completed: \(granted ? "granted" : "denied")", level: .info)
            }
            
            self.isRequestingNotificationPermission = false
            
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
    
    // MARK: - Debugging Utilities
    
    /// Force-set permission status (for testing or recovery)
    func forceSetPermissions(microphone: Bool, notification: Bool) {
        let defaults = UserDefaults.standard
        
        defaults.set(true, forKey: kMicPermissionCheckedKey)
        defaults.set(microphone, forKey: kMicPermissionGrantedKey)
        
        defaults.set(true, forKey: kNotificationPermissionCheckedKey)
        defaults.set(notification, forKey: kNotificationPermissionGrantedKey)
        
        defaults.synchronize()
        
        logService.log(message: "Force-set permissions - Microphone: \(microphone), Notifications: \(notification)", level: .info)
    }
    
    /// Reset cached permission status to force a fresh check
    func resetPermissionCache() {
        let defaults = UserDefaults.standard
        
        defaults.removeObject(forKey: kMicPermissionCheckedKey)
        defaults.removeObject(forKey: kMicPermissionGrantedKey)
        defaults.removeObject(forKey: kNotificationPermissionCheckedKey)
        defaults.removeObject(forKey: kNotificationPermissionGrantedKey)
        
        defaults.synchronize()
        
        logService.log(message: "Reset permission cache", level: .info)
    }
    
    /// Debug-print current permission status
    func logPermissionStatus() {
        let defaults = UserDefaults.standard
        
        let micChecked = defaults.bool(forKey: kMicPermissionCheckedKey)
        let micGranted = defaults.bool(forKey: kMicPermissionGrantedKey)
        let notifChecked = defaults.bool(forKey: kNotificationPermissionCheckedKey)
        let notifGranted = defaults.bool(forKey: kNotificationPermissionGrantedKey)
        
        logService.log(message: "===== PERMISSION STATUS =====", level: .info)
        logService.log(message: "Microphone checked: \(micChecked)", level: .info)
        logService.log(message: "Microphone granted: \(micGranted)", level: .info)
        logService.log(message: "Notification checked: \(notifChecked)", level: .info)
        logService.log(message: "Notification granted: \(notifGranted)", level: .info)
        
        // Also log current system status
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        logService.log(message: "Current system microphone status: \(micStatus.rawValue)", level: .info)
        logService.log(message: "===========================", level: .info)
    }
}

// Extension to AVCaptureDevice for better debugging
extension AVCaptureDevice {
    /// Get a stringified representation of the authorization status for debugging
    static func debugAuthorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        let status = authorizationStatus(for: mediaType)
        
        // Log the status for debugging
        var statusString = "unknown"
        switch status {
        case .notDetermined:
            statusString = "notDetermined"
        case .restricted:
            statusString = "restricted"
        case .denied:
            statusString = "denied"
        case .authorized:
            statusString = "authorized"
        @unknown default:
            statusString = "unknown"
        }
        
        print("DEBUG: AVCaptureDevice authorization status for \(mediaType): \(statusString) (\(status.rawValue))")
        return status
    }
}