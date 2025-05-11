import Foundation
import AVFoundation
import AppKit

/// Singleton manager for handling audio recording with a persistent audio engine
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
    
    // Logger
    private let logService = LoggingService()
    
    // Local permission handling to avoid dependencies
    private let kMicPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
    private let kMicPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"

    // Flag to prevent multiple concurrent permission requests
    private var isRequestingPermission = false
    
    // Private initializer for singleton
    private init() {
        logService.log(message: "AudioManager initializing", level: .info)
        
        // Initial setup of audio components without activating
        setupAudioComponents()
        
        // Log bundle ID for debugging
        if let bundleID = Bundle.main.bundleIdentifier {
            logService.log(message: "Current bundle identifier: \(bundleID)", level: .info)
        } else {
            logService.log(message: "Warning: No bundle identifier found!", level: .warning)
        }
        
        // Print current permission status for debugging
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        logService.log(message: "Initial microphone permission status: \(status.rawValue)", level: .info)
        
        logService.log(message: "AudioManager initialized with persistent audio engine", level: .info)
    }
    
    // MARK: - Setup
    
    /// Set up audio components without activating the engine
    private func setupAudioComponents() {
        guard !isSetup else { return }
        
        inputNode = audioEngine.inputNode
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: 16000, // Whisper expects 16kHz
                                  channels: 1,       // Whisper expects mono
                                  interleaved: false)
        
        guard inputNode != nil, audioFormat != nil else {
            logService.log(message: "Error setting up audio engine components", level: .error)
            return
        }
        
        // Prepare engine once to initialize all components
        audioEngine.prepare()
        
        isSetup = true
        logService.log(message: "Audio components setup successfully (engine not running)", level: .info)
    }
    
    // MARK: - Permission Properties

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

    /// Check if microphone permission is granted based on cached status
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

    /// Request microphone permission only if needed
    private func requestMicrophonePermissionIfNeeded(_ completion: @escaping (Bool) -> Void) {
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
        if isRequestingPermission {
            objc_sync_exit(self)
            logService.log(message: "Microphone permission request already in progress", level: .info)
            completion(false)
            return
        }
        isRequestingPermission = true
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
            isRequestingPermission = false
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
                self.isRequestingPermission = false

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
            isRequestingPermission = false
            completion(false)

        @unknown default:
            // Handle unknown state (future-proofing)
            defaults.set(true, forKey: kMicPermissionCheckedKey)
            defaults.set(false, forKey: kMicPermissionGrantedKey)
            defaults.synchronize()
            logService.log(message: "Unknown microphone permission status", level: .warning)
            isRequestingPermission = false
            completion(false)
        }
    }
    
    // MARK: - Recording Control
    
    /// Start recording audio
    func startRecording() -> Bool {
        guard !isRecording else {
            logService.log(message: "Already recording, ignoring startRecording call", level: .info)
            return false
        }

        // Check if we already have permission or skip permission check
        if hasMicrophonePermission || shouldSkipPermissions {
            // Already have permission or testing mode, start recording immediately
            return startRecordingWithPermission()
        } else {
            // Need to request permission first
            logService.log(message: "Requesting microphone permission before recording", level: .info)

            // Request permission
            requestMicrophonePermissionIfNeeded { [weak self] granted in
                guard let self = self else { return }

                guard granted else {
                    self.logService.log(message: "Cannot record: Microphone permission denied", level: .warning)
                    return
                }

                // Start recording on the main thread
                DispatchQueue.main.async {
                    _ = self.startRecordingWithPermission()
                }
            }

            // Return false for now, recording will start asynchronously if permission is granted
            return false
        }
    }
    
    /// Start recording with permission already granted
    private func startRecordingWithPermission() -> Bool {
        print("DEBUG: startRecordingWithPermission called")
        // Reset samples for new recording
        audioSamples.removeAll()
        print("DEBUG: Audio samples reset")

        // Reset and restart the engine every time to ensure a clean state
        // First stop the engine if it's running
        if isEngineRunning {
            print("DEBUG: Stopping previous audio engine instance")
            audioEngine.stop()
            isEngineRunning = false
        }

        // Reset audio components if needed
        if !isSetup {
            print("DEBUG: Setting up audio components")
            setupAudioComponents()
        }

        do {
            // Start the engine fresh
            print("DEBUG: Starting fresh audio engine instance")
            try audioEngine.start()
            isEngineRunning = true
            print("DEBUG: Audio engine started successfully")
            logService.log(message: "Audio engine started successfully", level: .info)
        } catch {
            print("ERROR: Failed to start audio engine: \(error.localizedDescription)")
            logService.log(message: "Error starting audio engine: \(error.localizedDescription)", level: .error)
            return false
        }
        
        // Install tap on input node
        guard let inputNode = inputNode, let targetFormat = audioFormat else {
            logService.log(message: "Error: Audio components not available", level: .error)
            return false
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, when) in
            guard let self = self, self.isRecording else { return }
            
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                self.logService.log(message: "Error creating format converter", level: .error)
                return
            }
            
            // Calculate capacity for the output buffer
            let frameCapacity = AVAudioFrameCount(targetFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate)
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
                self.logService.log(message: "Error creating PCM buffer for conversion", level: .error)
                return
            }
            
            // Set the frame length of the output buffer
            pcmBuffer.frameLength = frameCapacity
            
            var error: NSError? = nil
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            let status = converter.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)
            
            guard status != .error else {
                self.logService.log(message: "Error during audio conversion: \(error?.localizedDescription ?? "unknown")", level: .error)
                return
            }
            
            // Ensure the buffer has float channel data
            guard let channelData = pcmBuffer.floatChannelData else {
                self.logService.log(message: "PCM Buffer does not contain float channel data", level: .error)
                return
            }
            
            // Append converted samples
            let frameLength = Int(pcmBuffer.frameLength)
            // Access the first channel (index 0) for mono audio
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            // Append samples
            self.audioSamples.append(contentsOf: samples)
        }
        
        isRecording = true
        logService.log(message: "Recording started successfully", level: .info)
        return true
    }
    
    /// Stop recording audio
    func stopRecording() {
        guard isRecording else {
            logService.log(message: "Not recording, ignoring stopRecording call", level: .info)
            return
        }

        print("DEBUG: AudioManager.stopRecording - Completely stopping audio engine")

        // Set isRecording to false first to stop collecting samples
        isRecording = false

        // Remove tap
        inputNode?.removeTap(onBus: 0)

        // IMPORTANT: Actually stop the audio engine to release the microphone
        // This should turn off the orange mic indicator in the menu bar
        audioEngine.stop()
        isEngineRunning = false

        print("DEBUG: Audio engine and recording fully stopped")
        logService.log(message: "Recording stopped successfully and audio engine stopped", level: .info)
    }
    
    /// Get audio samples for transcription
    func getSamplesForTranscription() -> [Float] {
        return audioSamples
    }
    
    // MARK: - Cleanup

    /// Shutdown the audio engine when no longer needed (app termination)
    func shutdown() {
        if isRecording {
            stopRecording()
        }

        if isEngineRunning {
            audioEngine.stop()
            isEngineRunning = false
        }

        logService.log(message: "Audio engine shutdown successfully", level: .info)
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