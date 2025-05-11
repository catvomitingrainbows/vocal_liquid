import Foundation
import Carbon
import Cocoa

class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID()
    private var callback: (() -> Void)?
    private let logService = LoggingService()
    
    deinit {
        unregisterHotkey()
    }
    
    func registerHotkey(keyCode: Int, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        // First unregister any existing hotkey
        unregisterHotkey()
        
        // Store the callback
        self.callback = action
        
        // Create a unique ID for this hotkey
        // Convert "VCLQ" to OSType using ASCII values
        let signature = OSType(
            (UInt32(UInt8(ascii: "V")) << 24) |
            (UInt32(UInt8(ascii: "C")) << 16) |
            (UInt32(UInt8(ascii: "L")) << 8) |
            UInt32(UInt8(ascii: "Q"))
        )
        hotKeyID.signature = signature // Vocal Liquid signature
        hotKeyID.id = UInt32(1)
        
        // Convert NSEvent modifier flags to Carbon modifier flags
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        
        // Create the event type spec
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Install the event handler
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                
                // Extract the hotkey information
                var hkID = EventHotKeyID()
                let err = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                
                if err == noErr {
                    // Call the registered callback if this is our hotkey
                    // Convert "VCLQ" to OSType using ASCII values
                    let signature = OSType(
                        (UInt32(UInt8(ascii: "V")) << 24) |
                        (UInt32(UInt8(ascii: "C")) << 16) |
                        (UInt32(UInt8(ascii: "L")) << 8) |
                        UInt32(UInt8(ascii: "Q"))
                    )
                    if hkID.signature == signature {
                        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                        manager.hotkeyPressed()
                    }
                }
                
                return CallNextEventHandler(nextHandler, theEvent)
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        if status != noErr {
            logService.log(message: "Error installing event handler: \(status)", level: .error)
            return
        }
        
        // Register the hotkey
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus != noErr {
            logService.log(message: "Error registering hotkey: \(registerStatus)", level: .error)
            return
        }
        
        logService.log(message: "Hotkey registered successfully: keyCode=\(keyCode), modifiers=\(modifiers.rawValue)", level: .info)
    }
    
    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status != noErr {
                logService.log(message: "Error unregistering hotkey: \(status)", level: .error)
            } else {
                logService.log(message: "Hotkey unregistered successfully", level: .info)
            }
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            let status = RemoveEventHandler(eventHandler)
            if status != noErr {
                logService.log(message: "Error removing event handler: \(status)", level: .error)
            }
            self.eventHandler = nil
        }
    }
    
    private func hotkeyPressed() {
        print("HOTKEY DEBUG: Hotkey pressed and detected!")
        DispatchQueue.main.async { [weak self] in
            print("HOTKEY DEBUG: Executing callback on main thread")
            self?.callback?()
            print("HOTKEY DEBUG: Callback execution completed")
        }
    }
}