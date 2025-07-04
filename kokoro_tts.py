from kokoro import KPipeline
import soundfile as sf
import sys
import torch

if len(sys.argv) < 2:
    print("Usage: python3 kokoro_tts.py <text> [voice] [speed] [filename]")
    sys.exit(1)

text = sys.argv[1]
voice = sys.argv[2] if len(sys.argv) > 2 else 'af_heart'  # Default female voice
speed = float(sys.argv[3]) if len(sys.argv) > 3 else 1.3  # Default speed 1.3x (faster)
filename = sys.argv[4] if len(sys.argv) > 4 else 'output.wav'  # Default filename

# Set up device for Apple Silicon acceleration
device = 'mps' if torch.backends.mps.is_available() else 'cpu'
print(f"Using device: {device}")

pipeline = KPipeline(lang_code='a', repo_id='hexgrad/Kokoro-82M')
# Move model to MPS device for acceleration
if hasattr(pipeline, 'model') and pipeline.model is not None:
    pipeline.model = pipeline.model.to(device)
    print(f"Model moved to {device} device")

generator = pipeline(text, voice=voice, speed=speed)
for i, (gs, ps, audio) in enumerate(generator):
    sf.write(filename, audio, 22050)  # Optimized sample rate for speech
    break  # Only need the first output 