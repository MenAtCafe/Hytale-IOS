#!/bin/bash
# Capture Hytale's live OpenGL call profile.
#
# Why a script: HytaleClient refuses to start on its own ("Started without
# launcher arguments"). It only runs when the launcher starts it, so the
# tracer has to be injected into the launcher and inherited by the game.
#
# What it does:
#   1. quits the running launcher
#   2. relaunches it with gltrace.dylib injected
#   3. you press Play, play for ~30 seconds, then quit the game
#   4. gltrace.log collects every GL function the game asks for
#
# The tracer only records function names. No game data, no account data.

set -u
cd "$(dirname "$0")"
LOG="$PWD/gltrace.log"
: > "$LOG"

echo "Quitting the launcher..."
osascript -e 'quit app "Hytale Launcher"' >/dev/null 2>&1 || true
sleep 2

export DYLD_INSERT_LIBRARIES="$PWD/gltrace.dylib"
export GLTRACE_LOG="$LOG"

echo "Starting launcher with tracer. Log: $LOG"
"/Applications/Hytale Launcher.app/Contents/MacOS/f2p-evo" &
PID=$!

cat <<'MSG'

  -> Press Play in the launcher.
  -> Play for ~30 seconds (menu + walking around is ideal).
  -> Quit the game, then press Ctrl-C here.

MSG

wait $PID
echo "Launcher exited. Log lines: $(wc -l < "$LOG" 2>/dev/null || echo 0)"
