"""Local text-to-speech via Kokoro v1.0 (ONNX). Invoked by the `speak` wrapper."""
import argparse
import os
import signal
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

# So a SIGTERM from Hammerspoon's stop hotkey also kills afplay, not just us.
_player = []
def _stop(*_):
    if _player and _player[0].poll() is None:
        _player[0].terminate()
    sys.exit(143)
signal.signal(signal.SIGTERM, _stop)
signal.signal(signal.SIGINT, _stop)

MODEL = Path(os.environ.get("KOKORO_MODEL", "~/.local/share/kokoro/kokoro-v1.0.onnx")).expanduser()
VOICES = Path(os.environ.get("KOKORO_VOICES", "~/.local/share/kokoro/voices-v1.0.bin")).expanduser()
VOICE = os.environ.get("KOKORO_VOICE", "af_heart")
SPEED = float(os.environ.get("KOKORO_SPEED", "1.0"))
LANG = os.environ.get("KOKORO_LANG", "en-us")


def die(msg, code=1):
    print(f"speak: {msg}", file=sys.stderr)
    sys.exit(code)


def main():
    ap = argparse.ArgumentParser(description="Local TTS via Kokoro v1.0")
    ap.add_argument("text", nargs="*", help="text to speak (omit to read stdin)")
    ap.add_argument("-o", "--output", help="save WAV to file instead of playing")
    ap.add_argument("-v", "--voice", default=VOICE, help=f"voice (default: {VOICE})")
    ap.add_argument("-s", "--speed", type=float, default=SPEED, help=f"speed (default: {SPEED})")
    ap.add_argument("-l", "--lang", default=LANG, help=f"language code (default: {LANG})")
    ap.add_argument("--list-voices", action="store_true", help="list available voices and exit")
    args = ap.parse_args()

    if not MODEL.exists():
        die(f"model not found at {MODEL}\n        download it or set KOKORO_MODEL")
    if not VOICES.exists():
        die(f"voices not found at {VOICES}\n        download it or set KOKORO_VOICES")

    import warnings
    warnings.filterwarnings("ignore")

    from kokoro_onnx import Kokoro
    import numpy as np

    kokoro = Kokoro(str(MODEL), str(VOICES))

    if args.list_voices:
        for v in sorted(kokoro.get_voices()):
            print(v)
        return

    text = " ".join(args.text) if args.text else sys.stdin.read()
    text = text.strip()
    if not text:
        die("no text provided")

    print(f"[speak] synthesizing ({len(text)} chars, voice={args.voice})...", file=sys.stderr)
    samples, sr = kokoro.create(text, voice=args.voice, speed=args.speed, lang=args.lang)
    pcm16 = (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16).tobytes()

    if args.output:
        with wave.open(args.output, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sr)
            wf.writeframes(pcm16)
        print(f"[speak] wrote {args.output}", file=sys.stderr)
        return

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    try:
        with wave.open(tmp, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sr)
            wf.writeframes(pcm16)
        _player.append(subprocess.Popen(["afplay", tmp]))
        _player[0].wait()
    finally:
        os.unlink(tmp)


if __name__ == "__main__":
    main()
