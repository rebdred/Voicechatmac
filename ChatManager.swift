import Foundation
import AVFoundation
import SwiftUI
import CoreGraphics
import AppKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

class ChatManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var messages: [ChatMessage] = []
    @Published var isTTSReady = false
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private let geminiAPI = GeminiAPI()
    private var screenshotData: Data?
    private var screenshotFileURL: URL?
    
    // TTS optimization: Keep a persistent process
    private var ttsProcess: Process?
    private var ttsInputPipe: Pipe?
    private var ttsOutputPipe: Pipe?
    
    // Use a dedicated temp directory for all temp files
    private let tempDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceChatGeminiTemp", isDirectory: true)
    
    // TTS sentence playback queue and state
    private var ttsAudioQueue: [URL] = []
    private var ttsCurrentBaseFilename: String?
    private var ttsExpectedCount = 0
    private var ttsPlayedCount = 0
    private var ttsDoneFiles: Set<String> = []
    private var ttsStartTime: Date = Date()
    
    override init() {
        super.init()
        // Ensure temp directory exists
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
        setupPersistentTTS()
    }
    
    deinit {
        // Clean up persistent TTS process
        ttsProcess?.terminate()
    }
    
    private func setupPersistentTTS() {
        // Start a persistent Python process for TTS
        print("Setting up persistent TTS process...")
        Task {
            await startPersistentTTS()
        }
    }
    
    private func startPersistentTTS() async {
        let process = Process()
        
        guard let paths = findTTSPaths(persistent: true) else {
            print("ERROR: Could not find Python executable or persistent TTS script")
            return
        }
        
        process.launchPath = paths.venvPath
        process.arguments = [paths.scriptPath, "af_heart", "1.3"]  // Match the updated speed
        process.currentDirectoryPath = paths.workingDirectory
        
        // Set up pipes for communication
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        // Environment setup
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["TTS_SPEED"] = geminiAPI.ttsSpeed
        process.environment = environment
        
        do {
            try process.run()
            
            // Wait for TTS to be ready
            print("Waiting for TTS process to be ready...")
            await withCheckedContinuation { continuation in
                outputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let output = String(data: data, encoding: .utf8) {
                        print("TTS output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                        if output.contains("READY") {
                            DispatchQueue.main.async {
                                self.isTTSReady = true
                            }
                            print("TTS process is ready!")
                            continuation.resume()
                        }
                    }
                }
            }
            
            self.ttsProcess = process
            self.ttsInputPipe = inputPipe
            self.ttsOutputPipe = outputPipe
            
            print("Persistent TTS process started successfully")
            
        } catch {
            print("Failed to start persistent TTS: \(error)")
        }
    }
    
    private func findTTSPaths(persistent: Bool) -> (venvPath: String, scriptPath: String, workingDirectory: String)? {
        let binaryPath = CommandLine.arguments[0]
        let binaryDirectory = URL(fileURLWithPath: binaryPath).deletingLastPathComponent().path
        
        let venvPath = binaryDirectory + "/kokoro-venv/bin/python"
        let persistentScriptPath = binaryDirectory + "/kokoro_tts_persistent.py"
        let fallbackScriptPath = binaryDirectory + "/kokoro_tts.py"
        
        if FileManager.default.fileExists(atPath: venvPath) {
            if persistent && FileManager.default.fileExists(atPath: persistentScriptPath) {
                return (venvPath, persistentScriptPath, tempDirectory.path)
            } else if !persistent && FileManager.default.fileExists(atPath: fallbackScriptPath) {
                return (venvPath, fallbackScriptPath, binaryDirectory)
            }
        }
        return nil
    }
    
    func startChat() {
        isRecording = true
        takeScreenshot()
        startRecording()
    }
    
    func stopChat() {
        isRecording = false
        stopRecording()
    }
    
    private func takeScreenshot() {
        // Capture the entire visible screen including all windows
        let image = CGWindowListCreateImage(
            CGRect.infinite,
            .optionAll,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
        if let image = image {
            let bitmapRep = NSBitmapImageRep(cgImage: image)
            // Compress to JPEG, quality 0.7 (adjust if needed)
            if let data = bitmapRep.representation(using: .jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 0.7]) {
                screenshotData = data
                // Save screenshot to temp folder with timestamp
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "screenshot_\(formatter.string(from: Date())).jpg"
                let fileURL = tempDirectory.appendingPathComponent(filename)
                do {
                    try data.write(to: fileURL)
                    screenshotFileURL = fileURL // Store for later deletion
                    print("Screenshot saved to: \(fileURL.path)")
                    print("Screenshot size: \(data.count / 1024) KB")
                } catch {
                    print("Failed to save screenshot: \(error)")
                    screenshotFileURL = nil
                }
            }
        } else {
            screenshotData = nil
            screenshotFileURL = nil
            print("Failed to take screenshot")
        }
    }
    
    private func startRecording() {
        let filename = "recording.m4a"
        recordingURL = tempDirectory.appendingPathComponent(filename)
        
        guard let recordingURL = recordingURL else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        let stopTime = Date()
        print("[TIMING] stopRecording() called at \(stopTime)")
        audioRecorder?.stop()
        
        guard let recordingURL = recordingURL else { return }
        let screenshot = screenshotData
        
        // Add user message to chat
        let userMessage = ChatMessage(content: "🎤 [Voice message]", isUser: true, timestamp: Date())
        DispatchQueue.main.async {
            self.messages.append(userMessage)
        }
        
        // Send to Gemini API
        Task {
            await sendAudioAndScreenshotToGemini(recordingURL: recordingURL, screenshotData: screenshot, stopTime: stopTime)
        }
    }
    
    private func sendAudioAndScreenshotToGemini(recordingURL: URL, screenshotData: Data?, stopTime: Date) async {
        do {
            let audioReadTime = Date()
            print("[TIMING] Audio file read at \(audioReadTime), delta: \(audioReadTime.timeIntervalSince(stopTime))s")
            let audioData = try Data(contentsOf: recordingURL)
            // Pass conversation history to maintain context
            let sendTime = Date()
            print("[TIMING] Sending to Gemini API at \(sendTime), delta: \(sendTime.timeIntervalSince(audioReadTime))s")
            let response = await geminiAPI.sendAudioAndScreenshot(
                audioData: audioData, 
                screenshotData: screenshotData, 
                conversationHistory: messages
            )
            let geminiResponseTime = Date()
            print("[TIMING] Gemini API responded at \(geminiResponseTime), delta: \(geminiResponseTime.timeIntervalSince(sendTime))s")
            
            DispatchQueue.main.async {
                if let response = response {
                    let assistantMessage = ChatMessage(content: response, isUser: false, timestamp: Date())
                    self.messages.append(assistantMessage)
                    self.speakWithKokoro(text: response, geminiResponseTime: geminiResponseTime)
                } else {
                    let errorMessage = ChatMessage(content: "Sorry, I couldn't process your message.", isUser: false, timestamp: Date())
                    self.messages.append(errorMessage)
                }
            }
        } catch {
            print("Failed to read audio file: \(error)")
            DispatchQueue.main.async {
                let errorMessage = ChatMessage(content: "Error processing audio.", isUser: false, timestamp: Date())
                self.messages.append(errorMessage)
            }
        }
    }
    
    private func speakWithKokoro(text: String, geminiResponseTime: Date) {
        // Use persistent TTS process for faster response
        Task {
            if isTTSReady {
                await runPersistentTTS(text: text, geminiResponseTime: geminiResponseTime)
            } else {
                // Fallback to original method if persistent TTS not ready
                await runTTSInBackground(text: text)
            }
        }
    }
    
    private func runPersistentTTS(text: String, geminiResponseTime: Date) async {
        let ttsStartTime = Date()
        self.ttsStartTime = ttsStartTime
        print("[TIMING] TTS synthesis started at \(ttsStartTime), delta: \(ttsStartTime.timeIntervalSince(geminiResponseTime))s")
        guard let inputPipe = ttsInputPipe, let outputPipe = ttsOutputPipe else {
            print("TTS input/output pipe not available")
            return
        }
        
        // Generate unique base filename for this TTS request
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let baseFilename = "output_\(timestamp)"
        ttsAudioQueue = []
        ttsCurrentBaseFilename = baseFilename
        ttsExpectedCount = 0
        ttsPlayedCount = 0
        ttsDoneFiles = []
        let cleanText = text.replacingOccurrences(of: "\n", with: " ")
        let textWithBase = "\(cleanText)|\(baseFilename)\n"
        if let data = textWithBase.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
        
        // Listen for DONE:<filename> lines and queue files
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard let output = String(data: data, encoding: .utf8) else { return }
            for line in output.components(separatedBy: .newlines) {
                if line.hasPrefix("DONE:") {
                    let file = line.replacingOccurrences(of: "DONE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let base = self.ttsCurrentBaseFilename, file.hasPrefix(base) else { continue }
                    if self.ttsDoneFiles.contains(file) { continue }
                    self.ttsDoneFiles.insert(file)
                    let fileURL = self.tempDirectory.appendingPathComponent(file)
                    self.ttsAudioQueue.append(fileURL)
                    self.ttsExpectedCount += 1
                    
                    // Print timing when first audio chunk is generated
                    if self.ttsExpectedCount == 1 {
                        let audioGenTime = Date()
                        print("[TIMING] First audio chunk generated at \(audioGenTime), delta: \(audioGenTime.timeIntervalSince(self.ttsStartTime))s")
                    }
                    
                    if self.ttsAudioQueue.count == 1 && (self.audioPlayer == nil || self.audioPlayer?.isPlaying == false) {
                        Task { await self.playNextTTSFile() }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func playNextTTSFile() async {
        guard !ttsAudioQueue.isEmpty else { return }
        let fileURL = ttsAudioQueue.removeFirst()
        
        // Print timing when first chunk starts playing
        if ttsPlayedCount == 0 {
            let audioPlayTime = Date()
            print("[TIMING] First audio chunk playback started at \(audioPlayTime), delta: \(audioPlayTime.timeIntervalSince(ttsStartTime))s")
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Failed to play TTS audio: \(error)")
            try? FileManager.default.removeItem(at: fileURL)
            await playNextTTSFile() // Try next
        }
    }
    
    private func runTTSInBackground(text: String) async {
        let process = Process()
        
        guard let paths = findTTSPaths(persistent: false) else {
            print("ERROR: Could not find Python executable or TTS script in any of the expected locations")
            return
        }
        
        // Generate unique filename for this TTS request
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let uniqueFilename = "output_\(timestamp).wav"
        let audioURL = tempDirectory.appendingPathComponent(uniqueFilename)
        
        process.launchPath = paths.venvPath
        process.arguments = [paths.scriptPath, text, "af_heart", "1.3", audioURL.lastPathComponent]  // Pass unique filename only
        process.currentDirectoryPath = tempDirectory.path
        
        // Hide the terminal window and run in background
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "dumb"
        environment["TERM_PROGRAM"] = ""
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            // Wait for completion in background
            await withCheckedContinuation { continuation in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
            }
            
            // Wait for audio file to be generated
            let audioURL = URL(fileURLWithPath: paths.workingDirectory).appendingPathComponent(uniqueFilename)
            
            // Simple wait for file to appear
            for _ in 0..<50 { // Wait up to 5 seconds
                if FileManager.default.fileExists(atPath: audioURL.path) {
                    await MainActor.run {
                        do {
                            self.audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                            self.audioPlayer?.delegate = self
                            self.audioPlayer?.play()
                            // Delete the file after playing
                            try? FileManager.default.removeItem(at: audioURL)
                        } catch {
                            print("Failed to play Kokoro TTS audio: \(error)")
                        }
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            print("Kokoro TTS timeout - audio file not generated")
        } catch {
            print("Failed to run TTS process: \(error)")
        }
    }
    
    // Delete temp files after playback
    private func cleanupTempFiles() {
        if let screenshotFileURL = screenshotFileURL {
            try? FileManager.default.removeItem(at: screenshotFileURL)
            self.screenshotFileURL = nil
        }
        if let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
        }
    }
}

extension ChatManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}

extension ChatManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let lastPlayed = player.url {
            try? FileManager.default.removeItem(at: lastPlayed)
        }
        ttsPlayedCount += 1
        if !ttsAudioQueue.isEmpty {
            Task { await playNextTTSFile() }
        } else {
            // All done, cleanup
            let audioFinishTime = Date()
            print("[TIMING] All audio chunks finished playing at \(audioFinishTime), delta: \(audioFinishTime.timeIntervalSince(ttsStartTime))s")
            ttsCurrentBaseFilename = nil
            ttsExpectedCount = 0
            ttsPlayedCount = 0
            ttsDoneFiles.removeAll()
        }
    }
} 