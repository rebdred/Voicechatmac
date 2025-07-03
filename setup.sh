#!/bin/bash

echo "🚀 Setting up VoiceChatMac..."
echo ""

# Check if Python 3.11 is installed via Homebrew
PYTHON311_PATH="/opt/homebrew/opt/python@3.11/bin/python3.11"
if [ ! -f "$PYTHON311_PATH" ]; then
    echo "❌ Error: Python 3.11 is not installed via Homebrew."
    echo "💡 Please install it with: brew install python@3.11"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$("$PYTHON311_PATH" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 11 ]); then
    echo "❌ Error: Python 3.11+ is required for Kokoro TTS, but you have Python $PYTHON_VERSION"
    echo "💡 Please install Python 3.11.x from: https://www.python.org/downloads/"
    echo "💡 Or use pyenv: pyenv install 3.11.13"
    exit 1
fi



echo "✅ Python $PYTHON_VERSION found (compatible with Kokoro)"

# Create virtual environment
echo "📦 Creating Python virtual environment..."
"$PYTHON311_PATH" -m venv kokoro-venv

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source kokoro-venv/bin/activate

# Verify we're using the right Python version in venv
VENV_PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "✅ Virtual environment using Python $VENV_PYTHON_VERSION"

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install required packages
echo "📚 Installing Python packages..."
echo "   Installing Kokoro TTS (requires Python 3.11+)..."
pip install kokoro soundfile torch nltk

# Download NLTK data
echo "📖 Downloading NLTK language data..."
python3 -c "import nltk; nltk.download('punkt', quiet=True); nltk.download('wordnet', quiet=True); nltk.download('omw-1.4', quiet=True)"

# Create config template
echo "⚙️  Creating configuration template..."
cat > config.txt << 'EOF'
# Gemini API Configuration
# Replace this with your actual API key from Google AI Studio
# Visit: https://makersuite.google.com/app/apikey
GEMINI_API_KEY=your_api_key_here

# Gemini Model Configuration
# The model to use for generating responses (e.g., gemini-2.5-flash, gemini-1.5-flash, gemini-1.5-pro)
GEMINI_MODEL=gemini-2.5-flash

# Gemini Prompt Configuration
# This prompt is sent to Gemini along with the audio and screenshot
# You can customize this to change how the AI responds
GEMINI_PROMPT=Given the following voice message and screenshot, respond appropriately. Keep the response short and conversational. If the user asks to go deeper, but not more than 200 words. Never offer to go deeper yourself. 

# TTS Speed Configuration
# Controls how fast the text-to-speech synthesis plays (1.0 = normal speed, 1.5 = 50% faster, 0.8 = 20% slower)
TTS_SPEED=1.35
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Edit config.txt and replace 'your_api_key_here' with your actual Gemini API key"
echo "2. Build the app: swift build"
echo "3. Copy the binary to your project folder"
echo "4. Run the app: ./VoiceChatApp"
echo ""
echo "🔗 Get your API key from: https://makersuite.google.com/app/apikey"
echo "" 