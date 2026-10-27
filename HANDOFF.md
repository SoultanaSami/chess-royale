# Projektübergabe: Schachschlachtfeld

Stand: 27. Oktober 2026

Diese Datei ist der sitzungsübergreifende Einstieg für das Projekt. Vor Änderungen erst Status, lokale Diffs und diese Datei lesen. Das Repository enthält sowohl ein älteres Webprojekt als auch das aktive native Godot-Projekt.

## Neuester Auftrag: PC-Taktik-Deckbuilder

Die neue Nutzervorgabe ersetzt für den neuen Modus die bisherige Mobile-/8×8-Ausrichtung: größeres Gelände, fünf Rollen im Reserve-Deck, Ressourcen, 3 CP pro Zug und Burgen mit Garnisonsschilden. Der Nutzer hat ausdrücklich zuerst **UnitData-Architektur und erweitertes Grid** beauftragt; HUD/CP/Siege folgen in weiteren Schritten.

Dieser erste Schritt ist implementiert: Hauptmenü → **TAKTIKFELD** öffnet eine 12×16-Bewegungsprobe mit vier Figuren je Team, Fluss/Übergängen, Felsen, vier neutralen Ressourcenpunkten und zwei Burgen. Beide Armeen sind frei steuerbar; es gibt dort noch keine taktische Partie, KI oder Siegbedingung. 1920×1080 Referenzauflösung, 1440×810 Startfenster; WASD/Randscrollen, Mausrad, mittlere Maustaste und F für Übersicht. 14×18 ist ebenfalls geprüft. Das klassische Spiel bleibt über SPIELEN verfügbar.

Neue Definitionen liegen in [UnitData](godot/data/unit_data.gd) und [units/](godot/data/units/); Gelände in [BattlefieldConfig](godot/data/battlefield_config.gd), [BattlefieldTileData](godot/data/battlefield_tile_data.gd) und [river_crossing.tres](godot/data/battlefields/river_crossing.tres). Die vorhandenen BoardState-/MovementRules-/BoardView-/UnitView-Klassen wurden erweitert und werden gemeinsam genutzt. [TacticalField](godot/domain/tactical_field.gd) führt bestätigte Sandbox-Aktionen aus, [UnitAbility](godot/domain/unit_ability.gd) definiert vier Hooks. Kosten, Knotenertrag und Burgschilde sind Definitions-/Zustandswerte; es gibt noch keinen Ressourcenabzug, Besitzwechsel oder CP-Verbrauch. Fernkampf ist nur als separate Geometrie vorbereitet, nicht als Angriffsbefehl.

Prüfungen nach dem Umbau: **43 Taktik-Daten-/Regeltests, 25 native Taktik-UI-Tests, 427 klassische Regeltests und 380 klassische UI-Tests bestanden.** Vollständige Architektur, Grenzen und nächste Schritte: [TACTICAL_FOUNDATION.md](godot/docs/TACTICAL_FOUNDATION.md). Die alte Musikaufgabe ist aktuell kein offener Arbeitsauftrag.

## Aktiver Projektbereich

- Godot-Projekt: [`godot/`](./godot/)
- Godot-Datei: [`godot/project.godot`](./godot/project.godot)
- Engine hier: Godot 4.7.2; ausführbar unter `/Users/samisoultana/Downloads/Godot-2.app/Contents/MacOS/Godot`.
- Produktspezifikation und Spielregeln: [`godot/README.md`](./godot/README.md). Die genaueren Regeln dort sind maßgeblich; das separate [`STATE.md`](./STATE.md) ist nur für explizite Studio-Zyklen.

## Bestehender klassischer Modus (vor der neuen PC-Taktik-Ausrichtung)

Das Ziel ist ein mobiles, lokales 3D-Schachspiel in mittelalterlicher Bibliotheks-/Kriegsraumoptik. Das Brett ist 8×8. Es gelten normale legale Schachzüge mit Königssicherheit, Rochade, En passant, Umwandlung, Schachmatt, Patt und Aufgabe. Ein legaler Zug pro Seite und normaler unmittelbarer Seitenwechsel. Geschlagene Einheiten werden entfernt. Keine HP, Angriffsschäden, Mana, Upgrades oder Beschwörungen.

Der Deckbildschirm konfiguriert die 16 normalen Startplätze vor der Partie. Turmvarianten werden unabhängig gewählt; sie nutzen momentan dieselben Schachregeln. „Fesseln“ und „Schutz“ sind nur Zaubervorschauen ohne erfundene Einsatzregeln. Der Deckbau ist während einer offenen Partie gesperrt. Details/noch offene Regeln stehen in `godot/README.md`.

## Musik – aktueller Stand

- Menü: [`godot/audio/music/ashen_crown.ogg`](./godot/audio/music/ashen_crown.ogg), eigenes orchestrales Thema mit Streichern, Violine, Hörnern und wortlosem Chor. Es bleibt erhalten.
- Partie: [`godot/audio/music/battle_drums.ogg`](./godot/audio/music/battle_drums.ogg), eigene instrumentale Schleife mit Pauken-/Basstrommel, Tenortrommeln und sparsamen Snare-Wirbeln. Kein Gesang, keine Violine oder Streicher.
- Der Nutzer zeigte als stilistische Referenz den Anfangstrommel-Charakter des YouTube-Soundtracks „Battle over Coruscant“ (insbesondere den Einstieg; Link war in der Unterhaltung geteilt). Gewünscht sind markante, antreibende Kriegstrommeln statt weit auseinanderliegender Einzelschläge. Die Referenz dient nur als grobe Stimmung/Richtung; keine Melodie oder konkrete Tonfolge übernehmen.
- Die aktuelle Fassung ist auf einen markanteren Marschpuls bei 84 BPM überarbeitet: tiefe Schläge auf den schweren Zählzeiten, resonante Zwischenschläge und kurze Wirbel alle vier Takte; 16 Takte, ca. 46 Sekunden, Endlosschleife. Erzeugt aus CC0-Samples. Renderer: [`godot/tools/compose_battle_drums.py`](./godot/tools/compose_battle_drums.py); MIDI/Audio-Metadaten der Menümusik im selben Ordner.
- [`godot/audio/music_director.gd`](./godot/audio/music_director.gd) wechselt zwischen Menü- und Partiemusik. Partiemusik-Zielpegel derzeit −7 dB; beide Stücke benutzen den Musikbus und den einstellbaren Musikpegel. Lautstärkeregler im Hauptmenü unter Einstellungen, Standardwert 35 %, persistent in `user://settings.cfg` via [`godot/presentation/game_root.gd`](./godot/presentation/game_root.gd) und [`godot/ui/main_menu.gd`](./godot/ui/main_menu.gd).
- Nach der jüngsten Neugenerierung wurde Godot 4.7.2 headless importiert und `git diff --check` war sauber. Die 13 Musikprüfungen bestanden vor der letzten 84-BPM-Neugenerierung (damals 56-BPM-Fassung); **Musiktests nach der aktuellen Neugenerierung noch einmal ausführen**, wenn Validierung gefragt/erforderlich ist: `"$GODOT_BIN" --headless --path godot --script res://tests/music_test.gd`.
- Samplebasierter Musikrenderer benötigt die Pakete aus `godot/tools/music-requirements.txt`; funktionierende lokale Umgebung: `/tmp/chess-score-env/bin/python`. CC0-Samplecache: `~/.cache/schachschlachtfeld/vsco2`. Trommeln neu rendern mit `/tmp/chess-score-env/bin/python godot/tools/compose_battle_drums.py`.

## Uncommitted Changes und Vorsicht

Im Arbeitsbaum liegen bereits mehrere Änderungen aus früheren Schritten, darunter Brett-/Regel-, Menü-, Einstellungs- und Musikdateien. Siehe `git status --short` und `git diff`. Nicht zurücksetzen, nicht pauschal stagen und nicht committen, solange es nicht ausdrücklich gewünscht ist. Die jüngste Musikänderung betrifft insbesondere `battle_drums.ogg`, `battle_drums.json`, `compose_battle_drums.py`, `music_director.gd`, Musik-Credits/README und den Musiktest.

## Sinnvoller nächster Schritt

Als nächsten beauftragten Ausbauschritt den taktischen CP-/Ressourcen-Controller und das Fünf-Slot-Reserve-HUD auf der neuen Grundlage aufbauen. Keine normale Schach-Königssicherheit auf die königlose Bewegungsprobe anwenden: Burgen sind Geländeziele, das neue Siege-System wird separat entwickelt. Die früheren Anweisungen gegen Ressourcen/Deployment gelten weiterhin im klassischen Modus, wurden aber durch die neueste Nutzer-Vision für den Taktikmodus ersetzt. Arbeitsbaum und Index enthalten Änderungen mehrerer Sessions; vor Edits prüfen und fremde Arbeit erhalten.
