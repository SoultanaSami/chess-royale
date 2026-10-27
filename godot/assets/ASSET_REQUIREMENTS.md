# Asset Requirement Document

**Projekt:** Schachschlachtfeld – Godot 3D-Vertikal-Slice  
**Zielplattform:** Smartphones zuerst (Android/iOS), danach Desktop  
**Asset-Pipeline:** Nano Banana für Konzeptbilder und kontrollierte Bildvarianten; Meshy für daraus abgeleitete 3D-Modelle; Godot für Import, Materialeinstellungen, Zusammenbau und Abnahme.

Dieses Dokument ist der verbindliche Übergabevertrag zwischen Spiel, KI-Asset-Workflow und Godot-Integration. Ein Asset gilt erst als fertig, wenn Quelldateien, Exporte, Rechte-/Herkunftsnotiz und die unten genannten Prüfungen vorliegen.

## 1. Spiel- und Stilziel

Schachschlachtfeld ist ein dunkles mittelalterliches Taktikspiel auf 8×8. Die bestehende Testaufstellung umfasst pro Seite acht Bauern, zwei Türme, zwei Springer, zwei Läufer, eine Dame und ein König. Der Deckbau wählt **vor dem Match Varianten je Figurenplatz**. Er fügt keine Einheiten hinzu. Daher müssen Figurenvarianten bei gleicher Grundklasse aus der Vogelperspektive eindeutig lesbar und innerhalb einer Klasse ungefähr ähnlich groß sein.

Die Welt wirkt wie ein alter Kriegsraum in einer steinernen Burgbibliothek: verwitterter Schiefer, dunkles Eichenholz, geschwärztes Eisen, Messing, Wachs, Leder, Asche und sparsames bernsteinfarbenes Fackellicht. Formen sind handwerklich, schwer und glaubwürdig. Der Stil ist **stilisiertes, hochwertiges Low-Poly-Dark-Fantasy**, kein fotorealistischer Scan, kein Plastikspielzeug und keine überladene Miniatur.

Lesbarkeit geht vor Detailmenge. Silhouette, Klassenform und Teamfarbe müssen bei kleiner Smartphone-Darstellung erkennbar bleiben. Orange-Gold ist für Runen und Interaktion reserviert; blaue und rote Teamsignale bleiben in den Sockelmarkierungen. Modelle dürfen wichtige Information weder in winzige Schrift noch in ausschließlich emissive Details legen.

Die mögliche reduzierte Testarmee aus zehn Figuren hat noch keine festgelegte Startaufstellung. Deshalb werden die Assets weiterhin für die vorhandene vollständige Aufstellung und bis zu 32 gleichzeitig sichtbare Figuren budgetiert. Die klassische Schachlogik verwendet keine Kampfwerte; Figurenfähigkeiten und Zaubereinsatz sind noch offen.

## 2. Zielgeräte und Echtzeitbudget

Alle Abnahmen erfolgen mit der tatsächlich verwendeten Spielkamera und einer 390 × 844 großen Hochformatansicht sowie 844 × 390 im Querformat. Als zusätzliche Mindestgröße gilt 360 × 640. Modelle müssen auch auf einem mittelklassigen Smartphone bei mehreren gleichzeitig sichtbaren Figuren flüssig dargestellt werden.

| Bereich | Ziel | Harte Obergrenze / Regel |
| --- | --- | --- |
| sichtbare Spielfiguren | bis zu 32 Instanzen | Varianten teilen Materialien und möglichst Texturen |
| Dreiecke pro Spielfigur | 3.000–8.000 | 12.000 für außergewöhnlich große Heldenmodelle nur nach Profiling |
| Materials / Submeshes je Spielfigur | 1–2 | 3 nur, wenn technisch unvermeidbar; keine Material-Flut aus Meshy |
| Texturen pro Variante | geteilte Atlas-Texturen bevorzugt | keine individuellen 4K-Texturen; 1K nur für besonders wichtige Heldendetails |
| Texturformat im Quellpaket | PNG oder JPG für Rasterbilder; SVG für einfache Vektoren | keine unnötig eingebetteten Duplikate; Godot-Importkompression aktivieren |
| sichtbare Flächen | geschlossene, solide Geometrie | Alpha nur für zwingende Effekte; keine Alpha-Karten für Körper/Metall |
| Animationen | statische Pose für die erste Integration | Rig, Clips und zusätzliche Bones nur nach separater Freigabe |
| Echtzeit-Effekte | einfache Godot-Materialien/Lichter | keine ungebremsten Partikel, Echtzeit-Reflexionssonden oder Transparenzschichten |

Die Budgets sind Startwerte für den vertikalen Slice. Jede Abweichung muss auf einem realen Gerät gemessen werden; Desktop-Leistung allein ist kein Freigabekriterium.

## 3. Godot-Maßstab und Modellkonventionen

Die Brettfelder liegen in Godot ungefähr 1,15 Welt-Einheiten auseinander. Das bestehende Figurenfundament hat etwa 0,86 Einheiten Durchmesser und wird durch `UnitView` erzeugt. Gelieferte Spielfiguren enthalten **keinen zusätzlichen Sockel, keine Lebensleiste, keinen Namensschild und keine Team-Markierung**.

- **Maßeinheit:** 1 Blender/Meshy-Einheit entspricht 1 Meter in Godot; in Godot gilt +Y als oben.
- **Ursprung:** `(0, 0, 0)` in der Mitte der unteren Standfläche. Keine schwebenden Modelle und keine in den Boden versunkenen Füße/Räder.
- **Vorwärtsrichtung:** −Z. Die Front des Modells zeigt dorthin; die Spiellogik dreht die Gegenseite um 180°.
- **Spielfiguren-Grundfläche:** innerhalb eines Quadrats von ungefähr 0,78 × 0,78 Einheiten; breite Waffen dürfen die Silhouette betonen, aber keine Nachbarfelder dauerhaft verdecken.
- **Höhe:** gewöhnliche Infanterie 0,9–1,35; große Kommandanten und Reittiere bis etwa 1,7 Einheiten. Alle Varianten einer Klasse bleiben aus der Spielkamera ähnlich gewichtet.
- **Dateiformat:** bevorzugt GLB/glTF 2.0 (`.glb`) mit PBR-Materialien und eingebetteten benötigten Texturen. Quellprojekt und Einzeldaten daneben aufbewahren.
- **Szenenstruktur:** ein klar benannter Root-Node, positive Skalierung, keine unnötigen Kameras/Lichter/Kollisionskörper. Maßstab und Transformationen vor dem Export anwenden.
- **Material:** metallisch/rauheitsbasiert, keine komplexen Node-Graph-Abhängigkeiten. Rauheit muss unter warmem Fackellicht lesbar bleiben; Metall ist nicht überall spiegelglatt.
- **LOD/Kollision:** für die aktuelle Brettansicht keine separaten Kollisionen nötig. LOD nur ergänzen, wenn ein Profiling auf Zielgeräten es rechtfertigt.

Godot lädt Varianten als Prefabs aus `modelAssetPath`. Die vorhandenen Prefabs liegen in [`models/`](models/); die neue Integration ersetzt diese Pfade erst nach Sichtprüfung im Spiel. Eine GLB-Datei kann direkt importiert oder bei Bedarf in eine `.tscn`-Wrapper-Szene mit angepasster Skalierung und Materialien eingebettet werden.

## 4. Modellumfang für die aktuelle Armee

Pro Partie stehen zwar 32 Figuren auf dem Brett, gebraucht werden zum Start nur die eindeutigen Variantenmodelle dieser Tabelle. Wiederholte Bauern und Standardfiguren instanziieren dieselbe Ressource. Neue Varianten werden mit eindeutiger ID und klarer Abweichung als neue Modelle ergänzt.

| ID / Klasse | Erforderliche Hauptsilhouette | Lesbarkeit im Spiel | Besondere Vorgaben |
| --- | --- | --- | --- |
| `phalanx` – Bauer | gepanzerter Fußsoldat mit großem Turmschild | Schild, Helm und niedrige Infanteriesilhouette sofort erkennbar | Schild nicht vor dem ganzen Körper; keine dünne Einzelwaffe als einziges Klassenmerkmal |
| `cavalry` – Springer (Hellknight) | stehender, gepanzerter Speerträger mit dunkler Rüstung und rotem Umhang | aufrechte humanoide Silhouette mit klar lesbarer Waffe | Kein Reittier: bewusste Abweichung vom Pferd-Reiter-Klassencode; Waffe und Umhang dürfen Nachbarfelder nicht dauerhaft verdecken |
| `assassin` – Läufer | verhüllte Assassine mit zwei Giftklingen | schlanke, diagonale Kapuze-/Mantelsilhouette | Türkis/Grün nur als kleine Giftakzente; keine großen transparenten Rauchschwaden |
| `ram` – Turm | schwerer gepanzerter Rammbock auf stabilem Fahrgestell | breite, rechtwinklige Belagerungsform | massiver Stoßkopf, Eisenbänder, sichtbar gestützte Konstruktion; Räder nicht frei schwebend |
| `trebuchet` – Turm | kompaktes mobiles Belagerungstrebuchet | klar erkennbare Wurfarm-Silhouette unterscheidet es vom Rammbock | Wurfarm, Seil und Gegengewicht strukturell plausibel; dünne Seile nicht als tragende Hauptform |
| `golem` – Turm | steinerner Burgturm-Golem mit glühendem Kern | blockige, schwere Turmform statt humanoider Standardrüstung | große gebrochene Steinplatten und sichtbarer Kern; Glühen sparsam und ohne Bloom-Pflicht |
| `guard` – König | schwer gepanzerter Kriegsherr mit Krone/Helm und Wappenschild | größte klare humanoide Kommandanten-Silhouette | nicht so hoch oder breit, dass er ausgewählte Nachbarfelder verdeckt; keine lesbare Schrift am Modell |
| `queen` – Dame | dunkle Stahlkönigin mit Krone und arkanem Stab | elegant, hochrangig, dennoch von Guard und Assassine unterscheidbar | dunkles Stahlrot und Messingdetails; Stab kompakt und stabil; Lichtkugel klein |

**Hellknight-Integration:** Das gelieferte GLB rendert einen stehenden Speerträger, kein Schlachtross; die dunkle Rotpalette ist nur eine teilweise Stilpassung. Die runde Eigenplinthe wurde entfernt, da `UnitView` den Team-Sockel erzeugt. Der Wrapper skaliert gleichmäßig auf `0.60` und verschiebt lokal um `Y=+0.43533`, sodass die Stiefel bei `Y=0` aufsetzen. Ergebnis: etwa `0.89 × 0.67 m` Grundfläche, `1.01 m` hoch und `9,418` Dreiecke (unter 12,000); ein Ausnahmebudget ist damit nicht nötig. Die drei originalen 2048²-PBR-Maps bleiben erhalten. Vorhandene Materialtönung bleibt aktiv, doch Rot/Dunkel kann sie auf der Figur abschwächen; Sockelringe tragen weiter die klare Teamfarbe. Lizenzmetadaten waren im GLB nicht enthalten und sind vor Veröffentlichung zu klären.

**Wichtig:** Gift-, Glut- und Waffenmotive beschreiben ausschließlich das Aussehen. Varianten nutzen derzeit klassische Schachzüge; Spezialregeln bleiben offen. Die vorhandenen Modell-IDs und Klassenzuordnungen sind in [`variants.json`](../data/variants.json) und [`catalog.gd`](../data/catalog.gd) definiert. Modellnamen, Exportdateien und IDs müssen übereinstimmen. Für künftige Bauern-, Springer- oder Läufervarianten wird dieselbe Grundklasse beibehalten und nur die gewählte visuelle/Gameplay-Identität variiert.

## 5. Umgebung, Brett und Menü-Assets

Das Brett und die Bibliothek sind aus dem aktuellen Godot-Prototyp heraus bereits prozedural aufgebaut. Neue Umweltmodelle sollen gezielt Akzente ergänzen und nicht die Lesbarkeit der Figuren oder Touch-Ziele beeinträchtigen.

| Assetgruppe | Geplante Elemente | Priorität / Begrenzung |
| --- | --- | --- |
| Bibliothek | modulare dunkle Bücherregale, einzelne Buchstapel, Lesepult, Leiter, Steinbogen | Hoch; große Formen und ruhige Kontrastflächen im Menü-Hintergrund |
| Kerzen | 2–3 Kerzenvarianten, Wachsverläufe, einfache Flammenhalter | Hoch; Flamme bevorzugt als Godot-Effekt, nicht als schweres Mesh oder transparente Animation |
| Kriegsraum | Kartenrollen, Siegel, Federkiel, Kompass, Metallbeschläge | Mittel; nur dekorativ, keine aufgedruckte Kleinschrift erforderlich |
| Schachbrettdetails | Schieferplatten, Messinglinien, Randbeschläge, dezente Schrammen | Mittel; Boden und Details dürfen Zielfeld-Runen nicht überstrahlen |
| Kartenbilder | einheitliche Porträts/Icons für Figurenvarianten und Zauber | Hoch für Deckeditor; getrennte 2D-Exports statt gerenderte Schrift im Bild |
| Oberfläche | Holz-, Stein-, Eisen-, Leder- und Wachsmaterialien | Hoch; nahtlos, tiling-fähig und farblich auf die Szene abgestimmt |

Umweltmodelle sollen modular, wiederverwendbar und aus Spielerperspektive plausibel skalierbar sein. Wiederholte Regale oder Bodenteile müssen Material und Mesh teilen. Keine zufälligen lesbaren Runen, Wasserzeichen, Schriftzüge oder Marken in generierten Bildern.

## 6. Nano-Banana-Briefing: Konzeptbild und Referenzen

Nano Banana dient als **Konzept- und Bildvarianten-Werkzeug**, nicht als endgültige Quelle geometrischer Fakten. Jedes Konzeptbild muss einen klaren Asset-Namen, Zweck, Klassenform, Farbpalette und Blickwinkel enthalten.

Für Spielfiguren werden pro ID ein konsistentes Referenzblatt und ein separates sauberes Einzelbild erzeugt:

1. Neutraler Studiohintergrund in warmem Graubraun; eine Figur, mittig, vollständig sichtbar.
2. Vorder-, Seiten- und Rückansicht mit gleicher Form, Rüstung, Proportion und Beleuchtung. Falls das Tool kein belastbares Turnaround liefert: drei Ansichten separat anhand des freigegebenen Referenzbildes erzeugen und visuell abgleichen.
3. Drei Viertelansicht auf Augenhöhe als Hauptreferenz für Meshy; zusätzlich eine klare Seitenansicht für Asymmetrie und Tiefe.
4. Gleichmäßiges weiches Licht mit zurückhaltendem Rim-Light; kein dramatischer Schatten darf Körperteile verdecken.
5. Kein Text, keine Beschriftung, kein Rahmen, kein Interface, keine weiteren Figuren, keine Collage, keine schwebenden Teile und kein Sockel.
6. Einheitliche Weltmaterialien: geschwärztes Eisen, verwitterter Schiefer, dunkles Leder, mattes Messing, sparsame bernsteinfarbene Glut. Teamfarbe nur als kleines austauschbares Akzentmaterial, nicht als fest eingebrannte Textur.

**Prompt-Vorlage – Spielfigur**

> Erstelle ein sauberes Modellierungs-Referenzbild für eine einzelne kompakte Spielfigur für ein mobiles 3D-Taktikspiel. Asset: `[ID, Klasse, Variante]`. Hauptsilhouette: `[unverwechselbare Form]`. Pflichtdetails: `[3–5 große, aus der Spielkamera erkennbare Formen]`. Materialpalette: dunkles mittelalterliches Eisen, verwitterter Stein, matte Messingdetails, dunkles Leder, sehr sparsame bernsteinfarbene Glut. Stil: hochwertig stilisiertes Low-Poly-Dark-Fantasy, handwerklich, klare große Flächen, robuste Formen, keine winzigen dekorativen Teile. Zeige die vollständige Figur in einer neutralen Dreiviertelansicht auf einem schlichten graubraunen Studiohintergrund, gleichmäßig beleuchtet, ohne Sockel. Keine Schrift, kein Logo, kein UI, keine Collage, keine zusätzlichen Gegenstände, keine Transparenz. Proportionen müssen für eine Schachbrettzelle einer Smartphone-Taktikansicht lesbar sein.

**Prompt-Vorlage – Bibliotheksrequisite / Umgebung**

> Konzept für ein wiederverwendbares modular aufgebautes 3D-Umgebungsasset für eine mittelalterliche Burgbibliothek und einen Kriegsraum. Asset: `[Name]`; Funktion und Größenbezug: `[Beschreibung]`. Dunkle Eiche, alte Bücher, Stein und geschwärztes Eisen; dezente Gebrauchsspuren und warmer Kerzenschein. Stilisiert, glaubwürdig, große klare Volumen, mobile Echtzeitdarstellung, wenige überlappende Einzelteile. Zeige das Objekt vollständig, neutral freigestellt auf schlichtem dunklem Hintergrund. Keine lesbare Schrift, keine Figuren, kein Logo, kein UI, keine zusätzlichen Gegenstände oder Wasserzeichen.

Nach jeder Generierung werden Formfehler, unbeabsichtigte Schrift, abgeschnittene Elemente und Abweichungen vom gemeinsamen Stil geprüft. Nur freigegebene Bilder gehen als Referenz an Meshy.

## 7. Meshy-Briefing: Erzeugung und Nachbearbeitung

Meshy erhält pro Modell genau einen Asset-Auftrag mit der freigegebenen Nano-Banana-Referenz und dem passenden Klassenbrief. Wenn Meshy mehrere Ansichten unterstützt, dürfen sie nur zusammen hochgeladen werden, wenn alle dieselbe finale Variante zeigen. Unterschiedliche Versionen oder Farbideen nicht in einen Einzelauftrag mischen.

**Prompt-Vorlage – 3D-Modell**

> Erzeuge ein einzelnes solides, geschlossenes, für mobile Echtzeitspiele optimiertes 3D-Asset: `[ID, Variantenname]`. Es muss die Referenzsilhouette bewahren: `[Klasse und Hauptform]`. Maßstab 1 Meter = 1 Einheit; Gesamthöhe ungefähr `[0.9–1.7]` m und Grundfläche höchstens `0.78 × 0.78` m. Ursprung mittig auf der Standfläche, +Y nach oben, Front nach −Z. Stilisiertes handwerkliches Low-Poly-Dark-Fantasy mit klaren großen Flächen. Dunkles Eisen, Stein, Leder und mattes Messing; sparsame amberfarbene Akzente. Robuste Geometrie, geschlossene Volumen, saubere Normalen, keine unnötigen Innenteile. Maximal 8.000 Dreiecke, maximal zwei Material-Slots, Texturen bis 1024 px. Keine Basis/Sockel, kein Boden, kein Namensschild, keine Lebensleiste, keine Kamera, keine Lichter, keine Schrift, keine Transparenz, keine zusätzlichen Figuren. Ausgabe als einzelnes statisches Spielmodell.

Vor der Integration werden automatisierte Geometrie-Reparatur und/oder Blender-Nachbearbeitung genutzt, falls erforderlich: Maßstab und Ursprung richten, Rotation anwenden, Normalen korrigieren, verdeckte/duplizierte Geometrie entfernen, Materialanzahl reduzieren, Texturen bündeln und Mesh-Namen bereinigen. KI-Export direkt in das Spiel zu übernehmen ist nur nach Prüfung zulässig.

### Exportpaket je Asset

```text
<asset_id>/
  concept/
    <asset_id>_reference.png
    <asset_id>_turnaround.png
  source/
    <asset_id>_meshy_project_or_source.zip
  export/
    <asset_id>.glb
    <asset_id>_preview.png
    textures/                 # nur falls nicht eingebettet
  metadata.json
```

`metadata.json` enthält mindestens `id`, `displayName`, `baseChessType`, Quellwerkzeug und Erstellungsdatum, Exportdatei, Abmessungen, Dreieckzahl, Materialzahl, Texturgrößen, Lizenz-/Nutzungsstatus, nötige Godot-Importeinstellungen sowie bekannte Abweichungen. Geheimnisse, API-Schlüssel, private Kontoinformationen und personenbezogene Prompts gehören nie in das Paket oder Repository.

## 8. Godot-Integration und Abnahme

Für eine neue Figur wird `modelAssetPath` in [`variants.json`](../data/variants.json) auf die integrierte Godot-Szene gesetzt. Das Modell selbst bleibt ein Kind des automatisch gebauten `UnitView`-Sockels. Teamfarbe, Namensschild, Auswahlring, Bewegung und Schachmarkierung kommen aus dem Spielcode. Es gibt keine HP-, Schadens-, Rüstungs- oder Levelanzeigen.

Jedes Asset muss folgende Kriterien erfüllen:

- Importiert in der festgelegten Godot-Version ohne fehlende Texturen, Fehler, ungültige Meshes oder Warnungen zu fehlenden Ressourcen.
- Liegt mit dem Boden exakt auf `Y=0`; steht ohne Skalierungs-Workaround korrekt auf dem Sockel und zeigt nach −Z.
- Belegt die eigene Brettzelle; Gesicht/Front ist in beiden Teamrichtungen verständlich. Keine Nachbarfigur wird durch breite Teile verdeckt.
- Ist bei 360 × 640, 390 × 844 und 844 × 390 unter der echten Spielkamera als richtige Schachklasse identifizierbar.
- Lesbarkeit wird ohne Glow, ohne UI-Namensschild und im neutralen Graustufenbild geprüft. Danach folgt die Prüfung in warmem Fackellicht.
- Materialien überstrahlen nicht, flimmern nicht und verlieren bei gedämpfter Beleuchtung weder Umriss noch wichtige Details.
- Dreiecke, Texturgröße, Materialanzahl und Speicherbedarf liegen innerhalb der Budgets; ein Ausreißer ist dokumentiert und profiliert.
- Neue Dateien sind eindeutig benannt, komprimiert, lizenziert und ohne temporäre Meshy-/Blender-Dateien eingebunden.
- Das aktuelle Regel- und Smartphone-UI bleiben unverändert funktionsfähig.

**Abnahmeansichten:** Standbild in Front, Seite, Dreiviertelansicht und direkt im Spiel; dazu Nahsicht auf Material und Draufsicht im tatsächlichen Zellenmaß. Die Spielansicht ist entscheidend. Ein schickes isoliertes Render ohne Lesbarkeit auf dem Brett ist kein bestandenes Asset.

## 9. Ablage, Versionierung und Iterationen

Empfohlene Ordnerstruktur für künftig gelieferte Assets:

```text
godot/assets/
  concepts/<asset_id>/
  source/<asset_id>/
  models/<asset_id>.glb
  models/<asset_id>.tscn        # optionaler Godot-Wrapper
  previews/<asset_id>_game.png
```

Nur freigegebene Konzepte, Quellpakete, Exporte und nötige Metadaten gehören ins Projekt. Große temporäre Render, Zwischenstufen, Cache, Downloadarchive, Zugangsdaten und nicht verwendete Varianten bleiben außerhalb des Repositories. Jeder Modellwechsel wird unter derselben stabilen ID geprüft und erst dann als neue Fassung übernommen. Bereits spielbare Modelle bleiben verfügbar, bis die neue Fassung im Szenen- und Touch-Check besteht.

## 10. Priorisierte Produktionsreihenfolge

1. Ein Testmodell aus der vorhandenen `phalanx`-Variante erstellen und die gesamte Nano-Banana → Meshy → Godot-Kette auf dem Smartphone-Viewport abnehmen.
2. Die übrigen sieben aktuellen Figurenmodelle nach Klassen-Silhouette produzieren und mit einem gemeinsamen Materialsystem integrieren.
3. Kartenporträts aus freigegebenen Modellen/Referenzen ableiten; Kartenname, Figurenklasse und Regelbeschreibung stets als echte UI-Elemente rendern; keine Kampfwerte.
4. Kerzen, Bücherregale und wenige Kriegsraum-Requisiten als wiederverwendbare Menü-Assets ergänzen.
5. Zusätzliche Varianten erst nach vollständigem Durchlauf von Maßstab, Lesbarkeit, Speicher- und Performanceprüfung freigeben.

