# Basselefant

Abstrakte, audio-reaktive macOS-SwiftUI-App fuer Elektro/Techno/House-orientierte Visuals.

## Features

- Hybrid-Erkennung:
  - Direkter Abruf von aktuell laufenden Tracks aus `Spotify` und `Music.app` (AppleScript).
  - Mikrofon-Fallback (internes oder externes Mikrofon) mit Echtzeit-Audioanalyse.
  - `Nur Direkt` deaktiviert das Mikrofon komplett (kein laufender Audio-Tap).
  - Standardstart ist `Nur Direkt`; Mikro wird erst ueber das Menue (`Audio`) aktiviert.
- Audio-Metriken in Echtzeit:
  - Energie, Bass/Mid/Treble, Spektralzentrum, Puls und Tempo-Schaetzung.
- Kunstorientierte Visualisierung:
  - Erkennbarer, abstrakter Basselefant mit beat-animierten Ohren, Ruessel und Koerper.
  - Goa-inspirierte Aura, Rhythmus-Nebel und Partikel-Regen als Surround-Layer.
- AirPlay-/TV-Workflow:
  - Externe Anzeige im UI auswaehlbar.
  - AirPlay- oder Apple-TV-Displays werden markiert, sobald sie in macOS verbunden sind.

## Start

```bash
swift build
swift run BasselefantApp
```

## iOS Variante (iPhone, Hochkant + Quer)

Die iOS-App liegt in `iOSApp/BasselefantiOS.xcodeproj`.

Wichtig:
- iOS nutzt Mikrofon-Reaktivitaet.
- Das Mikrofon ist standardmaessig aus und wird nur ueber das iOS-Menue (Mic-Icon) aktiviert.
- Direkter Spotify/Music-Track-Abruf wie auf macOS ist auf iOS systembedingt nicht verfuegbar.
- Orientierungen sind aktiviert: Portrait + Landscape (echtes Fullscreen auf iPhone).

Device-Build (unsigned, fuer technischen Check):

```bash
./scripts/build_ios_device.sh
```

Auf iPhone installieren (Xcode):
1. `iOSApp/BasselefantiOS.xcodeproj` in Xcode oeffnen.
2. Target `BasselefantiOS` -> `Signing & Capabilities` -> dein `Team` waehlen.
3. iPhone anschliessen und als Run Destination waehlen.
4. `Run` druecken.

## App in /Applications installieren

```bash
./scripts/build_app.sh
```

Das Skript baut Release, generiert das Icon, erstellt `dist/Basselefant.app` und installiert nach `/Applications/Basselefant.app`.

## DMG fuer Weitergabe erstellen

```bash
./scripts/package_dmg.sh
```

Erzeugt `dist/Basselefant.dmg` mit `Basselefant.app` und einem `Applications`-Shortcut.

## Git-Update-Workflow

Initial (einmalig):

```bash
git clone https://github.com/blackmaddin/Basselefant.git
cd Basselefant
```

Update + Neuinstallation:

```bash
./scripts/update_from_git.sh
```

Optional mit Branch:

```bash
./scripts/update_from_git.sh main
```

## Update fuer Dummies (vollautomatisch)

In der App unter `Settings`:
- `Auto Update (alle 6h)` aktivieren
- oder `Jetzt updaten und neu starten` klicken

Ohne App-Menue (Terminal, ein Befehl):

```bash
./scripts/dummy_update.sh
```

Das Skript klont bei Bedarf automatisch nach `~/.basselefant/repo`, zieht Updates von GitHub und installiert neu nach `/Applications/Basselefant.app`.

## Berechtigungen

- Beim ersten Start Mikrofon-Zugriff erlauben.
- Fuer direkten Spotify/Music-Abruf kann macOS nach Automationszugriff fragen.

### Wenn Direkt-Erkennung nicht funktioniert

1. In Basselefant-Menue `Audio` -> `Request Spotify/Music Access` klicken.
2. Danach `Audio` -> `Open Automation Settings` und unter `Automation` fuer `Basselefant` Zugriff auf Spotify/Music aktivieren.
3. Spotify/Music einmal neu starten.

## Struktur

- `Sources/BasselefantApp/Audio`: Mikrofon-Capture + DSP/FFT-Analyse
- `Sources/BasselefantApp/Recognition`: Direktes Now-Playing-Reading
- `Sources/BasselefantApp/Visuals`: Canvas-basierte abstrakte Visual Engine
- `Sources/BasselefantApp/Display`: Externe Display-Ausgabe (AirPlay/TV-Flow)
- `Sources/BasselefantApp/Design`: Farb- und Stilpalette
- `Sources/IconGenerator`: Generiert das Elefanten-Icon (`.icns`)
