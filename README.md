# dictate

Local speech-to-text on macOS via [whisper.cpp](https://github.com/ggerganov/whisper.cpp).
Press a key, speak, get text — everything runs offline on Apple Silicon (Metal).

## What's here

- `bin/dictate` — terminal flow: record from mic, press Enter to stop, prints transcript and copies to clipboard.
- `bin/dictate-toggle` — stateful two-shot version (1st call starts recording, 2nd stops + transcribes). Used by the global hotkey and any non-interactive context (e.g. Claude Code's bash tool, where stdin can't deliver an Enter).
- `bin/dictate-find-mic` — picks the first available avfoundation audio device from a preference list. Lets the MX Brio "just work" when plugged in, falling back to the built-in mic.
- `hammerspoon/init.lua` — Hammerspoon config that binds **⌥⌘D** (Option+Cmd+D) to toggle dictation and paste the transcript into the focused app.

## Prerequisites

```sh
brew install whisper-cpp ffmpeg
brew install --cask hammerspoon       # optional, for the global hotkey
```

Then download a Whisper GGML model. The scripts default to `large-v3-turbo`:

```sh
mkdir -p ~/.local/share/whisper-cpp/models
curl -L -o ~/.local/share/whisper-cpp/models/ggml-large-v3-turbo.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

(About 1.5 GB. Override the path with `WHISPER_MODEL=/path/to/model.bin`.)

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

**Global hotkey** (after installing the Hammerspoon config):
- ⌥⌘D once → "dictating..." overlay, mic is live
- ⌥⌘D again → "transcribing..." overlay, transcript pastes at your cursor

**Two-shot (non-interactive):**
```sh
dictate-toggle     # starts recording, exits 0 silently
# ... speak ...
dictate-toggle     # stops, prints transcript on stdout
```

## Configuration (env vars)

| Variable | Purpose | Default |
|---|---|---|
| `WHISPER_MODEL` | Path to GGML model file | `~/.local/share/whisper-cpp/models/ggml-large-v3-turbo.bin` |
| `WHISPER_LANG` | Language code or `auto` | `en` |
| `DICTATE_AUDIO_DEV` | avfoundation device, e.g. `:0`, `:MX Brio` | (auto via `dictate-find-mic`) |
| `DICTATE_MIC_PREFERENCE` | Comma-separated mic preference order | `MX Brio,MacBook Pro Microphone` |

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

## Alternatives worth knowing

- **WhisperKit CLI** (Argmax, Swift+CoreML) — often the fastest Whisper on Apple Silicon (uses ANE). `brew install whisperkit-cli`.
- **mlx-whisper** (Apple MLX, Python) — fast, but no built-in mic streaming.
- **Parakeet-MLX** (Nvidia Parakeet on MLX) — often beats Whisper, English-only.

## Troubleshooting

- "no audio captured" → check ffmpeg can see your devices: `ffmpeg -f avfoundation -list_devices true -i ""`. If your terminal isn't in System Settings → Privacy → Microphone, grant it.
- The hotkey runs but nothing pastes → Hammerspoon is missing **Accessibility** permission.
- The hotkey runs but ffmpeg fails → Hammerspoon is missing **Microphone** permission. Force a fresh prompt: `tccutil reset Microphone org.hammerspoon.Hammerspoon`, then quit + reopen Hammerspoon.
- Wrong mic chosen → `dictate` logs the device it picked. Override with `DICTATE_AUDIO_DEV=:Name` or reorder `DICTATE_MIC_PREFERENCE`.
