import SwiftUI

struct ContentView: View {
    @StateObject private var chatManager = ChatManager()
    
    var body: some View {
        VStack(spacing: 20) {
            // TTS Status indicator
            HStack {
                Circle()
                    .fill(chatManager.isTTSReady ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(chatManager.isTTSReady ? "Ready to chat" : "Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Chat history
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chatManager.messages, id: \.id) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Start/Stop button (custom ZStack implementation)
            ZStack {
                Image(systemName: chatManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(chatManager.isRecording ? Color.red : Color.blue)
            .cornerRadius(12)
            .onTapGesture {
                chatManager.isRecording ? chatManager.stopChat() : chatManager.startChat()
            }
            
            // Hotkey note at the bottom
            HStack {
                Spacer()
                Text("⌃⌥⌘R to read any selection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 300, height: 400)  // window size
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            chatManager.enableReadSelectionHotkey()
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if message.isUser {
                    Text(message.content)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                } else {
                    // Gemini response: make selectable/copyable
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
} 