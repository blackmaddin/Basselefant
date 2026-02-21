# Basselefant

Abstrakte, audio-reaktive macOS-SwiftUI-App fuer Elektro/Techno/House-orientierte Visuals.

## Features

- Hybrid-Erkennung:
  - Direkter Abruf von aktuell laufenden Tracks aus `Spotify` und `Music.app` (AppleScript).
  - Mikrofon-Fallback (internes oder externes Mikrofon) mit Echtzeit-Audioanalyse.
  - `Nur Direkt` deaktiviert das Mikrofon komplett (kein laufender Audio-Tap).
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

## Berechtigungen

- Beim ersten Start Mikrofon-Zugriff erlauben.
- Fuer direkten Spotify/Music-Abruf kann macOS nach Automationszugriff fragen.

## Struktur

- `Sources/BasselefantApp/Audio`: Mikrofon-Capture + DSP/FFT-Analyse
- `Sources/BasselefantApp/Recognition`: Direktes Now-Playing-Reading
- `Sources/BasselefantApp/Visuals`: Canvas-basierte abstrakte Visual Engine
- `Sources/BasselefantApp/Display`: Externe Display-Ausgabe (AirPlay/TV-Flow)
- `Sources/BasselefantApp/Design`: Farb- und Stilpalette
- `Sources/IconGenerator`: Generiert das Elefanten-Icon (`.icns`)
