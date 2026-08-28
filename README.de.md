[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

# install-md-viewer

Installationsprogramm und Aktualisierungstool für [md-viewer](https://github.com/aydiler/md-viewer), einen Markdown-Viewer für Linux.

[English Version](README.md)

## Inhaltsverzeichnis

- [Über dieses Projekt](#über-dieses-projekt)
- [Funktionen](#funktionen)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Verwendung](#verwendung)
- [Optionale Integrationen](#optionale-integrationen)
- [Umgebungsvariablen](#umgebungsvariablen)
- [Lizenz](#lizenz)

## Über dieses Projekt

`install-md-viewer` ist ein Bash-Skript, das md-viewer auf Linux-x86_64-Systemen herunterlädt, verifiziert und installiert. Es kümmert sich um die Binärinstallation, Lizenzdateien und optionale Integrationen mit Desktop-Umgebungen, topgrade und chezmoi.

Dieses Repository enthält nur das Installationsskript — nicht md-viewer selbst.

## Funktionen

- Lädt das neueste md-viewer-Release von GitHub herunter
- Verifiziert die Integrität der Binärdatei durch Sha256-Checksummen-Überprüfung
- Installiert in `~/.local/bin/md-viewer` mit Lizenzdateien
- Verfolgt die installierte Version, um eine Neuinstallation zu überspringen, wenn bereits die aktuelle Version vorhanden ist
- Registriert md-viewer optional als Standard-Handler für Markdown-Dateien (mit `xdg-mime`) — fragt interaktiv oder wird über `--set-default`/`--no-default` gesteuert
- Optionale topgrade-Integration für automatische Aktualisierungen
- Optionale chezmoi-Integration zur Verwaltung der topgrade-Konfiguration
- Respektiert die XDG Base Directory-Spezifikation

## Voraussetzungen

**System:**
- Linux x86_64
- Bash

**Laufzeit-Abhängigkeiten:**
- curl
- grep, head, sed
- tar
- install, mktemp
- sha256sum

**Optionale Tools:**
- `xdg-mime` und `update-desktop-database` — für Desktop-Integration
- `topgrade` — für topgrade-Integration
- `chezmoi` — für chezmoi-Integration

## Installation

Repository klonen und das Installationsskript ausführen:

```bash
git clone https://github.com/Pat9496/install-md-viewer.git
cd install-md-viewer
bash install-md-viewer.sh
```

Das Skript installiert md-viewer in `~/.local/bin/md-viewer`. `~/.local/bin` muss in `$PATH` enthalten sein.

## Verwendung

### Vollständige Installation

Das Skript ohne Argumente oder mit dem Argument `install` ausführen:

```bash
bash install-md-viewer.sh
# oder
bash install-md-viewer.sh install
```

Dies führt folgende Schritte aus:
1. Lädt und installiert die md-viewer-Binärdatei herunter
2. Installiert LICENSE und THIRD_PARTY_NOTICES in `~/.local/share/licenses/md-viewer/`
3. Richtet Desktop-Integration ein (installiert die `.desktop`-Datei und entscheidet, ob md-viewer als Standard-Handler für Markdown-Dateien registriert wird — siehe unten)
4. Richtet topgrade-Integration ein (falls topgrade installiert ist)
5. Richtet chezmoi-Integration ein (falls chezmoi initialisiert ist)

Standardmäßig wird interaktiv entschieden, ob md-viewer Standard-Handler für Markdown-Dateien wird: Wenn das Skript von einem Terminal aus ausgeführt wird, fragt es `[J/n]`. Um die Nachfrage zu überspringen, kann eines der folgenden Flags übergeben werden:

```bash
bash install-md-viewer.sh --set-default   # als Standard-Handler registrieren, ohne Nachfrage
bash install-md-viewer.sh --no-default    # nicht als Standard-Handler registrieren, ohne Nachfrage
```

Diese Flags sind nur mit `install` (dem Standard-Modus) gültig und können nicht mit `--update` kombiniert werden. Falls das Skript nicht interaktiv (ohne Terminal) ohne eines dieser Flags ausgeführt wird, ändert es den Standard-Handler nicht.

### Nur Aktualisierung

Mit `--update` ausführen, um eine neuere Version herunterzuladen und zu installieren, ohne Integrationen zu ändern:

```bash
bash install-md-viewer.sh --update
```

Dies ist nützlich, um md-viewer zu aktualisieren, ohne Desktop- und Integrations-Setup erneut auszuführen.

## Optionale Integrationen

### Desktop-Integration

Das Skript installiert immer eine `.desktop`-Datei in `~/.local/share/applications/md-viewer.desktop` und aktualisiert die Desktop-Datenbank, falls `update-desktop-database` verfügbar ist.

Falls `xdg-mime` verfügbar ist, entscheidet das Skript zusätzlich, ob md-viewer als Standard-Handler für die MIME-Typen `text/markdown` und `text/x-markdown` registriert wird. Dies folgt der in [Verwendung](#verwendung) beschriebenen Priorität: Ein explizites `--set-default`/`--no-default`-Flag hat Vorrang; ansonsten wird in einem interaktiven Terminal gefragt; ansonsten bleibt der Standard-Handler unverändert. Falls `xdg-mime` überhaupt nicht verfügbar ist, wird die MIME-Typ-Registrierung vollständig übersprungen.

### Topgrade-Integration

Falls `topgrade` installiert ist, erstellt das Skript eine benutzerdefinierte Befehlskonfiguration unter `~/.config/topgrade.d/md-viewer.toml`. Dies ermöglicht es `topgrade`, md-viewer automatisch zusammen mit anderen Systempaketen zu aktualisieren.

Das Skript führt einen Test-Lauf der topgrade-Konfiguration durch, falls topgrade verfügbar ist.

### Chezmoi-Integration

Falls `chezmoi` initialisiert ist (hat ein Quellverzeichnis mit Inhalten), fügt das Skript die topgrade-Konfigurationsdatei zu chezmoi-Management hinzu. Dies ermöglicht es chezmoi, die topgrade-Konfiguration auf mehreren Maschinen zu verfolgen und zu synchronisieren.

Falls chezmoi nicht installiert oder nicht initialisiert ist, wird dieser Schritt übersprungen.

## Umgebungsvariablen

- `XDG_DATA_HOME` — Verzeichnis für Anwendungsdatendateien (Standard: `~/.local/share`)
- `XDG_CONFIG_HOME` — Verzeichnis für Konfigurationsdateien (Standard: `~/.config`)
- `MD_VIEWER_ALLOW_ROOT` — Auf `1` setzen, um das Skript als root auszuführen (Standard: `0`, Skript weigert sich, als root zu laufen, falls nicht gesetzt)

## Lizenz

MIT-Lizenz — siehe [LICENSE](LICENSE)-Datei.
