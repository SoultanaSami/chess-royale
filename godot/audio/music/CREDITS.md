# Glut der alten Krone

Originales instrumentales Menüthema für **Schachschlachtfeld**. Eine eigens
geschriebene, samplebasierte Komposition mit Solo-Violine, Violinengruppe,
Bratschen, Celli, Kontrabass und Harfe. Leise modellierte Rahmentrommeln und
einzelne Glockenakzente begleiten den Aufbau. Keine Gesangsspur.

## Musikalische Form

72 Takte in 6/8, d-Moll mit einer helleren Passage in F-Dur. Das Tempo atmet
zwischen 44 und 57 punktierten Vierteln pro Minute. Die Melodie beginnt schon
in der Einleitung und kehrt nach dem Höhepunkt wieder.

| Takte | Abschnitt |
| --- | --- |
| 1–4 | Harfe, dunkle Saiten und ein erster Ruf der Violine |
| 5–20 | Hauptthema mit langen, singenden Phrasen |
| 21–28 | Intimer Rückzug und Vorbereitung |
| 29–44 | Weite, hellere Orchesterpassage und melodischer Höhepunkt |
| 45–48 | Kurze Atempause |
| 49–64 | Wiederkehr des Themas mit vollerem Streicherbett |
| 65–72 | Langsamer Ausklang mit natürlichem Hallende |

[OGG-Master](ashen_crown.ogg) · [Editierbare MIDI-Noten](ashen_crown.mid) ·
[Renderdaten und Sample-Prüfsummen](ashen_crown.json)

Die MIDI-Datei bewahrt Noten, Artikulationslängen und Tempowechsel; ihr Klang
hängt vom verwendeten MIDI-Instrument ab. Der OGG-Master ist die fertige
Mischung, die das Spiel verwendet.

## Instrumentaufnahmen

Die aufgenommenen Streich- und Harfeninstrumente stammen aus
[VSCO 2 Community Edition, Versilian Studios](https://github.com/sgossner/VSCO-2-CE),
Revision `440300901dfe9275fd84e0b7763af1f8443ae62e`.
Aufnahmen: Sam Gossner und Simon Dalzell; Sample-Bearbeitung:
Elan Hickler / Soundemote. Lizenz: [CC0 1.0 Universal](VSCO-CC0.txt).
Die Komposition übernimmt keine bestehende Melodie aus dieser Bibliothek.

Der Renderer lädt nur die benötigten Einzelton-Aufnahmen in einen lokalen
Cache; die Rohbibliothek wird nicht mit dem Spiel ausgeliefert. Trommeln,
Glocken und der Stereo-Hall werden durch den Renderer erzeugt.

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

Die bisherige Partiemusik bleibt unverändert. Ihr separater Renderer ist
[render_medieval_music.swift](../../tools/render_medieval_music.swift).
