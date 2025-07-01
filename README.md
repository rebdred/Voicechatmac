# Voice Chat with your screen-aware Gemini with TTS by Kokoro 

A macOS application - real-time voice conversations with the screen-aware Gemini AI. Features Apple Silicon acceleration, persistent TTS processing. Runs TTS via Python, so not optimized at all. For educational purposes only.

It's a Linux binary, which works alright, but opens up a Terminal window on start. Closing terminal kills the app.

## ✨ Features

- 🎤 **Real-time voice questions** 
- 🤖 **Google Gemini AI integration** with conversation history
- 🎵 **High-quality TTS** using Kokoro 
- 🖼️ **Screenshot context** - AI can see your screen every time you ask a question
- 🪟 **Floating window** - Always on top, non-intrusive interface
- ⚡ **Optimized performance** - MPS acceleration, persistent TTS process



## 🚀 Performance Optimizations

- **Apple Silicon MPS Acceleration**: TTS runs 6.5x faster on Apple Silicon
- **Persistent TTS Process**: Model loads once, stays in memory
- **Optimized Sample Rate**: 22050 Hz for speech (excellent quality, smaller files)
- **Real-time Factor**: 0.17x (generates audio 6x faster than real-time)
- **Conversation History**: Smart context management for better responses

## 📋 Prerequisites

- **macOS 13.0 or later** (Apple Silicon recommended for best performance)
- **Xcode 15.0 or later**
- **Python 3.11.x** (required for Kokoro TTS - Python 3.12+ may have compatibility issues)
- **Google Gemini API key**

## 🛠️ Setup

### 1. Clone and Navigate
```bash
git clone <repository-url>
cd Voicechatmac
```

### 2. Run the Setup Script
```bash
# Make the setup script executable
chmod +x setup.sh

# Run the automated setup
./setup.sh
```

The setup script will:
- ✅ Check for Python 3.11.x compatibility
- ✅ Create Python virtual environment (`kokoro-venv`)
- ✅ Install required packages: `kokoro`, `soundfile`, `torch`, `nltk`
- ✅ Download NLTK language data for sentence tokenization
- ✅ Create a `config.txt` template

### 3. Configure Your API Key
- Edit the generated `config.txt` file
- Replace `your_api_key_here` with your actual Gemini API key
- Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)

### 4. Build and Run
```bash
# Build the Swift app
swift build

# Copy the binary to your project folder
cp .build/arm64-apple-macosx/debug/VoiceChatApp .

# Run the app
./VoiceChatApp
```

> **IMPORTANT:**
> Place the `kokoro-venv` folder and the TTS scripts (`kokoro_tts_persistent.py`, `kokoro_tts.py`) in **either**:
> - The same directory as the app binary (recommended for development)
> - The parent directory of the app bundle (recommended for production/distribution)
>
> This ensures the app can find and use the TTS engine on any machine.

## 🎯 Usage

1. **Launch** the application (appears as floating window)
2. **Click "Start Chat"** to begin recording
3. **Speak** your message clearly
4. **Click "Stop Chat"** to end recording and send to Gemini
5. **Listen** to the AI response (automatically played back)


## 📁 Project Structure

### Core App Files
- `VoiceChatApp.swift` - Main app entry point with floating window setup
- `ContentView.swift` - Modern SwiftUI interface with status indicators
- `ChatManager.swift` - Audio recording, TTS, and chat logic
- `ChatMessage.swift` - Message data model
- `GeminiAPI.swift` - Google Gemini API integration

### TTS Engine Files
- `kokoro_tts_persistent.py` - Optimized persistent TTS process (primary)
- `kokoro_tts.py` - Fallback TTS script
- `kokoro-venv/` - Python virtual environment

### Configuration
- `Package.swift` - Swift Package Manager configuration
- `Info.plist` - App permissions and configuration
- `.gitignore` - Excludes build artifacts and temp files

## 🔧 Technical Details

### TTS Performance
- **Model**: Kokoro-82M (312MB)
- **Device**: Apple Silicon MPS acceleration
- **Sample Rate**: 22050 Hz (optimized for speech)


### API Integration
- **Model**: `gemini-2.5-flash`
- **Features**: Audio input, screenshot context, conversation history
- **Response Limit**: 4000 tokens (optimized for voice responses)

### Architecture
- **SwiftUI** for modern, responsive interface
- **AVFoundation** for audio recording/playback
- **Python subprocess** for TTS integration
- **Apple Silicon MPS** for GPU acceleration

## 🔒 Permissions Required

- **Microphone**: For voice recording
- **Screen Recording**: For screenshot context (optional)

## 🐛 Troubleshooting

### Common Issues

**TTS Not Working:**
- Ensure Python virtual environment is activated
- Check that `kokoro` package is installed
- Verify Apple Silicon MPS is available

**API Errors:**
- Verify Gemini API key is correct
- Check API quota and billing
- Ensure network connectivity

**Audio Issues:**
- Check microphone permissions in System Preferences
- Verify audio output device is working
- Restart the app if persistent TTS fails

**Performance Issues:**
- Ensure running on Apple Silicon Mac for MPS acceleration
- Check that model is loaded to MPS device
- Monitor system resources

### Debug Information
The app provides detailed timing logs:
```
[TIMING] stopRecording() called at ...
[TIMING] Audio file read at ...
[TIMING] Sending to Gemini API at ...
[TIMING] Gemini API responded at ...
[TIMING] TTS synthesis started at ...
[TIMING] Audio file generated at ...
[TIMING] Audio playback started at ...
```

## 🔄 Recent Optimizations

- ✅ **Apple Silicon MPS acceleration** (6.5x speedup)
- ✅ **Persistent TTS process** (eliminates model loading delay)
- ✅ **Optimized sample rate** (22050 Hz for speech)
- ✅ **Floating window interface** (always on top, non-intrusive)
- ✅ **Multi-line text handling** (fixes TTS processing issues)
- ✅ **Unique audio filenames** (prevents file conflicts)
- ✅ **Conversation history** (maintains context)
- ✅ **Screenshot context** (AI can see your screen)

## 📄 License

This project is for educational purposes. Please ensure compliance with:
- Google's Gemini API terms of service
- Kokoro TTS licensing terms
- Apple's developer guidelines

## 🤝 Contributing

Contributions are welcome! Please ensure:
- Code follows Swift and Python best practices
- Performance optimizations are tested on Apple Silicon
- TTS quality and latency are maintained 