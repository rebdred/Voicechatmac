import Foundation

class GeminiAPI {
    private let apiKey: String
    private let prompt: String
    let ttsSpeed: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash"
    
    init() {
        // Load API key, prompt, and TTS speed from config file
        let config = GeminiAPI.loadConfig()
        self.apiKey = config.apiKey
        self.prompt = config.prompt
        self.ttsSpeed = config.ttsSpeed
    }
    
    private static func loadConfig() -> (apiKey: String, prompt: String, ttsSpeed: String) {
        // Get the binary directory to find config.txt
        let binaryPath = CommandLine.arguments[0]
        let binaryDirectory = URL(fileURLWithPath: binaryPath).deletingLastPathComponent()
        let configURL = binaryDirectory.appendingPathComponent("config.txt")
        
        var apiKey = ""
        var prompt = "Given the following voice message and screenshot, respond appropriately. Keep the response short and conversational. If the user asks for a breakdown, go deeper, but not more than 200 words."
        var ttsSpeed = "1.3"
        
        do {
            let configContent = try String(contentsOf: configURL, encoding: .utf8)
            let lines = configContent.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.hasPrefix("GEMINI_API_KEY=") {
                    let key = String(trimmedLine.dropFirst("GEMINI_API_KEY=".count))
                    if !key.isEmpty {
                        apiKey = key
                    }
                } else if trimmedLine.hasPrefix("GEMINI_PROMPT=") {
                    let customPrompt = String(trimmedLine.dropFirst("GEMINI_PROMPT=".count))
                    if !customPrompt.isEmpty {
                        prompt = customPrompt
                    }
                } else if trimmedLine.hasPrefix("TTS_SPEED=") {
                    let speed = String(trimmedLine.dropFirst("TTS_SPEED=".count))
                    if !speed.isEmpty {
                        ttsSpeed = speed
                    }
                }
            }
            
            if !apiKey.isEmpty {
                print("[GeminiAPI] Configuration loaded from config.txt")
            } else {
                print("[GeminiAPI] ERROR: GEMINI_API_KEY not found in config.txt")
            }
        } catch {
            print("[GeminiAPI] ERROR: Could not read config.txt: \(error)")
            print("[GeminiAPI] Make sure config.txt exists in the same directory as the app")
        }
        
        return (apiKey, prompt, ttsSpeed)
    }
    
    func sendAudioAndScreenshot(audioData: Data, screenshotData: Data?, conversationHistory: [ChatMessage] = []) async -> String? {
        guard !apiKey.isEmpty else {
            print("[GeminiAPI] ERROR: API key is missing.")
            return nil
        }
        guard let url = URL(string: "\(baseURL):generateContent?key=\(apiKey)") else {
            print("[GeminiAPI] ERROR: Invalid URL.")
            return nil
        }
        
        // Build conversation history
        var contents: [[String: Any]] = []
        
        // Add conversation history (last 10 messages to stay within token limits)
        let recentHistory = Array(conversationHistory.suffix(10))
        for message in recentHistory {
            let role = message.isUser ? "user" : "model"
            contents.append([
                "role": role,
                "parts": [
                    ["text": message.content]
                ]
            ])
        }
        
        // Add current message with audio and screenshot
        var currentParts: [[String: Any]] = [
            ["text": prompt]
        ]
        
        // Add audio part
        currentParts.append([
            "inlineData": [
                "mimeType": "audio/mp4",
                "data": audioData.base64EncodedString()
            ]
        ])
        
        // Add screenshot part if available
        if let screenshotData = screenshotData {
            currentParts.append([
                "inlineData": [
                    "mimeType": "image/png",
                    "data": screenshotData.base64EncodedString()
                ]
            ])
        }
        
        contents.append([
            "role": "user",
            "parts": currentParts
        ])
        
        let requestBody: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 4000
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[GeminiAPI] Status code:", httpResponse.statusCode)
            }
            print("[GeminiAPI] Raw response:", String(data: data, encoding: .utf8) ?? "nil")
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[GeminiAPI] ERROR: API request failed with status code \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            
            let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let candidates = responseDict?["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                print("[GeminiAPI] Parsed text response:", text)
                return text
            } else {
                print("[GeminiAPI] ERROR: Could not parse text from response.")
            }
            
            return nil
        } catch {
            print("[GeminiAPI] ERROR: Exception during API call: \(error)")
            return nil
        }
    }
} 