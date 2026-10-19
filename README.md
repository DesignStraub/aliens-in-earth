# Kometen & Kronen

Ein klassisches Echtzeit-Strategiespiel mit Wirtschaft, Zeitaltern und Konter-Einheiten, gebaut mit Godot 4.7.
Mittelalter trifft Aliens: **Säugetiere**, **Aliens** und **lebende Pflanzen** kämpfen um eine zufällig erzeugte Karte.

## Starten
Ordner in Godot 4.7 öffnen (Projekt importieren → `project.godot`) und F5 drücken.
Oder im Terminal:

    /Applications/Godot.app/Contents/MacOS/Godot --path .

## Was schon drin ist
- **3 Völker** mit eigener Pixelgrafik, Einheitennamen und Boni
- **5 Zeitalter**: Funkenzeit → Bannerzeit → Bastionszeit → Kronenzeit → Sternenzeit.
  Jeder Aufstieg schaltet Gebäude und Einheiten frei, und vorhandene Einheiten steigen einen Rang auf (II, III, IV, V)
- **Ressourcen**: Nahrung (Beeren, Farmen), Holz (Wälder abholzen), Gold, Stein. Arbeiter liefern sie an Hauptsitz, Kornspeicher oder Sammellager ab
- **Schere-Stein-Papier**: Speer > Reiter > Schützen > Speer. Belagerung zerstört Gebäude, verliert aber gegen Reiter
- **Mauern, Palisaden, Tore** (nur für das eigene Volk passierbar), Wachtürme. Gebäude blockieren die Wegfindung, bis sie zerstört sind.
  Militär greift Mauern an, die ihm den Weg versperren
- **Zufallskarten**: Seen, Strände, Wälder als natürliche Grenzen (abholzbar), Startressourcen für jeden Spieler
- **Computer-Gegner**: baut die Wirtschaft auf, steigt in Zeitaltern auf, kontert deine Einheiten und greift in Wellen an
- **Bis zu 4 Spieler**: Jeder gegen jeden oder alle gegen dich, 3 Kartengrößen, 3 KI-Schwierigkeiten
- **Nebel des Krieges**: unerforschtes Land ist schwarz, außer Sicht wird es abgedunkelt
- **17 Technologien** in Hauptsitz, Sammellager, Kornspeicher, Kaserne, Schützenhof, Reiterhof und Kriegswerk (Gezahnte Klinge, Zähe Kittel, Glutschmiede, Bollwerkbau, Kometenstaub …)
- **Animationen**: Laufzyklen; Dorfbewohner zeigen mit Werkzeug, was sie tun (Axt, Spitzhacke, Hacke, Korb, Hammer) und tragen ihre Ladung sichtbar auf dem Rücken. Dazu Späne, Funken und Staub
- **Sound**: alle Effekte werden zur Laufzeit synthetisiert (Hacken, Bergbau, Bauen, Kampf, Schüsse je Volk, Fanfaren, Angriffsalarm)
- **Titelbildschirm, Spiel-Einrichtung, Einstellungen** (Oberflächen-Skalierung, Vollbild, Lautstärke, Kamera), Pausenmenü
- **Speichern & Laden** (F5 oder Menü)
- **Skalierung für 4K/Retina**: die Oberfläche wächst automatisch mit der Fenstergröße
- Minimap mit Angriffs-Ping, Sammelpunkte, Bauschleife, Reparieren

## Steuerung
| Eingabe | Aktion |
|---|---|
| Linksklick / Ziehen | Auswählen (Shift: hinzufügen) |
| Rechtsklick | Bewegen, sammeln, bauen, reparieren, angreifen, Sammelpunkt |
| WASD / Pfeile / Bildschirmrand / mittlere Maustaste | Kamera |
| Mausrad | Zoom |
| H | Hauptsitz |
| . (Punkt) | Nächster untätiger Arbeiter |
| Entf | Auswahl löschen |
| F5 | Speichern |
| Esc / F10 | Pausenmenü |
| Mauern | Ziehen = Linie, Shift = weiterbauen |

## Aufbau
| Datei | Inhalt |
|---|---|
| `scripts/data.gd` | **Alle Spielwerte**: Völker, Zeitalter, Einheiten, Gebäude, Konter-Boni. Balancing hier |
| `scripts/art.gd` | Prozedurale Pixelgrafik (ASCII-Vorlagen für Einheiten, gezeichnete Gebäude). Später durch PNGs ersetzbar |
| `scripts/map_gen.gd` | Zufallskarten-Generator |
| `scripts/main.gd` | Welt: Raster, Wegfindung (AStarGrid2D je Spieler), Wirtschaft, Eingabe |
| `scripts/unit.gd` / `building.gd` | Verhalten von Einheiten und Gebäuden |
| `scripts/ai.gd` | Computer-Gegner |
| `scripts/hud.gd` / `minimap.gd` | Oberfläche, Titelbildschirm, Menüs |
| `scripts/fog.gd` | Nebel des Krieges |
| `scripts/sfx.gd` | Prozedurale Sound-Effekte |
| `scripts/settings.gd` | Einstellungen (`user://settings.cfg`) |

## Entwickler-Tests
    Godot --headless --path . -- --autotest   # KI gegen KI, druckt Statistiken
    Godot --headless --path . -- --autotest4  # 4 KIs gegeneinander
    Godot --path . -- --uitest                # skriptet Spielerbefehle, speichert Screenshots

## Lizenz
Open Source unter der [MIT-Lizenz](LICENSE): Jeder darf das Spiel und den Code frei verwenden, verändern, weitergeben und auch kommerziell nutzen.
Mitmachen ist willkommen – Issues und Pull Requests gern gesehen.
