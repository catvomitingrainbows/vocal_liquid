import Foundation
import whisper

enum WhisperError: Error {
    case modelLoadingFailed
    case transcriptionFailed(code: Int32)
    case noAudioSamples
}

class WhisperManager {
    private var whisperContext: OpaquePointer?
    private let logService = LoggingService()
    
    init() {
        loadWhisperModel()
    }
    
    deinit {
        if let context = whisperContext {
            whisper_free(context)
            logService.log(message: "Whisper context freed.", level: .info)
        }
    }
    
    private func loadWhisperModel() {
        print("DEBUG: Loading Whisper model...")

        // First try to find the model in the Resources directory
        guard let modelPath = Bundle.main.path(forResource: "ggml-base.en", ofType: "bin") else {
            logService.log(message: "Error: Model file not found in bundle. Application will not function properly.", level: .error)

            // Print to console for debugging
            print("ERROR: Model file 'ggml-base.en.bin' not found in application bundle")
            print("Current bundle path: \(Bundle.main.bundlePath)")
            print("Current bundle resource path: \(Bundle.main.resourcePath ?? "nil")")

            // List files in Resources directory for debugging
            if let resourcePath = Bundle.main.resourcePath {
                print("Listing files in resource directory:")
                let fileManager = FileManager.default
                do {
                    let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
                    for file in files {
                        print("  - \(file)")
                    }
                } catch {
                    print("Error listing resource directory: \(error)")
                }
            }

            return
        }

        print("DEBUG: Found model at path: \(modelPath)")

        if !FileManager.default.fileExists(atPath: modelPath) {
            logService.log(message: "Error: Model file does not exist at path: \(modelPath)", level: .error)
            return
        }
        
        logService.log(message: "Attempting to load model from: \(modelPath)", level: .info)
        
        var contextParams = whisper_context_default_params()
        #if targetEnvironment(simulator)
            logService.log(message: "Running on Simulator, GPU usage disabled.", level: .info)
            contextParams.use_gpu = false
        #else
            logService.log(message: "Running on Device, attempting GPU usage.", level: .info)
            contextParams.use_gpu = true
        #endif
        
        whisperContext = whisper_init_from_file_with_params(modelPath.cString(using: .utf8), contextParams)
        
        if whisperContext == nil {
            logService.log(message: "Error: Failed to load Whisper model.", level: .error)
        } else {
            logService.log(message: "Whisper model loaded successfully.", level: .info)
        }
    }
    
    func transcribeAudio(samples: [Float], completion: @escaping (Result<String, Error>) -> Void) {
        print("DEBUG: transcribeAudio called with \(samples.count) samples")

        guard let context = whisperContext else {
            print("ERROR: Whisper context not available")
            logService.log(message: "Error: Whisper context not available.", level: .error)
            completion(.failure(WhisperError.modelLoadingFailed))
            return
        }

        guard !samples.isEmpty else {
            print("ERROR: No audio samples to transcribe")
            logService.log(message: "No audio samples to transcribe.", level: .warning)
            completion(.failure(WhisperError.noAudioSamples))
            return
        }

        print("DEBUG: Will process \(samples.count) samples for transcription")
        
        logService.log(message: "Processing \(samples.count) samples for transcription.", level: .info)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            
            // Run the transcription
            let result = whisper_full(context, params, samples, Int32(samples.count))
            
            var transcription = ""
            if result == 0 {
                self?.logService.log(message: "Transcription successful.", level: .info)
                let n_segments = whisper_full_n_segments(context)
                for i in 0..<n_segments {
                    if let text_ptr = whisper_full_get_segment_text(context, i) {
                        transcription += String(cString: text_ptr)
                    }
                }
                completion(.success(transcription))
            } else {
                self?.logService.log(message: "Error during transcription: \(result)", level: .error)
                completion(.failure(WhisperError.transcriptionFailed(code: result)))
            }
        }
    }
}