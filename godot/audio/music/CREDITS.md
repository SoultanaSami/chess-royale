# Glut der alten Krone

Originales orchestrales Menüthema für **Schachschlachtfeld**, Arrangement 3.
Eine eigens geschriebene, samplebasierte Komposition mit Solo-Violine,
Violinengruppe, Bratschen, Celli, Kontrabass, Harfe und Hörnern. Ein aus
aufgenommenen Einzelvokalen geschichteter, wortloser Männerchor begleitet
ausgewählte Passagen. Es gibt keinen Liedtext.

Diese Überarbeitung stellt aufgenommene große Orchestertrommeln,
Tenortrommeln und militärische Snare-Akzente in den Vordergrund. Der
6/8-Marschpuls beginnt schon im ersten Takt; Wirbel leiten die großen
Orchestereinsätze ein. Kürzere Cellobögen, kräftigere Hornantworten und
ein höheres Tempo geben der Melodie mehr Drang. Die Harfe beschränkt sich
weitgehend auf einzelne Akzente. Der wortlose Chor bleibt im Aufbau und
Höhepunkt erhalten.

## Musikalische Form

72 Takte in 6/8, Dauer etwa 2:34, d-Moll mit einer helleren Passage in F-Dur.
Das Tempo atmet zwischen 46 und 63 punktierten Vierteln pro Minute. Die Melodie beginnt schon
in der Einleitung und kehrt nach dem Höhepunkt wieder.

| Takte | Abschnitt |
| --- | --- |
| 1–4 | Tiefe Orchestertrommeln, Cellopuls, Hornrufe und erste Violine |
| 5–20 | Hauptthema über Marschrhythmus, kurzen Cellobögen und Hornantworten |
| 21–28 | Rückzug, erneuter Aufbau und anschwellender Männerchor |
| 29–44 | Großer Moll-Höhepunkt mit Chor, Hörnern und voller Streichergruppe |
| 45–48 | Kurze Atempause |
| 49–64 | Wiederkehr des Themas mit vollerem Streicherbett |
| 65–72 | Langsamer Ausklang mit natürlichem Hallende |

[OGG-Master](ashen_crown.ogg) · [Editierbare MIDI-Noten](ashen_crown.mid) ·
[Renderdaten und Sample-Prüfsummen](ashen_crown.json)

Die MIDI-Datei bewahrt Noten, Artikulationslängen und Tempowechsel; ihr Klang
hängt vom verwendeten MIDI-Instrument ab. Der OGG-Master ist die fertige
Mischung, die das Spiel verwendet.

## Instrumentaufnahmen

Die aufgenommenen Streich-, Harfen-, Horn-, Becken- und Trommelinstrumente stammen aus
[VSCO 2 Community Edition, Versilian Studios](https://github.com/sgossner/VSCO-2-CE),
Revision `440300901dfe9275fd84e0b7763af1f8443ae62e`.
Aufnahmen: Sam Gossner und Simon Dalzell; Sample-Bearbeitung:
Elan Hickler / Soundemote. Lizenz: [CC0 1.0 Universal](VSCO-CC0.txt).
Die Komposition übernimmt keine bestehende Melodie aus dieser Bibliothek.

Die wortlosen Vokalaufnahmen stammen aus dem
[Legato Vocal Tutorial von Karoryfer Samples](https://github.com/sfzinstruments/legato_vocal_tutorial),
Revision `fac6461ee4c7f498b23246eced644616fa58d2ec`.
Die Quelle bezeichnet sie als den „a“-Vokal aus Hadzi-Fia.
Lizenz: [CC0 1.0 Universal](VOCAL-CC0.txt).
Mehrere zeitlich und tonal leicht versetzte Stimmen bilden den Chor;
es handelt sich nicht um eine Aufnahme eines vollständigen Live-Chores.

Der Renderer lädt nur die benötigten Einzelton-Aufnahmen in einen lokalen
Cache; die Rohbibliotheken werden nicht mit dem Spiel ausgeliefert. Eine
zusätzliche tiefe Trommelresonanz, Glocken und der Stereo-Hall werden durch
den Renderer erzeugt. Die dominanten Trommelschichten sind echte Aufnahmen
mit wechselnden Anschlägen, keine Synthesizer-Presets.

## Erneut rendern

Vom Projektwurzelverzeichnis aus in einer Python-Umgebung:

```sh
python3 -m pip install -r godot/tools/music-requirements.txt
python3 godot/tools/compose_crown_theme.py
```

Optional erzeugt `--wav /pfad/zum/master.wav` zusätzlich einen 24-Bit-WAV-Master.
Der erste Lauf benötigt Internetzugriff auf die öffentliche Samplebibliothek.
Die Python-Pakete sind ausschließlich für die Audioproduktion erforderlich;
Godot lädt die fertige OGG-Datei ohne zusätzliche Laufzeitabhängigkeiten.

## Partiemusik: Trommeln vor der Schlacht

Während einer Partie läuft [battle_drums.ogg](battle_drums.ogg): ausschließlich
langsame Bass- und Tenortrommeln, ohne Violine, andere Streicher oder Gesang.
16 Takte in 4/4 bei 84 BPM ergeben eine etwa 46 Sekunden lange Schleife.
Ein fester Marschpuls aus tiefen Paukenschlägen und resonanten Antworttrommeln
trägt den Rhythmus; kurze, sparsame Wirbel bauen an jedem vierten Takt Spannung
auf. Wechselnde Aufnahmen und kleine Anschlagsvariationen vermeiden einen mechanischen Puls. Der Hall
des letzten Takts wird an den Schleifenanfang übertragen, damit kein stiller
Neustart entsteht. Die oben genannten CC0-Aufnahmen aus VSCO 2 CE liefern
beide Instrumente. Quellen, Anschläge und Pegel stehen in [battle_drums.json](battle_drums.json).

Erneut rendern mit denselben Python-Abhängigkeiten:

```sh
python3 godot/tools/compose_battle_drums.py
```

Die frühere orchestrale Partiemusik und ihr
[Swift-Renderer](../../tools/render_medieval_music.swift) bleiben als Quelldateien
erhalten; im Spiel wird die neue Trommelschleife verwendet.
