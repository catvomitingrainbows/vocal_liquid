#!/bin/bash
set -e

echo "=== VocalLiquid Audio Debug Script ==="
echo "This script will reset permissions and run the app with enhanced debug output"

# First, reset permissions
echo "Resetting permissions..."
./reset_permissions.sh

# Kill any running instances
echo "Killing existing instances..."
pkill -f VocalLiquid 2>/dev/null || true

# Create a modified version of AudioManager.swift with extra debugging
echo "Creating debug version of AudioManager.swift..."
cat > VocalLiquid/Managers/AudioManager.swift.debug << 'EOF'
import Foundation
import AVFoundation

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
    
    // Permission keys
    private let kMicPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
    private let kMicPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"
    
    // Logger
    private let logService = LoggingService()
    
    // Private initializer for singleton
    private init() {
        print("🎤 DEBUG: AudioManager singleton being initialized")
        
        // Clear any previous permission settings for clean testing
        UserDefaults.standard.removeObject(forKey: kMicPermissionCheckedKey)
        UserDefaults.standard.removeObject(forKey: kMicPermissionGrantedKey)
        UserDefaults.standard.synchronize()
        
        // Initial setup of audio components without activating
        setupAudioComponents()
        
        // Run permission check in main thread to block until complete
        print("🎤 DEBUG: About to request mic permissions explicitly and synchronously")
        requestMicrophonePermissionSynchronously()
        
        // At this point, we should have definitive permission status
        let hasPermission = UserDefaults.standard.bool(forKey: kMicPermissionGrantedKey)
        print("🎤 DEBUG: Final permission state after init: \(hasPermission ? "GRANTED" : "DENIED")")
        
        logService.log(message: "AudioManager initialized with persistent audio engine", level: .info)
    }
    
    // MARK: - Setup
    
    /// Set up audio components without activating the engine
    private func setupAudioComponents() {
        guard !isSetup else { 
            print("🎤 DEBUG: Audio components already set up, skipping")
            return 
        }
        
        print("🎤 DEBUG: Setting up audio components...")
        
        inputNode = audioEngine.inputNode
        print("🎤 DEBUG: Input node obtained: \(inputNode != nil ? "YES" : "NO")")
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: 16000, // Whisper expects 16kHz
                                  channels: 1,       // Whisper expects mono
                                  interleaved: false)
        print("🎤 DEBUG: Audio format created: \(audioFormat != nil ? "YES" : "NO")")
        
        guard inputNode != nil, audioFormat != nil else {
            print("🎤 DEBUG: ERROR: Failed to set up audio components!")
            logService.log(message: "Error setting up audio engine components", level: .error)
            return
        }
        
        // Set audio session category once at startup
        do {
            print("🎤 DEBUG: Setting audio session category...")
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎤 DEBUG: Audio session category set successfully")
        } catch {
            print("🎤 DEBUG: ERROR setting audio session category: \(error.localizedDescription)")
        }
        
        // Prepare the engine once
        audioEngine.prepare()
        print("🎤 DEBUG: Audio engine prepared")
        
        isSetup = true
        logService.log(message: "Audio components setup successfully (engine not running)", level: .info)
    }
    
    // MARK: - Permission Handling
    
    /// Check if microphone permission is granted
    var hasMicrophonePermission: Bool {
        let has = UserDefaults.standard.bool(forKey: kMicPermissionGrantedKey)
        print("🎤 DEBUG: Checking microphone permission: \(has ? "GRANTED" : "DENIED")")
        return has
    }
    
    /// Request microphone permission synchronously
    private func requestMicrophonePermissionSynchronously() {
        let defaults = UserDefaults.standard
        
        // Skip if we've already checked
        if defaults.bool(forKey: kMicPermissionCheckedKey) {
            let granted = defaults.bool(forKey: kMicPermissionGrantedKey)
            print("🎤 DEBUG: Microphone permission already checked, status: \(granted ? "GRANTED" : "DENIED")")
            logService.log(message: "Microphone permission already checked, status: \(granted)", level: .info)
            return
        }
        
        // Request permission directly using AVAudioSession API
        print("🎤 DEBUG: Requesting microphone permission using AVAudioSession...")
        
        let semaphore = DispatchSemaphore(value: 0)
        var permissionGranted = false
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            switch audioSession.recordPermission {
            case .granted:
                print("🎤 DEBUG: Microphone permission already granted")
                permissionGranted = true
                semaphore.signal()
                
            case .denied:
                print("🎤 DEBUG: Microphone permission already denied")
                permissionGranted = false
                semaphore.signal()
                
            case .undetermined:
                print("🎤 DEBUG: Microphone permission undetermined, requesting...")
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print("🎤 DEBUG: Microphone permission request completed: \(granted ? "GRANTED" : "DENIED")")
                    permissionGranted = granted
                    semaphore.signal()
                }
                
            @unknown default:
                print("🎤 DEBUG: Unknown permission status")
                permissionGranted = false
                semaphore.signal()
            }
        } catch {
            print("🎤 DEBUG: Error checking permission: \(error)")
            permissionGranted = false
            semaphore.signal()
        }
        
        // Wait for permission callback
        _ = semaphore.wait(timeout: .now() + 10)
        
        // Save result to UserDefaults
        defaults.set(true, forKey: kMicPermissionCheckedKey)
        defaults.set(permissionGranted, forKey: kMicPermissionGrantedKey)
        defaults.synchronize()
        
        print("🎤 DEBUG: Permission check complete, saved result: \(permissionGranted ? "GRANTED" : "DENIED")")
        
        if permissionGranted {
            logService.log(message: "Microphone permission granted explicitly", level: .info)
        } else {
            logService.log(message: "Microphone permission denied explicitly", level: .warning)
        }
    }
    
    // MARK: - Recording Control
    
    /// Start recording audio
    func startRecording() -> Bool {
        print("🎤 DEBUG: startRecording called, isRecording=\(isRecording), isEngineRunning=\(isEngineRunning)")
        
        if isRecording {
            print("🎤 DEBUG: Already recording, ignoring startRecording call")
            logService.log(message: "Already recording, ignoring startRecording call", level: .info)
            return false
        }
        
        // Ensure we have permission before proceeding
        guard hasMicrophonePermission else {
            print("🎤 DEBUG: Cannot record: Microphone permission not granted")
            logService.log(message: "Cannot record: Microphone permission not granted", level: .warning)
            return false
        }
        
        // Reset samples for new recording
        audioSamples.removeAll()
        print("🎤 DEBUG: Audio samples cleared for new recording")
        
        // Only start the engine if not already running
        if !isEngineRunning {
            do {
                print("🎤 DEBUG: Starting audio engine...")
                try audioEngine.start()
                isEngineRunning = true
                print("🎤 DEBUG: Audio engine started successfully")
                logService.log(message: "Audio engine started successfully", level: .info)
            } catch {
                print("🎤 DEBUG: Error starting audio engine: \(error.localizedDescription)")
                logService.log(message: "Error starting audio engine: \(error.localizedDescription)", level: .error)
                return false
            }
        }
        
        // Install tap on input node
        guard let inputNode = inputNode, let targetFormat = audioFormat else {
            print("🎤 DEBUG: Error: Audio components not available")
            logService.log(message: "Error: Audio components not available", level: .error)
            return false
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 DEBUG: Input format: \(inputFormat)")
        print("🎤 DEBUG: Target format: \(targetFormat)")
        
        // Remove any existing tap first to be safe
        if isRecording {
            print("🎤 DEBUG: Removing existing tap before installing new one")
            inputNode.removeTap(onBus: 0)
        }
        
        // Install tap to capture audio
        print("🎤 DEBUG: Installing audio tap...")
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, when) in
            guard let self = self else { return }
            if !self.isRecording {
                print("🎤 DEBUG: Warning: tap callback invoked while isRecording is false")
            }
            
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                print("🎤 DEBUG: Error creating format converter")
                self.logService.log(message: "Error creating format converter", level: .error)
                return
            }
            
            // Calculate capacity for the output buffer
            let frameCapacity = AVAudioFrameCount(targetFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate)
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
                print("🎤 DEBUG: Error creating PCM buffer for conversion")
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
                print("🎤 DEBUG: Error during audio conversion: \(error?.localizedDescription ?? "unknown")")
                self.logService.log(message: "Error during audio conversion: \(error?.localizedDescription ?? "unknown")", level: .error)
                return
            }
            
            // Ensure the buffer has float channel data
            guard let channelData = pcmBuffer.floatChannelData else {
                print("🎤 DEBUG: PCM Buffer does not contain float channel data")
                self.logService.log(message: "PCM Buffer does not contain float channel data", level: .error)
                return
            }
            
            // Append converted samples
            let frameLength = Int(pcmBuffer.frameLength)
            if self.audioSamples.count == 0 {
                print("🎤 DEBUG: First audio buffer received, length: \(frameLength)")
            }
            // Access the first channel (index 0) for mono audio
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            // Append samples
            self.audioSamples.append(contentsOf: samples)
        }
        
        isRecording = true
        print("🎤 DEBUG: Recording started successfully, isRecording set to true")
        logService.log(message: "Recording started successfully", level: .info)
        return true
    }
    
    /// Stop recording audio
    func stopRecording() {
        print("🎤 DEBUG: stopRecording called, isRecording=\(isRecording)")
        
        if !isRecording {
            print("🎤 DEBUG: Not recording, ignoring stopRecording call")
            logService.log(message: "Not recording, ignoring stopRecording call", level: .info)
            return
        }
        
        // Set isRecording to false first to prevent more samples from being added
        isRecording = false
        
        // Remove tap but don't stop the engine
        print("🎤 DEBUG: Removing audio tap...")
        inputNode?.removeTap(onBus: 0)
        
        print("🎤 DEBUG: Total samples collected: \(audioSamples.count)")
        logService.log(message: "Recording stopped successfully (engine still running)", level: .info)
    }
    
    /// Get audio samples for transcription
    func getSamplesForTranscription() -> [Float] {
        print("🎤 DEBUG: Returning \(audioSamples.count) audio samples for transcription")
        return audioSamples
    }
    
    // MARK: - Cleanup
    
    /// Shutdown the audio engine when no longer needed (app termination)
    func shutdown() {
        print("🎤 DEBUG: Shutting down audio engine...")
        
        if isRecording {
            print("🎤 DEBUG: Still recording during shutdown, stopping recording first")
            stopRecording()
        }
        
        if isEngineRunning {
            print("🎤 DEBUG: Stopping audio engine")
            audioEngine.stop()
            isEngineRunning = false
        }
        
        do {
            print("🎤 DEBUG: Deactivating audio session")
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("🎤 DEBUG: Error deactivating audio session: \(error.localizedDescription)")
        }
        
        print("🎤 DEBUG: Audio engine shutdown complete")
        logService.log(message: "Audio engine shutdown successfully", level: .info)
    }
}
EOF

# Backup the original file
cp VocalLiquid/Managers/AudioManager.swift VocalLiquid/Managers/AudioManager.swift.original
mv VocalLiquid/Managers/AudioManager.swift.debug VocalLiquid/Managers/AudioManager.swift

# Now let's add some debug prints to VocalLiquidApp.swift
echo "Adding debug prints to VocalLiquidApp.swift..."
sed -i '' 's/private func toggleRecording() {/private func toggleRecording() {\n        print("⚡️ DEBUG: toggleRecording called, current recording state: \(isRecording)")/g' VocalLiquid/VocalLiquidApp.swift
sed -i '' 's/stopRecording()/print("⚡️ DEBUG: About to call stopRecording")\n            stopRecording()\n            print("⚡️ DEBUG: Returned from stopRecording, isRecording=\(isRecording)")/g' VocalLiquid/VocalLiquidApp.swift
sed -i '' 's/startRecording()/print("⚡️ DEBUG: About to call startRecording")\n            startRecording()\n            print("⚡️ DEBUG: Returned from startRecording, isRecording=\(isRecording)")/g' VocalLiquid/VocalLiquidApp.swift

# Build and run
echo "Building and running with debug instrumentation..."
./build_background.sh

# Restore original files after run
echo "The app is now running with extra debugging."
echo "Press Cmd+Shift+R to test recording toggle."
echo ""
echo "When you're done testing, run this to restore the original files:"
echo "cp VocalLiquid/Managers/AudioManager.swift.original VocalLiquid/Managers/AudioManager.swift"