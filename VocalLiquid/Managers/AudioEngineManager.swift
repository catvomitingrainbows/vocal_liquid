import Foundation
import AVFoundation
import Combine

class AudioEngineManager: ObservableObject {
    // Standard permission keys
    private let kMicPermissionCheckedKey = "VocalLiquid.MicPermissionChecked"
    private let kMicPermissionGrantedKey = "VocalLiquid.MicPermissionGranted"
    
    @Published var isRecording = false
    private(set) var audioSamples: [Float] = []

    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private let logService = LoggingService()

    init() {
        setupAudioEngine()
        // Do NOT check permissions at initialization
        logService.log(message: "AudioEngineManager initialized", level: .info)
    }

    private func setupAudioEngine() {
        inputNode = audioEngine.inputNode
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: 16000, // Whisper expects 16kHz
                                  channels: 1,       // Whisper expects mono
                                  interleaved: false)

        guard inputNode != nil, audioFormat != nil else {
            logService.log(message: "Error setting up audio engine components", level: .error)
            return
        }

        logService.log(message: "Audio engine components setup successfully", level: .info)
    }

    func startRecording() {
        guard let inputNode = inputNode, let targetFormat = audioFormat, !isRecording else {
            logService.log(message: "Error: Audio engine not setup or already recording", level: .error)
            return
        }

        print("AudioEngineManager: startRecording called")
        print("Permission status in AudioEngineManager:")

        // Print current permission status
        let defaults = UserDefaults.standard
        print("Mic permission checked: \(defaults.bool(forKey: kMicPermissionCheckedKey))")
        print("Mic permission granted: \(defaults.bool(forKey: kMicPermissionGrantedKey))")

        // Use saved permission result if already checked
        if defaults.bool(forKey: self.kMicPermissionCheckedKey) {
            print("AudioEngineManager: Microphone permission was already checked")
            if defaults.bool(forKey: self.kMicPermissionGrantedKey) {
                print("AudioEngineManager: Using saved permission (granted)")
                startRecordingWithPermission()
            } else {
                print("AudioEngineManager: Using saved permission (denied)")
                logService.log(message: "Cannot record: Microphone permission previously denied", level: .warning)
            }
            return
        }

        // Only check permission if not already checked and saved
        print("AudioEngineManager: First-time recording, requesting microphone permission")
        logService.log(message: "First-time recording: requesting microphone permission", level: .info)
        checkMicrophonePermission { [weak self] granted in
            guard let self = self else { return }

            print("AudioEngineManager: Permission check completed with result: \(granted)")

            guard granted else {
                self.logService.log(message: "Microphone permission denied, cannot record", level: .warning)
                return
            }

            self.startRecordingWithPermission()
        }
    }

    private func startRecordingWithPermission() {
        guard let inputNode = inputNode, let targetFormat = audioFormat, !isRecording else { return }

        DispatchQueue.main.async {
            self.audioSamples.removeAll() // Clear previous samples
            self.isRecording = true

            let inputFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, when) in
                guard let self = self else { return }

                guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                    self.logService.log(message: "Error creating format converter", level: .error)
                    return
                }

                // Calculate capacity needed for the output buffer
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

            self.audioEngine.prepare()
            do {
                // On macOS, we don't need to set up an audio session like on iOS
                try self.audioEngine.start()
                self.logService.log(message: "Audio engine started successfully", level: .info)
            } catch {
                self.logService.log(message: "Error starting audio engine: \(error.localizedDescription)", level: .error)
                self.isRecording = false
                inputNode.removeTap(onBus: 0)
            }
        }
    }

    func stopRecording() {
        guard let inputNode = inputNode, isRecording else { return }

        logService.log(message: "Stopping recording...", level: .info)
        isRecording = false
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
    }

    func getSamplesForTranscription() -> [Float] {
        return audioSamples
    }

    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let defaults = UserDefaults.standard

        print("AudioEngineManager: Checking microphone permission")

        // If we've already checked permissions, use that saved result
        if defaults.bool(forKey: self.kMicPermissionCheckedKey) {
            let granted = defaults.bool(forKey: self.kMicPermissionGrantedKey)
            print("AudioEngineManager: Found saved permission result: \(granted)")
            logService.log(message: "Using saved permission result: \(granted)", level: .info)
            completion(granted)
            return
        }

        let permission = AVAudioApplication.shared.recordPermission
        print("AudioEngineManager: Current permission status: \(permission.rawValue)")

        switch permission {
        case .granted:
            print("AudioEngineManager: Permission already granted, saving to UserDefaults")
            logService.log(message: "Microphone permission already granted", level: .info)
            // Save the permission result to UserDefaults
            defaults.set(true, forKey: self.kMicPermissionCheckedKey)
            defaults.set(true, forKey: self.kMicPermissionGrantedKey)
            defaults.synchronize() // Force synchronize
            print("AudioEngineManager: Permission saved, returning true")
            completion(true)

        case .undetermined:
            print("AudioEngineManager: Permission undetermined, requesting...")
            logService.log(message: "Requesting microphone permission...", level: .info)
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    print("AudioEngineManager: Permission request completed with result: \(granted)")
                    if granted {
                        self.logService.log(message: "Microphone permission granted", level: .info)
                    } else {
                        self.logService.log(message: "Microphone permission denied", level: .warning)
                    }

                    // Save the permission result to UserDefaults
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: self.kMicPermissionCheckedKey)
                    defaults.set(granted, forKey: self.kMicPermissionGrantedKey)
                    defaults.synchronize() // Force synchronize
                    print("AudioEngineManager: Permission saved, current status:")
                    print("Mic permission checked: \(defaults.bool(forKey: self.kMicPermissionCheckedKey))")
                    print("Mic permission granted: \(defaults.bool(forKey: self.kMicPermissionGrantedKey))")
                    completion(granted)
                }
            }

        case .denied:
            print("AudioEngineManager: Permission already denied, saving to UserDefaults")
            logService.log(message: "Microphone permission previously denied", level: .warning)
            // Save the permission result to UserDefaults
            defaults.set(true, forKey: self.kMicPermissionCheckedKey)
            defaults.set(false, forKey: self.kMicPermissionGrantedKey)
            defaults.synchronize() // Force synchronize
            print("AudioEngineManager: Permission saved, returning false")
            completion(false)

        @unknown default:
            print("AudioEngineManager: Unknown permission status, defaulting to denied")
            logService.log(message: "Unknown microphone permission status", level: .warning)
            // Save the permission result to UserDefaults (as a denial for safety)
            defaults.set(true, forKey: self.kMicPermissionCheckedKey)
            defaults.set(false, forKey: self.kMicPermissionGrantedKey)
            defaults.synchronize() // Force synchronize
            print("AudioEngineManager: Permission saved, returning false")
            completion(false)
        }
    }
}