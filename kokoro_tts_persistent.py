#!/usr/bin/env python3
"""
Persistent Kokoro TTS script that loads the model once and processes text continuously.
This reduces the delay between Gemini response and voice playback.
Optimized for Apple Silicon using MPS acceleration.
"""

import sys
import signal
import soundfile as sf
import torch
from kokoro import KPipeline
import numpy as np
import nltk
import os
nltk.download('punkt', quiet=True)
from nltk.tokenize import sent_tokenize

def signal_handler(sig, frame):
    print("Shutting down persistent TTS...")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

if len(sys.argv) < 2:
    print("Usage: python3 kokoro_tts_persistent.py <voice> [speed]")
    sys.exit(1)

voice = sys.argv[1]
# Read speed from environment variable TTS_SPEED, fallback to command line argument, then default
speed = float(os.environ.get("TTS_SPEED", sys.argv[2] if len(sys.argv) > 2 else 1.3))

# Set up device for Apple Silicon acceleration
device = 'mps' if torch.backends.mps.is_available() else 'cpu'
print(f"Using device: {device}")
print(f"Starting persistent TTS with voice: {voice}, speed: {speed}")
print("READY", flush=True)  # Signal that we're ready to receive text

# Load the pipeline once with device specification
pipeline = KPipeline(lang_code='a')
# Move model to MPS device for acceleration
if hasattr(pipeline, 'model') and pipeline.model is not None:
    pipeline.model = pipeline.model.to(device)
    print(f"Model moved to {device} device")

try:
    while True:
        # Read text from stdin
        input_line = input().strip()
        
        if not input_line:
            continue
            
        # Parse text and filename
        if '|' in input_line:
            text, basefilename = input_line.split('|', 1)
        else:
            text = input_line
            basefilename = 'output'
            
        sentences = [s.strip() for s in sent_tokenize(text) if s.strip()]
        for idx, sentence in enumerate(sentences, 1):
            if not sentence:
                continue
            filename = f"{basefilename}_{idx}.wav"
            audio_segments = []
            generator = pipeline(sentence, voice=voice, speed=speed)
            for _, _, audio in generator:
                audio_segments.append(audio)
            if audio_segments:
                full_audio = np.concatenate(audio_segments)
                sf.write(filename, full_audio, 22050)
                print(f"DONE:{filename}", flush=True)
            
except EOFError:
    print("EOF received, shutting down...")
except KeyboardInterrupt:
    print("Interrupted, shutting down...")
except Exception as e:
    print(f"Error: {e}", flush=True)
finally:
    print("Persistent TTS shutdown complete") 