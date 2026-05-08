#!/usr/bin/env bash
# Symlink the scripts into ~/.local/bin and the Hammerspoon config into ~/.hammerspoon.
# Idempotent — safe to re-run.
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DST="$HOME/.local/bin"
HS_DST="$HOME/.hammerspoon"

mkdir -p "$BIN_DST" "$HS_DST"

for f in dictate dictate-toggle dictate-find-mic speak _speak.py; do
  ln -sfn "$REPO_DIR/bin/$f" "$BIN_DST/$f"
  echo "linked $BIN_DST/$f -> $REPO_DIR/bin/$f"
done

# Hammerspoon: only install if the user wants the global hotkey.
if [[ "${1:-}" == "--with-hammerspoon" ]]; then
  if [[ -e "$HS_DST/init.lua" && ! -L "$HS_DST/init.lua" ]]; then
    cp "$HS_DST/init.lua" "$HS_DST/init.lua.bak.$(date +%s)"
    echo "backed up existing init.lua"
  fi
  ln -sfn "$REPO_DIR/hammerspoon/init.lua" "$HS_DST/init.lua"
  echo "linked $HS_DST/init.lua -> $REPO_DIR/hammerspoon/init.lua"
  echo "next: open Hammerspoon, grant Accessibility + Microphone in System Settings, reload config"
else
  echo "(skipping hammerspoon — pass --with-hammerspoon to enable the global hotkey)"
fi
