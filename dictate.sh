#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"
export LANG="de_DE.UTF-8"
export LC_ALL="de_DE.UTF-8"
MODEL="$HOME/whisper-models/ggml-large-v3-turbo.bin"
WAV="/tmp/dictate.wav"
PIDFILE="/tmp/dictate.pid"

if [ -f "$PIDFILE" ]; then
    REC_PID=$(cat "$PIDFILE")
    kill -INT "$REC_PID" 2>/dev/null
    rm -f "$PIDFILE"
    sleep 0.5
    afplay /System/Library/Sounds/Pop.aiff &

    whisper-cli -m "$MODEL" -l de -nt -otxt -of "/tmp/dictate" \
      --no-speech-thold 0.6 -t 4 "$WAV" >/dev/null 2>&1
    TEXT=$(cat "/tmp/dictate.txt" | tr -d '\n' | sed 's/^ *//')

    case "$TEXT" in
      "Vielen Dank."|"Vielen Dank"|"Untertitelung"*|"Untertitel"*|"Untertitel."*) TEXT="" ;;
    esac
    [ -z "$TEXT" ] && { rm -f "$WAV" "/tmp/dictate.txt"; exit 0; }

    printf '%s' "$TEXT" | pbcopy
    osascript -e 'tell application "System Events" to keystroke "v" using command down'

    rm -f "$WAV" "/tmp/dictate.txt"
else
    ffmpeg -f avfoundation -i ":0" -ar 16000 -ac 1 -y "$WAV" >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
    sleep 0.8
    afplay /System/Library/Sounds/Tink.aiff
fi
