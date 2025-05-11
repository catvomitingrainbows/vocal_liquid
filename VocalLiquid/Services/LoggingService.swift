import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

class LoggingService {
    private let logFileURL: URL
    private let maxLogFiles = 5
    private let maxLogSize = 5 * 1024 * 1024 // 5 MB
    private let dateFormatter: DateFormatter
    
    init() {
        // Set up the date formatter for log timestamps
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Create log directory if needed
        let fileManager = FileManager.default
        let logDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("VocalLiquid", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        
        if !fileManager.fileExists(atPath: logDirectory.path) {
            do {
                try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating log directory: \(error.localizedDescription)")
            }
        }
        
        // Set up the current log file
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let timestamp = formatter.string(from: Date())
        logFileURL = logDirectory.appendingPathComponent("vocalliquid_\(timestamp).log")
        
        // Clean up old log files
        cleanupOldLogFiles(in: logDirectory)
        
        // Create initial log entry
        log(message: "Logging initialized", level: .info)
    }
    
    func log(message: String, level: LogLevel) {
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        
        // Print to console for development purposes
        print(logEntry, terminator: "")
        
        // Write to log file
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
                
                // Check if we need to rotate the log file
                let attributes = try FileManager.default.attributesOfItem(atPath: logFileURL.path)
                if let fileSize = attributes[.size] as? NSNumber, fileSize.intValue > maxLogSize {
                    rotateLogFile()
                }
            } else {
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Error writing to log file: \(error.localizedDescription)")
        }
    }
    
    private func rotateLogFile() {
        let fileManager = FileManager.default
        let logDirectory = logFileURL.deletingLastPathComponent()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let rotatedLogURL = logDirectory.appendingPathComponent("vocalliquid_\(timestamp).log")
        
        do {
            try fileManager.moveItem(at: logFileURL, to: rotatedLogURL)
        } catch {
            print("Error rotating log file: \(error.localizedDescription)")
        }
        
        // Clean up old log files after rotation
        cleanupOldLogFiles(in: logDirectory)
    }
    
    private func cleanupOldLogFiles(in directory: URL) {
        let fileManager = FileManager.default
        
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
                .filter { $0.pathExtension == "log" }
                .sorted { (file1, file2) -> Bool in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
            
            // Keep only maxLogFiles files, delete the rest
            if logFiles.count > maxLogFiles {
                for logFile in logFiles[maxLogFiles...] {
                    try fileManager.removeItem(at: logFile)
                }
            }
        } catch {
            print("Error cleaning up log files: \(error.localizedDescription)")
        }
    }
}