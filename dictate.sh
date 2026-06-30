#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"
export LANG="de_DE.UTF-8"
export LC_ALL="de_DE.UTF-8"
MODEL="$HOME/whisper-models/ggml-small.bin"
WAV="/tmp/dictate.wav"
PIDFILE="/tmp/dictate.pid"

# Mikrofon-Index dynamisch per Name aufloesen.
# Reihenfolge = Prioritaet. VB-Cable wird nie genommen (stummes Geraet).
find_mic_index() {
    local devices
    devices=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1)
    local audio
    audio=$(printf '%s\n' "$devices" | sed -n '/audio devices:/,$p')

    for want in "MacBook Air-Mikrofon" "MacBook" "OBSBOT Tail Air Microphone"; do
        local idx
        idx=$(printf '%s\n' "$audio" | grep -i "$want" | grep -iv "VB-Cable" | \
              sed -nE 's/.*\[([0-9]+)\].*/\1/p' | head -n1)
        if [ -n "$idx" ]; then
            printf '%s' "$idx"
            return 0
        fi
    done
    return 1
}

if [ -f "$PIDFILE" ]; then
    REC_PID=$(cat "$PIDFILE")
    kill -INT "$REC_PID" 2>/dev/null
    rm -f "$PIDFILE"
    sleep 0.5
    afplay /System/Library/Sounds/Pop.aiff &

    whisper-cli -m "$MODEL" -l de -nt -otxt -of "/tmp/dictate" \
      --no-speech-thold 0.6 -tp 0.0 --entropy-thold 2.8 \
      -t 8 "$WAV" >/dev/null 2>&1
    TEXT=$(cat "/tmp/dictate.txt" | tr -d '\n' | sed 's/^ *//; s/ *$//')

    # Bekannte Whisper-Halluzinationen entfernen (auch mitten im Text)
    TEXT=$(printf '%s' "$TEXT" | sed -E 's/[\(\[](Musik|Music|Applaus|Applause|BLANK_AUDIO|Geraeusche|Sound)[^\)\]]*[\)\]]//gI' | sed 's/^ *//; s/ *$//')

    case "$TEXT" in
      "Vielen Dank."|"Vielen Dank"|"Untertitelung"*|"Untertitel"*|"Untertitel."*) TEXT="" ;;
    esac
    [ -z "$TEXT" ] && { rm -f "$WAV" "/tmp/dictate.txt"; exit 0; }

    printf '%s' "$TEXT" | pbcopy
    osascript -e 'tell application "System Events" to keystroke "v" using command down'

    rm -f "$WAV" "/tmp/dictate.txt"
else
    MIC=$(find_mic_index)
    if [ -z "$MIC" ]; then
        afplay /System/Library/Sounds/Basso.aiff
        osascript -e 'display notification "Kein Mikrofon gefunden" with title "Dictate"'
        exit 1
    fi
    ffmpeg -f avfoundation -i ":${MIC}" -ar 16000 -ac 1 -y "$WAV" >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
    sleep 0.8
    afplay /System/Library/Sounds/Tink.aiff
fi
