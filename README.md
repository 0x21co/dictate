# dictate — lokales Speech-to-Text für macOS mit Whisper

Kostenlose, offline-fähige Diktierlösung für macOS. Drücke einen Hotkey, sprich, drücke nochmal — der transkribierte Text wird in das aktive Fenster eingefügt. Kein Cloud-Dienst, keine Abos.

**Gedacht für**: Claude Code CLI, SSH-Sessions, Terminal-Workflows, alle anderen Apps.

---

## Wie es funktioniert

```
Hotkey (1×) → ffmpeg nimmt vom Mikrofon auf (im Hintergrund)
Hotkey (2×) → Aufnahme stoppt → whisper-cli transkribiert lokal
              → Text landet per ⌘V im aktiven Fenster
```

- Aufnahme via **ffmpeg/AVFoundation** (macOS-nativ, zuverlässig auch auf Apple Silicon)
- Transkription via **whisper.cpp** lokal, Modell `ggml-large-v3-turbo` (Deutsch und andere Sprachen)
- Texteinfügung über Zwischenablage + AppleScript-Keystroke (robust bei Umlauten und Sonderzeichen)
- Toggle-Logik: ein Skript, ein Hotkey — kein separater Stop-Befehl nötig

---

## Schnellstart

```bash
git clone https://github.com/0x21co/dictate.git
cd dictate
bash install.sh
```

Das Installationsskript erledigt alles: Homebrew-Abhängigkeiten, Modell-Download, Skript-Installation, Hinweise zu Berechtigungen und Hotkey.

---

## Manuelle Installation

### 1. Voraussetzungen

```bash
brew install whisper-cpp ffmpeg
```

### 2. Whisper-Modell laden

```bash
mkdir -p ~/whisper-models
curl -L -o ~/whisper-models/ggml-large-v3-turbo.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

Das Modell ist ~800 MB groß und läuft vollständig lokal — keine Internetverbindung beim Diktieren nötig.

Alternativen bei langsamer Hardware:

| Modell | Größe | Geschwindigkeit | Genauigkeit |
|--------|-------|-----------------|-------------|
| `ggml-medium.bin` | ~480 MB | schneller | gut |
| `ggml-large-v3-turbo.bin` | ~800 MB | mittel | sehr gut |
| `ggml-large-v3.bin` | ~1,5 GB | langsam | exzellent |

### 3. Skript installieren

```bash
mkdir -p ~/bin
cp dictate.sh ~/bin/dictate.sh
chmod +x ~/bin/dictate.sh
```

`~/bin` muss im PATH sein:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 4. Binary-Name prüfen

Je nach whisper-cpp-Version heißt das Binary `whisper-cli` oder `whisper-cpp`:

```bash
which whisper-cli whisper-cpp
```

Falls nur `whisper-cpp` existiert, in `dictate.sh` ersetzen:

```bash
sed -i '' 's/whisper-cli/whisper-cpp/g' ~/bin/dictate.sh
```

---

## macOS-Berechtigungen

Zwei Berechtigungen müssen einmalig erteilt werden:

### Mikrofon
**Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon**
→ Terminal (und/oder iTerm2) aktivieren

Falls kein Dialog erscheint, einmal manuell auslösen:
```bash
ffmpeg -f avfoundation -i ":0" -t 1 /tmp/mic_test.wav && afplay /tmp/mic_test.wav
```

### Bedienungshilfen (Tastatureingabe)
**Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen**
→ Terminal (und/oder iTerm2) aktivieren

> Wenn du Automator als Hotkey-Launcher nutzt, muss **Automator** ebenfalls in beiden Listen stehen — nicht nur das Terminal.

---

## Hotkey einrichten

### Option A: Automator (kostenlos, macOS-Bordmittel)

1. **Automator** öffnen → Neues Dokument → **Schnellaktion**
2. Oben: "Arbeitsablauf erhält" → **keine Eingabe**
3. Aktion **"Shell-Skript ausführen"** in die Arbeitsfläche ziehen
4. Inhalt:
   ```bash
   $HOME/bin/dictate.sh
   ```
5. Als **"Diktat"** sichern
6. **Systemeinstellungen → Tastatur → Tastaturkurzbefehle → Dienste → Allgemein**
   → "Diktat" auswählen → Hotkey vergeben (z.B. `⌃⌥D` oder `⌃Y`)

### Option B: Hammerspoon (kostenlos, flexibler)

```lua
-- ~/.hammerspoon/init.lua
hs.hotkey.bind({"ctrl"}, "y", function()
  hs.task.new("/Users/DEINNAME/bin/dictate.sh", nil):start()
end)
```

---

## Workflow

```
1. Fokus ins Zielfenster (Terminal, Claude CLI, Browser, etc.)
2. Hotkey drücken  →  kurzen "Tink"-Ton abwarten
3. Sprechen  (bis zu 30 Sekunden)
4. Hotkey nochmal drücken
5. "Pop"-Ton ertönt, Transkription läuft (~2–5 Sekunden)
6. Text erscheint an der Cursorposition
```

**Wichtig**: Erst nach dem Tink-Ton sprechen — ffmpeg braucht ~0,8 s zum Öffnen des Mikrofons.

---

## Konfiguration

Alle Einstellungen sind direkt in `dictate.sh` als Variablen oben im Skript:

| Variable | Standard | Beschreibung |
|----------|----------|--------------|
| `MODEL` | `~/whisper-models/ggml-large-v3-turbo.bin` | Pfad zum Whisper-Modell |
| `WAV` | `/tmp/dictate.wav` | Temporäre Aufnahmedatei |
| `PIDFILE` | `/tmp/dictate.pid` | PID-Datei für Toggle-Logik |

Sprache ändern (z.B. Englisch): in der `whisper-cli`-Zeile `-l de` durch `-l en` ersetzen.

Maximale Aufnahmedauer: ffmpeg hat kein hartes Zeitlimit — die Aufnahme läuft bis zum zweiten Hotkey-Druck. Du kannst ein Limit mit `-t 60` in der ffmpeg-Zeile einbauen.

---

## Troubleshooting

### Kein Text erscheint, kein Ton

Skript manuell testen:
```bash
~/bin/dictate.sh   # startet Aufnahme
~/bin/dictate.sh   # stoppt + transkribiert
```
Fehlermeldungen sind hier sichtbar, die Automator schluckt.

### Aufnahme stumm (afplay gibt Stille aus)

```bash
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A20 "audio"
```
Das MacBook-Mikrofon sollte als `[0]` erscheinen. Falls nicht:

```bash
# In dictate.sh die Gerätennummer anpassen:
ffmpeg -f avfoundation -i ":1" ...   # z.B. Gerät [1] probieren
```

Mikrofon-Berechtigung fehlt → Systemeinstellungen → Datenschutz → Mikrofon → Terminal aktivieren.

### "Vielen Dank" als Output (Whisper-Halluzination)

Passiert, wenn die Aufnahme zu wenig oder gar keine Sprache enthält:
- Zu früh gesprochen (vor dem Tink-Ton)? → Warten auf den Ton
- Mikrofon-Pegel zu leise? → Systemeinstellungen → Ton → Eingabe → Eingangslautstärke erhöhen

Das Skript filtert bekannte Halluzinationen bereits heraus und fügt bei Stille-Output nichts ein.

### Umlaute kaputt (ä → `√§`)

`LANG` und `LC_ALL` sind im Skript gesetzt. Falls das Problem per Hotkey auftritt, aber nicht manuell: Automator erbt manchmal keine Locale. Prüfen:
```bash
locale   # sollte de_DE.UTF-8 oder UTF-8 zeigen
```
Workaround: Im Automator-Skript die Locale nochmal explizit setzen:
```bash
export LANG=de_DE.UTF-8
$HOME/bin/dictate.sh
```

### Per Hotkey blinkt die Menüleiste, aber kein Text

Automator findet `ffmpeg` oder `whisper-cli` nicht. Die PATH-Erweiterung im Skript deckt den Standard-Homebrew-Pfad ab (`/opt/homebrew/bin`). Bei Intel-Macs liegt Homebrew unter `/usr/local/bin`:
```bash
# In dictate.sh anpassen:
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
```

---

## Systemanforderungen

- macOS 13 (Ventura) oder neuer
- Apple Silicon oder Intel Mac
- ~1 GB freier Speicher (Modell)
- Homebrew

---

## Hintergrund

Entstanden aus dem Wunsch, Claude Code per Sprache zu bedienen — ohne Cloud-STT-Dienste, ohne Abo-Tools wie Superwhisper oder MacWhisper. Der Stack ist absichtlich minimal:

- `ffmpeg` ersetzt `sox` für die Aufnahme (stabiler auf Apple Silicon mit CoreAudio/AVFoundation)
- `whisper.cpp` läuft nativ auf Apple Silicon mit Metal-Beschleunigung
- Die Toggle-Logik (PID-Datei) ermöglicht einen einzigen Hotkey für Start und Stop

Das Skript ist auf Deutsch konfiguriert, funktioniert aber mit jeder von Whisper unterstützten Sprache.
