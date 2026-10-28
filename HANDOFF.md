# Projektübergabe: Schachschlachtfeld

Stand: 28. Oktober 2026. Aktives Projekt: [godot/](godot/), unabhängig vom älteren Node/Webprojekt. Vor Änderungen Git-Status und diese Datei lesen; mehrere Sessions bearbeiten dieselbe Arbeitskopie.

## Aktuelle Nutzerentscheidung

Die frühere Mobile-/8×8-Vision wurde für den Hauptausbau durch ein **PC-Taktik-Deckbuilder-Spiel** ersetzt. Zuletzt verlangt: vollständiger lokaler Spielablauf, große organische Höhenkarte, begrenzte Schachbewegungen, düstere hochwertige Darstellung, 2×2-Gebäude, spürbare Einheitensteuerung, Tarot-HUD und **am Ende alles pushen**. Diese Push-/Commit-Autorisierung ist explizit; frühere allgemeine Hinweise gegen ungefragtes Committen sind hierfür kein Hindernis.

## Jetzt implementiert

Hauptmenü → **TAKTISCHE SCHLACHT**: Deckauswahl mit fünf Rollen, danach lokale Partie gegen KI auf den **24×32 Aschenklippen**. Vier Startfiguren pro Seite, 10 Gold, drei KP pro Zug. Karten per Klick, 1–5 oder Drag-and-drop neben der eigenen Burg rekrutieren; Bewegungen, Schüsse und horizontale Bauernformationen kosten je einen KP. Goldminen werden am Zugende über einen unbestrittenen Randbereich erobert und liefern ab dem nächsten eigenen Zug Einkommen. Zwei Naturminen liefern +2, drei zentrale/seitliche Erweiterungen +3, dazu +2 Grundeinkommen.

Beide Burgen und alle fünf Minen belegen **2×2 solide Felder**. Zustand liegt einmal am nordwestlichen Anker; alle vier Felder blockieren Bewegung. Jeder Teil einer Burg kann bedroht werden. Bleibt die Belagerung am eigenen Zugende bestehen, fällt ein Schild; drei verlorene Schilde oder bewiesenes Matt beenden die Partie. Mehrschritt-Verteidigung wird inkrementell und ohne falsches Matt bei unfertiger Suche geprüft. Pause, Aufgabe, Neustart und optionaler Zugtimer sind implementiert.

Bewegung: Bauer bis 2 vorwärts/1 diagonal schlagen, Springer 1 L-Sprung beziehungsweise Dawn Riders 2 verkettete Sprünge innerhalb Radius 4, Läufer 3 diagonal, Turm 4 orthogonal, Dame 4. Wald kostet 2 Bewegungspunkte, Türme dürfen auch nicht im Wald rekrutiert werden. Klippen brauchen Rampen; Springer überspringen Hindernisse/Höhen. Hochland-Läufer haben +1 diagonale Fernkampfreichweite; bergauf ist Aufklärung nötig.

Rendering ist auf **Forward+** umgestellt und tatsächlich auf Metal 4.0 / Apple M4 geprüft: SDFGI, SSAO, volumetrischer Nebel (.02), lokale Talnebel, Bloom (.9), ACES (Kontrast 1.15), Mitternachtshimmel, abgesenktes Wasser, triplanare Stein-Normaltexturen, Schatten und GPU-Feuer/Fackeln. Kein globales Raster; cyanfarbene Bewegungs- und rote Angriffsdekale erscheinen lokal. Gebäudebanner/Goldsymbole/3 Schild-Pips ersetzen rohe Textbeschriftungen.

Einheiten heben sich bei Auswahl, springen bei Bewegungen und landen mit Staub, Grenzblitz und .15 s Kamerastoß. Vorschau zeigt Flugbahn und hypothetische Angriffsdeckung ohne Spielzustandsänderung. Tarotkarten sind freistehend, mit großen Frontporträts, Kostenhexagon, Rollenemblem, 30 px Hover-Lift/1.12× Zoom und grauen gesperrten Zuständen. Kompakte Metallwappen zeigen Gold/KP und Burgschilde.

## Mitgelieferte GLB

`/Users/samisoultana/Downloads/ast_d02a2c4488.glb` ist **ein gepanzerter Axt-Springer mit eigenem Sockel**, keine Goldmine. Er ist als [Ironbound Knight](godot/data/units/ironbound.tres) auswählbar; Quelle/Wrapper liegen unter [ironbound/](godot/assets/models/ironbound/). Seine Materialien bleiben erhalten und es wird kein zweiter Sockel erzeugt. Die bestehenden Foundation-Assets anderer Sessions bleiben für die übrigen Figuren erhalten.

Neue Gebäude-Assets: `mine_prefab` oder `castle_prefab` in [BattlefieldConfig](godot/data/battlefield_config.gd) zuweisen. [ObjectiveView](godot/presentation/objective_view.gd) hat einen normalisierten `AssetSocket`; Spiellogik hängt nicht vom Modell ab. Ohne Asset bleibt maßstabsgetreue prozedurale Ersatzgeometrie.

## Einstiegspunkte und Regeln für weitere Arbeit

- [Architektur](godot/docs/TACTICAL_FOUNDATION.md) und [Godot-README](godot/README.md) beschreiben den aktuellen Stand. Die alten Texte „nur Geländetest / CP noch offen“ sind überholt.
- Regeln: [TacticalMatch](godot/domain/tactical_match.gd), [TacticalCommands](godot/domain/tactical_commands.gd), [TacticalMovement](godot/domain/tactical_movement.gd), [SiegeSearch](godot/domain/siege_search.gd), [BoardState](godot/domain/board_state.gd).
- Präsentation: [BoardView](godot/presentation/board_view.gd), [UnitView](godot/presentation/unit_view.gd), [ObjectiveView](godot/presentation/objective_view.gd), [BattleAtmosphere](godot/presentation/battle_atmosphere.gd), [TacticalHUD](godot/ui/tactical_hud.gd).
- Die klassischen 8×8-Regeln bleiben separat unter **KLASSISCHES SCHACH** erhalten. Keine taktischen Kosten oder Reichweiten in klassische Figuren ohne UnitData einführen.
- Tatsächliche Spezialfähigkeiten bleiben über UnitAbility erweiterbar; noch nicht beschriebene Feuer-/Zeitreise-Regeln nicht erfinden. Netzwerk-Multiplayer ist nicht Teil dieses lokalen Slices.
- Vorhandene Menü-/Trommelmusik und der persistente Musikregler bleiben bestehen. Kein neuer Musikauftrag offen.
- Nicht fremde Änderungen zurücksetzen oder lokale Datenbanken anfassen. Der Nutzer hat diesen Stand einschließlich vorhandener Asset-Arbeit zum Push beauftragt; den aktuellen Branch-/Remote-Stand vor jedem späteren Push erneut prüfen.

## Prüfung

Godot-Binary hier: `/Users/samisoultana/Downloads/Godot-2.app/Contents/MacOS/Godot` (4.7.2). [Launch.command](godot/Launch.command) oder das Projekt im Editor starten.

Grün in dieser Umsetzung: 427 klassische Regeln, 380 klassische UI, 45 Taktik-Daten, 53 Match, 60 Terrain/Reichweiten, 153 Gebäude, 37 vollständige Taktik-UI, 37 Vertical-Slice-Rendering/Interaktion — insgesamt **1.192 Prüfungen**. Native Tests bewegen den Mauszeiger; nicht parallel laufen lassen. Temporäre echte Screenshots liegen unter `/tmp`, z. B. `/tmp/vertical-slice-final.png`; sie sind keine Spielassets.
