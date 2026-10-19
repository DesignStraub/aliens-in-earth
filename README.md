# Kometen & Kronen

Ein Echtzeit-Strategiespiel im Stil von Age of Empires II, gebaut mit Godot 4.7.
Mittelalter trifft Aliens: **Säugetiere**, **Aliens** und **lebende Pflanzen** kämpfen um eine zufällig erzeugte Karte.

## Starten
Ordner in Godot 4.7 öffnen (Projekt importieren → `project.godot`) und F5 drücken.
Oder im Terminal:

    /Applications/Godot.app/Contents/MacOS/Godot --path .

## Was schon drin ist
- **3 Völker** mit eigener Pixelgrafik, Einheitennamen und Boni
- **5 Zeitalter**: Dunkle Zeit → Feudalzeit → Burgzeit → Imperialzeit → Moderne.
  Jeder Aufstieg schaltet Gebäude und Einheiten frei, und vorhandene Einheiten steigen eine Stufe auf (Veteran, Elite, …)
- **Ressourcen**: Nahrung (Beeren, Farmen), Holz (Wälder abholzen), Gold, Stein. Arbeiter liefern sie an Dorfzentrum, Mühle oder Lager ab
- **Schere-Stein-Papier**: Speer > Reiter > Schützen > Speer. Belagerung zerstört Gebäude, verliert aber gegen Reiter
- **Mauern, Palisaden, Tore** (nur für das eigene Volk passierbar), Wachtürme. Gebäude blockieren die Wegfindung, bis sie zerstört sind.
  Militär greift Mauern an, die ihm den Weg versperren
- **Zufallskarten**: Seen, Strände, Wälder als natürliche Grenzen (abholzbar), Startressourcen für jeden Spieler
- **Computer-Gegner**: baut die Wirtschaft auf, steigt in Zeitaltern auf, kontert deine Einheiten und greift in Wellen an
- Minimap, Sammelpunkte, Bauschleife, Reparieren

## Steuerung
| Eingabe | Aktion |
|---|---|
| Linksklick / Ziehen | Auswählen (Shift: hinzufügen) |
| Rechtsklick | Bewegen, sammeln, bauen, reparieren, angreifen, Sammelpunkt |
| WASD / Pfeile / Bildschirmrand / mittlere Maustaste | Kamera |
| Mausrad | Zoom |
| H | Dorfzentrum |
| . (Punkt) | Nächster untätiger Arbeiter |
| Entf | Auswahl löschen |
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
| `scripts/hud.gd` / `minimap.gd` | Oberfläche und Startmenü |

## Entwickler-Tests
    Godot --headless --path . -- --autotest   # KI gegen KI, druckt Statistiken
    Godot --path . -- --uitest                # skriptet Spielerbefehle, speichert Screenshots
