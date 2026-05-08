# dictate

Local speech-to-text *and* text-to-speech on macOS, fully offline on Apple Silicon.
- STT via [whisper.cpp](https://github.com/ggerganov/whisper.cpp) (Metal).
- TTS via [Kokoro v1.0](https://github.com/thewh1teagle/kokoro-onnx) (ONNX, ~325 MB, Apache 2.0).

## What's here

- `bin/dictate` — terminal flow: record from mic, press Enter to stop, prints transcript and copies to clipboard.
- `bin/dictate-toggle` — stateful two-shot version (1st call starts recording, 2nd stops + transcribes). Used by the global hotkey and any non-interactive context (e.g. Claude Code's bash tool, where stdin can't deliver an Enter).
- `bin/dictate-find-mic` — picks the first available avfoundation audio device from a preference list. Lets the MX Brio "just work" when plugged in, falling back to the built-in mic.
- `bin/speak` — text-to-speech: takes text from args or stdin, plays via `afplay`. `pbpaste | speak` reads the clipboard aloud.
- `hammerspoon/init.lua` — Hammerspoon config that binds **⌥⌘D** (Option+Cmd+D) to toggle dictation and paste the transcript into the focused app.

## Prerequisites

```sh
brew install whisper-cpp ffmpeg
brew install --cask hammerspoon       # optional, for the global hotkey
pip install kokoro-onnx               # for bin/speak
```

Then download a Whisper GGML model. The scripts default to `large-v3-turbo`:

```sh
mkdir -p ~/.local/share/whisper-cpp/models
curl -L -o ~/.local/share/whisper-cpp/models/ggml-large-v3-turbo.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

(About 1.5 GB. Override the path with `WHISPER_MODEL=/path/to/model.bin`.)

And the Kokoro v1.0 model + voices for TTS (~350 MB total):

```sh
mkdir -p ~/.local/share/kokoro
curl -L -o ~/.local/share/kokoro/kokoro-v1.0.onnx \
  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -L -o ~/.local/share/kokoro/voices-v1.0.bin \
  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
```

(Override paths with `KOKORO_MODEL` / `KOKORO_VOICES`.)

## Install

```sh
./install.sh                      # symlinks bin/* into ~/.local/bin
./install.sh --with-hammerspoon   # also symlinks hammerspoon/init.lua
```

Make sure `~/.local/bin` is on your `PATH`.

If you opted into Hammerspoon, open the app once and grant it **Accessibility** *and* **Microphone** permissions in System Settings → Privacy & Security. The TCC scope is per-app, so iTerm/Terminal granting mic access does not transfer.

## Usage

**Terminal:**
```sh
dictate            # speak, press Enter to stop
```

**Global hotkeys** (after installing the Hammerspoon config):
- ⌥⌘D once → "dictating..." overlay, mic is live
- ⌥⌘D again → "transcribing..." overlay, transcript pastes at your cursor
- ⌥⌘S → speak the currently selected text via Kokoro; press again to stop playback

**Two-shot (non-interactive):**
```sh
dictate-toggle     # starts recording, exits 0 silently
# ... speak ...
dictate-toggle     # stops, prints transcript on stdout
```

**Text-to-speech:**
```sh
speak "hello world"           # text as args
echo "hello" | speak          # text via stdin
pbpaste | speak               # read the clipboard aloud
speak -o out.wav "..."        # save to file instead of playing
speak --list-voices           # 54 voices: af_*, am_*, bf_*, bm_*, plus other languages
speak -v am_michael -s 1.1 "..."   # pick a voice, nudge speed
```

## Configuration (env vars)

| Variable | Purpose | Default |
|---|---|---|
| `WHISPER_MODEL` | Path to GGML model file | `~/.local/share/whisper-cpp/models/ggml-large-v3-turbo.bin` |
| `WHISPER_LANG` | Language code or `auto` | `en` |
| `DICTATE_AUDIO_DEV` | avfoundation device, e.g. `:0`, `:MX Brio` | (auto via `dictate-find-mic`) |
| `DICTATE_MIC_PREFERENCE` | Comma-separated mic preference order | `MX Brio,Razer Kiyo,MacBook Pro Microphone` |
| `DICTATE_INTERNAL_MIC` | Name of the built-in mic; skipped when lid is closed | `MacBook Pro Microphone` |
| `KOKORO_MODEL` | Path to Kokoro ONNX model | `~/.local/share/kokoro/kokoro-v1.0.onnx` |
| `KOKORO_VOICES` | Path to Kokoro voices file | `~/.local/share/kokoro/voices-v1.0.bin` |
| `KOKORO_VOICE` | Default voice for `speak` | `af_heart` |
| `KOKORO_SPEED` | Default speech speed | `1.0` |
| `KOKORO_LANG` | Default language code | `en-us` |
| `KOKORO_PYTHON` | Python interpreter to use for `speak` | (auto-detected: first python with `kokoro_onnx` importable) |

When the laptop lid is closed (clamshell mode), `dictate-find-mic` skips the
built-in mic from both the preference list and the ultimate fallback, so it
holds out for whatever USB device is attached (Brio, Kiyo, headset, etc.).
Lid state is read from `ioreg -k AppleClamshellState`.

List your audio devices to see what names work:
```sh
ffmpeg -hide_banner -f avfoundation -list_devices true -i ""
```

## Why these choices

- **whisper.cpp over Python whisper / faster-whisper:** Metal acceleration on Apple Silicon. faster-whisper has no Metal path on Mac.
- **`large-v3-turbo`:** real-time on M-series chips with no quality cliff vs. `large-v3`.
- **`avfoundation` named devices:** robust to plug/unplug reordering — `:0` shifts when you add a USB mic, `:MX Brio` doesn't.
- **`dictate-toggle` as a separate script:** Claude Code's bash tool doesn't pass interactive stdin, so the Enter-to-stop pattern fails there. The toggle pattern works in any context.
- **Symlinks instead of copies:** edit once in the repo, changes apply immediately without re-running the installer.
- **Kokoro v1.0 for TTS:** top open-weight TTS in 2025 by quality-per-byte. 82M params, Apache 2.0, multiple natural voices, runs faster than real-time on Apple Silicon via ONNX Runtime + CoreML.
- **`af_heart` as the default voice:** consistently rated the most natural English voice in the v1.0 release. Override with `-v` or `KOKORO_VOICE`.
- **stdlib `wave` + `afplay` over `soundfile`/`sox`:** no extra dependencies. `afplay` ships with macOS.

## Alternatives worth knowing

- **WhisperKit CLI** (Argmax, Swift+CoreML) — often the fastest Whisper on Apple Silicon (uses ANE). `brew install whisperkit-cli`.
- **mlx-whisper** (Apple MLX, Python) — fast, but no built-in mic streaming.
- **Parakeet-MLX** (Nvidia Parakeet on MLX) — often beats Whisper, English-only.
- **mlx-audio** — Kokoro/CSM/etc. on Apple MLX. Marginally faster than ONNX once warm; ONNX wins on cold-start and packaging simplicity.
- **Sesame CSM-1B** — more natural conversational prosody than Kokoro, but ~10x larger and slower.
- **macOS `say`** — zero-setup, ships with the OS. Quality is far below Kokoro but useful as a fallback.

## Troubleshooting

- "no audio captured" → check ffmpeg can see your devices: `ffmpeg -f avfoundation -list_devices true -i ""`. If your terminal isn't in System Settings → Privacy → Microphone, grant it.
- The hotkey runs but nothing pastes → Hammerspoon is missing **Accessibility** permission.
- The hotkey runs but ffmpeg fails → Hammerspoon is missing **Microphone** permission. Force a fresh prompt: `tccutil reset Microphone org.hammerspoon.Hammerspoon`, then quit + reopen Hammerspoon.
- Wrong mic chosen → `dictate` logs the device it picked. Override with `DICTATE_AUDIO_DEV=:Name` or reorder `DICTATE_MIC_PREFERENCE`.
- `speak: no python with kokoro_onnx found` → run `pip install kokoro-onnx` in the env you want, or set `KOKORO_PYTHON=/path/to/python`. The wrapper probes `python3` on PATH, miniconda, anaconda, pyenv, and homebrew/system Python in that order.
- `speak` runs but no audio plays → check system output device; `afplay` uses the default. Test with `afplay /System/Library/Sounds/Glass.aiff`.
