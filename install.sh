#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# install.sh — Whisper Speech-to-Text Diktierwerkzeug für macOS
# Getestet auf macOS 14+ mit Apple Silicon und Intel
# ---------------------------------------------------------------------------

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }
heading() { echo -e "\n${YELLOW}=== $* ===${NC}"; }

# ---------------------------------------------------------------------------
heading "Homebrew"
if ! command -v brew &>/dev/null; then
    warn "Homebrew nicht gefunden – wird installiert …"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    info "Homebrew vorhanden"
fi

# Brew-Pfad sicherstellen (Apple Silicon vs Intel)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
heading "Abhängigkeiten"
BREW_PKGS=(whisper-cpp ffmpeg)
for pkg in "${BREW_PKGS[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        info "$pkg bereits installiert"
    else
        warn "$pkg wird installiert …"
        brew install "$pkg"
    fi
done

# ---------------------------------------------------------------------------
heading "Whisper-Modell"
MODEL_DIR="$HOME/whisper-models"
MODEL_FILE="$MODEL_DIR/ggml-large-v3-turbo.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"

mkdir -p "$MODEL_DIR"

if [[ -f "$MODEL_FILE" ]]; then
    info "Modell bereits vorhanden: $MODEL_FILE"
else
    warn "Lade ggml-large-v3-turbo (~800 MB) …"
    curl -L --progress-bar -o "$MODEL_FILE" "$MODEL_URL"
    info "Modell heruntergeladen"
fi

# ---------------------------------------------------------------------------
heading "dictate.sh installieren"
BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dictate.sh"
if [[ ! -f "$SCRIPT_SRC" ]]; then
    error "dictate.sh nicht gefunden – bitte das gesamte Repo klonen, nicht nur install.sh"
fi

cp "$SCRIPT_SRC" "$BIN_DIR/dictate.sh"
chmod +x "$BIN_DIR/dictate.sh"
info "dictate.sh → $BIN_DIR/dictate.sh"

# ~/bin in PATH eintragen (falls noch nicht vorhanden)
for RC in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [[ -f "$RC" ]] && ! grep -q 'PATH.*HOME/bin' "$RC"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$RC"
        info "PATH ergänzt in $RC"
    fi
done

# ---------------------------------------------------------------------------
heading "whisper-cli Binary prüfen"
if command -v whisper-cli &>/dev/null; then
    info "whisper-cli gefunden: $(which whisper-cli)"
elif command -v whisper-cpp &>/dev/null; then
    warn "Binary heißt whisper-cpp statt whisper-cli – passe dictate.sh an …"
    sed -i '' 's/whisper-cli/whisper-cpp/g' "$BIN_DIR/dictate.sh"
    info "dictate.sh angepasst (whisper-cpp)"
else
    error "Weder whisper-cli noch whisper-cpp gefunden – bitte 'brew install whisper-cpp' prüfen"
fi

# ---------------------------------------------------------------------------
heading "Mikrofon-Gerät erkennen"
AUDIO_DEVICES=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep "AVFoundation audio")
echo "$AUDIO_DEVICES"
warn "Stelle sicher, dass dein Mikrofon als Gerät [0] gelistet ist."
warn "Falls nicht: dictate.sh anpassen (avfoundation -i ':X' mit der richtigen Nummer)."

# ---------------------------------------------------------------------------
heading "Berechtigungen"
echo ""
echo "Zwei macOS-Berechtigungen müssen manuell erteilt werden:"
echo ""
echo "  1. Mikrofon-Zugriff für Terminal:"
echo "     Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon"
echo "     → Terminal (oder iTerm2) aktivieren"
echo ""
echo "  2. Bedienungshilfen (für Tastatureingabe per Skript):"
echo "     Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen"
echo "     → Terminal (oder iTerm2) aktivieren"
echo ""
echo "  Falls du Automator als Hotkey-Launcher nutzt:"
echo "     Automator ebenfalls in beiden Listen aktivieren."
echo ""

# ---------------------------------------------------------------------------
heading "Hotkey einrichten (Automator)"
echo "Anleitung für einen globalen Hotkey ohne Drittanbieter-App:"
echo ""
echo "  1. Automator öffnen → Neues Dokument → Schnellaktion"
echo "  2. Oben: 'Arbeitsablauf erhält' → 'keine Eingabe'"
echo "  3. Aktion 'Shell-Skript ausführen' hineinziehen"
echo "  4. Inhalt:"
echo '       $HOME/bin/dictate.sh'
echo "  5. Sichern als 'Diktat'"
echo "  6. Systemeinstellungen → Tastatur → Tastaturkurzbefehle"
echo "     → Dienste → Allgemein → 'Diktat' → Hotkey vergeben (z.B. ⌃⌥D)"
echo ""

# ---------------------------------------------------------------------------
heading "Fertig"
info "Installation abgeschlossen."
echo ""
echo "  Workflow:"
echo "    1. Hotkey drücken  → Aufnahme startet (Tink-Ton)"
echo "    2. Sprechen"
echo "    3. Hotkey nochmal  → Aufnahme stoppt (Pop-Ton), Text wird eingefügt"
echo ""
echo "  Manueller Test:"
echo "    ~/bin/dictate.sh   # startet Aufnahme"
echo "    ~/bin/dictate.sh   # stoppt + transkribiert"
echo ""
