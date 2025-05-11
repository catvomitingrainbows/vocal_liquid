import Foundation

// Constants for permission keys to ensure they're used consistently across the app
struct PermissionKeys {
    static let micPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
    static let micPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"
    static let notificationPermissionCheckedKey = "VocalLiquid.NotificationPermissionChecked"
    static let notificationPermissionGrantedKey = "VocalLiquid.NotificationPermissionGranted"
    static let notificationsShownKey = "VocalLiquid.NotificationsShown"
    
    // Helper to print current permission status
    static func printPermissionStatus() {
        let defaults = UserDefaults.standard
        
        print("======= PERMISSION STATUS =======")
        print("Mic permission checked: \(defaults.bool(forKey: micPermissionCheckedKey))")
        print("Mic permission granted: \(defaults.bool(forKey: micPermissionGrantedKey))")
        print("Notification permission checked: \(defaults.bool(forKey: notificationPermissionCheckedKey))")
        print("Notification permission granted: \(defaults.bool(forKey: notificationPermissionGrantedKey))")
        
        // Print notifications shown
        if let notificationsShown = defaults.stringArray(forKey: notificationsShownKey) {
            print("Notifications shown (\(notificationsShown.count)): \(notificationsShown)")
        } else {
            print("No notifications shown yet")
        }
        print("================================")
    }
    
    // Forcibly set all permissions to granted (for testing)
    static func forceSetPermissions() {
        let defaults = UserDefaults.standard
        
        // Set microphone permissions to granted
        defaults.set(true, forKey: micPermissionCheckedKey)
        defaults.set(true, forKey: micPermissionGrantedKey)
        
        // Set notification permissions to granted
        defaults.set(true, forKey: notificationPermissionCheckedKey)
        defaults.set(true, forKey: notificationPermissionGrantedKey)
        
        // Set some shown notifications
        defaults.set(["app_launch"], forKey: notificationsShownKey)
        
        // Explicitly synchronize
        defaults.synchronize()
        
        print("Permissions forcibly set to 'granted' state")
        printPermissionStatus()
    }
    
    // Reset all permissions (for testing)
    static func resetPermissions() {
        let defaults = UserDefaults.standard
        
        // Remove all permission keys
        defaults.removeObject(forKey: micPermissionCheckedKey)
        defaults.removeObject(forKey: micPermissionGrantedKey)
        defaults.removeObject(forKey: notificationPermissionCheckedKey)
        defaults.removeObject(forKey: notificationPermissionGrantedKey)
        defaults.removeObject(forKey: notificationsShownKey)
        
        // Explicitly synchronize
        defaults.synchronize()
        
        print("All permissions have been reset")
        printPermissionStatus()
    }
}