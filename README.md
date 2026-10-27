# Chess Royale

Die aktuelle Godot-Entwicklung zum PC-Taktikspiel steht in [godot/README.md](godot/README.md); der Sitzungsstand in [HANDOFF.md](HANDOFF.md). Die folgende Dokumentation beschreibt das ältere Webprojekt.

Ein mobiles Schachspiel mit Runenmagie, eigenen Figurenvarianten und einer mittelalterlichen Burghalle. Node.js, WebSocket, SQLite und eine PWA ohne Frontend-Buildschritt.

## Starten

```sh
sh scripts/start.sh
```

Der Start verwendet die lokale Node-Laufzeit in `.runtime`, sofern vorhanden. Auf anderen Rechnern Node.js 24 oder neuer installieren, anschließend `npm ci` und `npm start` ausführen.

- Desktop: **http://localhost:3000** öffnet den Geräte-Simulator. Zwei Geräte haben voneinander getrennte Gastkonten.
- Ohne Rahmen: **http://localhost:3000/?frame=off**.
- Echtes Handy: mit demselben WLAN verbinden und die beim Serverstart angezeigte `http://<WLAN-IP>:3000` öffnen. Der Server lauscht auf allen Netzwerkschnittstellen; eine macOS-Firewallabfrage für Node zulassen.
- PWA: auf localhost oder einer HTTPS-Adresse installierbar. Über eine gewöhnliche HTTP-WLAN-Adresse funktionieren Spiel und Touch-Steuerung, aber Browser erlauben dort normalerweise keine Service Worker/PWA-Installation. Für Installation auf dem Handy eine vertrauenswürdige HTTPS-Verbindung verwenden.
- `PORT=3001 sh scripts/start.sh` verwendet einen anderen Port. `NODE_ENV=production` deaktiviert die Entwicklerfunktionen.

## Inhalte und Regeln ergänzen

Alle Inhaltsdefinitionen stehen in [shared/catalog.js](shared/catalog.js): Figuren, Rollen, Seltenheiten, Zauber, Truhen, Arenen und Balancing. Für eine neue Variante einen Datensatz mit eindeutiger ID, Rolle, Seltenheit, Mana, Beschreibung und Effekt anlegen. Neue **Mechaniken** brauchen zusätzlich einen geprüften Handler in [src/engine.js](src/engine.js); Daten allein führen keinen beliebigen Code aus.

Das Deck enthält je eine Variante für König, Dame, Turm, Läufer, Springer und Bauer sowie drei verschiedene Königszauber. Training erlaubt das Ausprobieren aller Varianten. Normales Schach ist separat als klassischer Modus spielbar.

Eine Runde umfasst zwei Halbzüge. Beschwörungen, aktive Fähigkeiten und Königszauber verbrauchen einen Zug. Nach einer Aktion muss der eigene König sicher stehen. Könige werden nie durch Magie oder Flächenschaden entfernt. Die Oberfläche zeigt nur vom Server freigegebene Aktionen. Zeitspulen stellt die Brettstellung zurück, erstattet aber keine Bedenkzeit.

## Entwicklung und Prüfung

```sh
PATH="$PWD/.runtime/bin:$PATH" npm test
```

Die automatische Prüfung nutzt eigene In-Memory-Datenbanken. Gastkonten und Partien werden regulär in `data/chess-royale.sqlite` gespeichert. Ein Gasttoken wird pro simuliertem Gerät im Browser gespeichert; ohne dieses Token lässt sich das Gastkonto nicht wiederherstellen.

Der Screenshot-Knopf des Simulators exportiert das aktuelle Spiel als PNG. Netzwerksimulation wird je Gerät eingestellt. Entwicklerwerkzeuge werden zusätzlich auf dem Server auf echte lokale Anfragen beschränkt.

## Copilot-Agenten

Die workspace-lokale Copilot-Integration liegt in `.github/agents/`, `.github/prompts/` und `.github/skills/studio/`. `orchestrator` koordiniert die verborgenen Fachagenten; `/studio` startet einen begrenzten Improve–Critic–Verify-Zyklus, `/direction` hält eine ausdrücklich vorgegebene Stilrichtung in `DESIGN.md` fest. Details stehen in [den Projektanweisungen](.github/copilot-instructions.md). Es werden keine globalen Nutzerprofile installiert und keine Modell-IDs festgeschrieben. Die Struktur orientiert sich am [lean-context-kit Agent Integration Guide](https://github.com/SoulNassim/lean-context-kit/blob/main/AGENT_README.md), wurde aber auf dieses Projekt und seine bestehenden Playwright-Prüfungen zugeschnitten.

Für Browser-Prüfungen den Server in einem separaten Terminal mit einer In-Memory-Datenbank starten:

```sh
DB_PATH=:memory: PORT=3000 sh scripts/start.sh
```

Danach in einem weiteren Terminal nur die benötigten Prüfungen ausführen, etwa `node scripts/check-ui.mjs`, `node scripts/check-polish.mjs` oder `node scripts/check-frame.mjs`. Diese Skripte überschreiben gleichnamige Screenshots unter `test-results/`; vorhandene Aufnahmen sichern und erzeugte Bilder nur auf ausdrücklichen Wunsch übernehmen.

## Umsetzung in Phasen

1. **Kernspiel:** vollständige Schachregeln, Mana, Hand, Varianten, Zauber, KI, Geräte-Simulator und PWA.
2. **Fortschritt:** Truhen, Timer, Pity, Sammlung, Upgrades, Shop, Quests, Saison-Pass und Arenen.
3. **Multiplayer:** servergeprüfte Partien, Räume, Matchmaking, Zuschauer, Uhren, Reconnect, Rangliste und Replays.
4. **Polish:** Tutorial, Einstellungen, Zugänglichkeit, Akkuschonmodus und Abschlussprüfung.

Die Abschnitte beschreiben den geplanten Umfang. Der jeweilige Abschluss wird erst nach einer lauffähigen Prüfung dokumentiert.

## Verwendete Bibliotheken

- [chess.js](https://github.com/jhlywa/chess.js) für die Grundregeln (BSD-2-Clause).
- [ws](https://github.com/websockets/ws) für WebSocket (MIT).
- [html-to-image](https://github.com/bubkoo/html-to-image) für lokale Gerätescreenshots (MIT).
- [Node.js SQLite](https://nodejs.org/api/sqlite.html) für die persistente Speicherung.

Grafiken und Motive im Spiel sind eigens erstellte SVG- und CSS-Gestaltungen. Kein Tracking, keine Echtgeldkäufe, keine externen Konten.
