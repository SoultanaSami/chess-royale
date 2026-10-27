# Schachschlachtfeld · Godot

Mobiles 3D-Schach auf **8×8** in einer mittelalterlichen Bibliothek. Der native Godot-Slice ist unabhängig vom älteren Webprojekt im übergeordneten Verzeichnis.

## Start

[Launch.command](Launch.command) startet die vorhandene Godot-Installation. Alternativ [project.godot](project.godot) in Godot 4.7.2 importieren und F5 drücken. Eine andere Installation lässt sich über `GODOT_BIN` auswählen.

## Festgelegte Spielregeln

- **Ein legaler Figurenzug pro Seite.** Danach wechselt die Seite unmittelbar; Animationen oder KI-Timer verändern die Regeln nicht. Es gibt weder eine zweite Aktion noch einen Knopf zum Überspringen des Zuges.
- Ein Schlag entfernt die gegnerische Figur sofort. Es gibt keine HP, Angriffsschäden, Rüstung, verwundeten Einheiten, Mana, Upgrades oder Level.
- Ein Zug darf den eigenen König nicht im Schach lassen. Das Spiel markiert nur legale Zielfelder; gefesselte Figuren und Abwehrzüge werden berücksichtigt.
- Ein bedrohter König erhält einen roten Runenrahmen, einen roten Ring und ein gut sichtbares **Ausrufezeichen**. Die Warnung steht zusätzlich im HUD und bleibt auch ohne ausgewählte Figur sichtbar.
- Schachmatt beendet die Partie. Der König wird **niemals geschlagen**. Aufgabe zählt als Sieg der Gegenseite; Patt als Remis.
- Die kurze und lange Rochade gelten für beide Seiten und alle Turmvarianten: ursprünglicher König und Turm ungezogen, alle Zwischenfelder frei, König weder im Schach noch über ein angegriffenes Feld oder auf ein angegriffenes Zielfeld. Der Turm zieht gleichzeitig mit; die Rochade ist ein Zug. Zurückziehen stellt verlorene Rochaderechte nicht wieder her.
- Bauern dürfen beim ersten Zug von ihrer Startreihe zwei Felder vorwärts ziehen, wenn beide frei sind. En passant ist nur unmittelbar nach dem gegnerischen Doppelschritt erlaubt und darf den eigenen König nicht gefährden.
- Auf der letzten Reihe wählt der Spieler **Dame, Turm, Läufer oder Springer**. Erst mit der Wahl wird die Umwandlung ausgeführt; es entsteht keine zusätzliche Figur. Die KI wählt die Dame.

## Decks und Aufstellung

Das Hauptmenü öffnet zuerst die Bibliothek. **DECKS** führt zur Auswahl der Figurenvarianten vor der Partie. Die bestehende spielbare Testaufstellung bleibt derzeit klassisch mit **16 Figuren je Seite**:

| Klasse | Anzahl | Weiße Startfelder |
| --- | ---: | --- |
| Bauern | 8 | A2–H2 |
| Türme | 2 | A1, H1 |
| Springer | 2 | B1, G1 |
| Läufer | 2 | C1, F1 |
| Dame | 1 | D1 |
| König | 1 | E1 |

Schwarz steht entsprechend auf Reihe 7 und 8. Die beiden Türme sind unabhängig als Battering Ram, Siege Trebuchet oder Stone Golem konfigurierbar. Die Varianten verwenden aktuell dieselben klassischen Regeln ihrer Klasse. Alte Gift-, Rüstungs-, Flächen- und Fernschadenseffekte sind entfernt; neue Spezialregeln werden erst nach ihrer Festlegung umgesetzt.

**Noch offen:** Eine mögliche reduzierte Testarmee aus zehn Figuren benötigt eine festgelegte Zusammensetzung und Startaufstellung. Bis dahin bleibt die vorhandene 16er-Aufstellung auf 8×8 spielbar.

Während einer laufenden oder pausierten Partie ist die Variantenauswahl gesperrt. **PARTIE AUFGEBEN** beendet die Partie mit einem Ergebnis; anschließend ist der Deckbereich wieder zugänglich. Alte gespeicherte Decks behalten gültige Figurenplätze; früher gewählte Zauber werden nicht übernommen. Es gibt keine Nachbeschwörung oder Upgrades während des Matches.

## Decks → Zauber: nur Vorschau

Diese Abteilung zeigt zwei Einträge mit sichtbaren Beschreibungen. Sie hat keine Ausrüstungs-, Kosten- oder Einsatzbedienelemente und verändert die Armee nicht.

| Zauber | Festgelegte Wirkung | Noch offen |
| --- | --- | --- |
| **Fesseln** | Fesselt eine Einheit für eine Runde auf ihrem aktuellen Feld. Sie kann sich nicht bewegen. | Weitere Auswirkungen, etwa auf Angriffe, sowie Einsatzregeln und Königssicherheit. |
| **Schutz** | Schützt eine eigene Einheit für die nächste gegnerische Runde. Ein gegnerischer Schlagversuch scheitert vollständig: beide Figuren bleiben auf ihren Ausgangsfeldern, der gegnerische Zug ist verbraucht. | Einsatzregeln und Wechselwirkungen mit Schach/Königssicherheit. |

**Nicht festgelegt und nicht implementiert:** Zauberkosten, Einsatzlimits, Nachziehen, Ersatz eines normalen Zuges oder zusätzliche Aktionen. Es gibt noch keinen Zauberbefehl in der Match-API. Individuelle Figurenfähigkeiten und weitere Deckzusammenstellungsregeln bleiben ebenfalls offen.

## Bedienung und mobile Darstellung

Figur antippen, dann ein markiertes Zielfeld wählen. Für eine Rochade den König auswählen und C1/G1 beziehungsweise C8/G8 antippen. Für eine Umwandlung erscheint eine Auswahl mit vier großen Schaltflächen. Das Menü pausiert den lokalen Gegner; Fortsetzen führt höchstens einen ausstehenden Gegnerzug aus. Ein neues Match kann nicht durch einen alten KI-Timer verändert werden.

Das gesamte Brett liegt in einem eigenen 3D-Viewport. Auswahl-Informationen stehen außerhalb des Brettes; sie enthalten Bewegungsregeln statt HP/ATK. Es gibt keine Kampfhand und keinen Fernangriffsschalter. Touch-Bedienelemente sind mindestens 48 logische Pixel hoch. Hochformat, Querformat, mobile Pixeldichte und sichere Bildschirmränder werden berücksichtigt.

Esc schließt die Auswahl oder öffnet das Menü. Rechtsklick hebt die Auswahl auf. Die Leertaste überspringt keinen Zug.

## Musik

Im Menü spielt **„Glut der alten Krone“**: ein eigenes, 2:34 Minuten langes Orchesterstück mit Solo-Violine, dunklen Streichern, Hörnern und wortlosem Männerchor. Arrangement 3 stellt echte Orchester- und Tenortrommeln mit Marschrhythmus und Wirbeln in den Vordergrund. Ein schnelleres Tempo, kurze Cellobögen und kräftige Hornantworten tragen den Aufbau; die Harfe tritt zurück. Die fertige Stereomischung liegt als mobilefreundliches [OGG-Audio](audio/music/ashen_crown.ogg) vor; [MIDI-Noten](audio/music/ashen_crown.mid) ermöglichen eine weitere Bearbeitung. [Credits und Renderanleitung](audio/music/CREDITS.md) dokumentieren die CC0-Instrument- und Vokalaufnahmen sowie den Aufbau.

Beim Start einer Partie blendet [music_director.gd](audio/music_director.gd) zur [Trommelschleife](audio/music/battle_drums.ogg) über: ein langsamerer, schwerer Marschpuls aus tieferen, stärker akzentuierten Paukenschlägen und resonanten Antworttrommeln; kurze Snarewirbel setzen alle vier Takte Akzente. 64 BPM geben den Schlägen mehr Raum und Gewicht; die kräftigere Abmischung bleibt durch sanfte Spitzenbegrenzung sauber. Die 16-taktige Schleife dauert etwa eine Minute und kommt ohne Violine oder andere Melodieinstrumente aus. Der Hall läuft über die Schleifengrenze weiter. Menüwechsel innerhalb desselben Musikbereichs starten das Stück nicht neu; schnelle Wechsel brechen alte Überblendungen ab, damit ausstehende Stop-Callbacks keinen neuen Titel unterbrechen. Beide Stücke verwenden den Musikregler in den Einstellungen. Die Renderer sind [compose_crown_theme.py](tools/compose_crown_theme.py) für das Menü und [compose_battle_drums.py](tools/compose_battle_drums.py) für die Partie.

## Architektur

| Schicht | Einstieg | Aufgabe |
| --- | --- | --- |
| Daten | [catalog.gd](data/catalog.gd), [variants.json](data/variants.json), [Schema](data/piece_variant.schema.json) | Aussehen, Klassen, Bewegungsbeschreibungen und Status offener Regeln; keine Kampfwerte |
| Stellung | [board_state.gd](domain/board_state.gd), [unit_state.gd](domain/unit_state.gd) | Figurenpositionen, Bewegungshistorie, ursprüngliche Rochadeteilnehmer, En-passant-Fenster und isolierte Kopien |
| Regeln | [movement_rules.gd](domain/movement_rules.gd) | Geometrische Angriffskarte getrennt von legalen Zügen; Königssicherheit durch Simulation einschließlich Rochade/En passant |
| Schlagen | [combat_system.gd](domain/combat_system.gd) | Sofortige Entfernung eines Gegners, niemals des Königs |
| Match | [game_manager.gd](domain/game_manager.gd) | Validierte Züge, unmittelbarer Seitenwechsel, Umwandlung, Matt/Patt und Aufgabe |
| Gegner | [tactical_ai.gd](domain/tactical_ai.gd) | Bewertet ausschließlich legale Schachzüge und nutzt dieselben Befehle wie die Oberfläche |
| Darstellung | [board_view.gd](presentation/board_view.gd), [unit_view.gd](presentation/unit_view.gd) | Bewegungsanimation, Sockel, Modelle, persistente Schachwarnung |
| Oberfläche | [game_root.gd](presentation/game_root.gd), [war_room_hud.gd](ui/war_room_hud.gd) | Bildschirmwechsel, Touch, Deck-Vorschau, Umwandlungsdialog, abbrechbare KI-Verzögerung |

[Asset Requirement Document](assets/ASSET_REQUIREMENTS.md): Nano-Banana-/Meshy-Workflow, Modellkonventionen und mobile Budgets. Modelle haben Bodenursprung, +Y nach oben, −Z nach vorne. Sockel, Namensschild und Auswahlring kommen aus der Darstellung, ohne HP-/Schadensanzeigen.

## Prüfung und Grenzen

```sh
"$GODOT_BIN" --headless --path . --editor --import --quit
"$GODOT_BIN" --headless --path . --script res://tests/rules_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/music_test.gd
"$GODOT_BIN" --path . --script res://tests/ui_smoke.gd
```

Die Regeltests prüfen Referenz-Zugbaumzahlen (Startstellung 20/400/8902, Kiwipete 48/2039, Turm-Bauern-Endspiel 2812 auf Tiefe 3), Königssicherheit, beidseitige Rochaden und Rechteverlust, En passant einschließlich Selbstschach, alle vier Umwandlungen, sofortiges Schlagen, Matt/Patt/Aufgabe und KI-Zugwechsel. Die UI-Prüfung bedient die echte Szene per Maus/Touch, prüft den Musikwechsel zwischen Menü und Partie und verändert die Fenstergröße; währenddessen nicht in das Testfenster klicken.

**Aktuell verifiziert:** 427 Regelprüfungen und 376 Oberflächenprüfungen bestanden, einschließlich 390×844, 844×390, 360×800, 375×667 und 360×640.

Die Smartphone-Prüfungen laufen in Godot-Fenstern auf dem Mac. Physische Android-/iOS-Geräte und installierbare Mobil-Builds sind noch nicht verifiziert. Der Slice hat einen lokalen Gegner, keinen Netzwerkmodus und keinen Match-Speicher. Wiederholungs-/50-Züge-Remisverfahren und automatische Remiserkennung bei toten Stellungen sind noch nicht umgesetzt; Matt und Patt werden erkannt.
