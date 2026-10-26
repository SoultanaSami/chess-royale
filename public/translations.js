import { PIECES, SPELLS, TUTORIAL } from "/shared/catalog.js";
const phrases = {
  Start: "Home",
  Deck: "Deck",
  Shop: "Treasury",
  Truhen: "Chests",
  Arenen: "Arenas",
  Rangliste: "Leaderboard",
  Gold: "Gold",
  Mondsteine: "Moonstones",
  Trophäen: "Trophies",
  Spielanleitung: "How to play",
  Einstellungen: "Settings",
  "Dein Königreich": "Your kingdom",
  "Ein neues Kapitel beginnt": "A new chapter begins",
  "DEIN WEG ZUR KRONE": "YOUR ROAD TO THE CROWN",
  "ARENA 01 · HOLZHALLE": "ARENA 01 · TIMBER HALL",
  "Jeder Zug.": "Every move.",
  "Ein neues Königreich.": "A new kingdom.",
  "Schach mit einem Funken Magie.": "Chess with a spark of magic.",
  "Bereit für deinen Zug?": "Ready for your next move?",
  Training: "Training",
  Klassisch: "Classic",
  Fantasy: "Fantasy",
  Leicht: "Easy",
  Mittel: "Medium",
  Schwer: "Hard",
  "Dein Deck, Mana & Magie auf dem Schachbrett.":
    "Your deck, mana and magic on the chessboard.",
  "Das zeitlose Spiel. Nur du und dein nächster Zug.":
    "The timeless game. Just you and your next move.",
  "Zur Schlacht": "To battle",
  "GEGEN KI · OHNE ZEITDRUCK · DEIN TEMPO": "VERSUS AI · NO CLOCK · YOUR PACE",
  "⚔ Duellhalle · Gemeinsam spielen": "⚔ Duel hall · Play together",
  "Ein guter Plan beginnt mit einem kleinen Zug.":
    "A good plan begins with a small move.",
  "Laufende Partie fortsetzen": "Resume your game",
  "Deine Figuren": "Your pieces",
  "Dein Deck": "Your deck",
  "Im Training frei": "Free in training",
  "Deine Zauber": "Your spells",
  "3 Plätze": "3 slots",
  König: "King",
  Dame: "Queen",
  Turm: "Rook",
  Läufer: "Bishop",
  Springer: "Knight",
  Bauer: "Pawn",
  "Schach & Magie": "Chess & magic",
  "Das königliche Spiel": "The royal game",
  "Der Hofstratege": "The court strategist",
  "Ein würdiger Gegner": "A worthy opponent",
  "Du bist am Zug. Wähle eine Figur.": "Your turn. Choose a piece.",
  "Tippe auf ein markiertes Zielfeld.": "Tap a highlighted destination.",
  "Dein Gegenüber denkt nach …": "Your opponent is thinking …",
  "Die Partie ist beendet.": "The game is over.",
  "Schach! Bring deinen König in Sicherheit.": "Check! Keep your king safe.",
  "Wähle das Ziel für deinen Zauber.": "Choose a target for your spell.",
  "Wähle ein Ziel für die Fähigkeit.": "Choose a target for the ability.",
  "Wähle ein markiertes Feld zum Beschwören.":
    "Choose a highlighted square to summon.",
  "Deine Verstärkung": "Your reinforcements",
  "So funktioniert’s": "How it works",
  "Fähigkeit nutzen": "Use ability",
  "Normal ziehen": "Normal move",
  "Kein Nachschub": "No reinforcements",
  Zugverlauf: "Move history",
  Aufgeben: "Resign",
  Weiterspielen: "Keep playing",
  "Die Fahne senken?": "Lower your banner?",
  "Eine kleine Pause": "A short break",
  "Zur Startseite": "Return home",
  Schließen: "Close",
  "Noch eine Partie": "Play again",
  "Zurück ins Königreich": "Return to your kingdom",
  "Dein Königreich triumphiert": "Your kingdom triumphs",
  "Jeder Zug lehrt etwas": "Every move teaches something",
  "Ein würdiges Remis": "A worthy draw",
  "TRAINING ABGESCHLOSSEN": "GAME COMPLETE",
  Halbzüge: "Half-moves",
  Gegner: "Opponent",
  "SCHÄTZE DEINES KÖNIGREICHS": "TREASURES OF YOUR KINGDOM",
  "Die Truhenkammer": "The chest chamber",
  "Jedes Schloss verbirgt eine neue Geschichte.":
    "Every lock hides a new story.",
  "Freier Platz": "Empty slot",
  "Gewinne eine Partie oder besuche die Schatzkammer.":
    "Win a game or visit the treasury.",
  Aufschließen: "Unlock",
  Beschleunigen: "Speed up",
  "Siegel brechen": "Break the seal",
  "Bereit zum Öffnen": "Ready to open",
  "Deine Sammlung": "Your collection",
  "Noch unentdeckt": "Undiscovered",
  MAXIMAL: "MAXIMUM",
  "Dein Fund": "Your discovery",
  "Antippen oder halten zum Öffnen": "Tap or hold to open",
  "Das Siegel ist bereit.": "The seal is ready.",
  "NEUE KARTE ENTDECKT": "NEW CARD DISCOVERED",
  "Nächste Karte": "Next card",
  "In die Sammlung": "To your collection",
  Gewöhnlich: "Common",
  Selten: "Rare",
  Episch: "Epic",
  Legendär: "Legendary",
  "HANDEL UNTER ALTEN BALKEN": "TRADE BENEATH ANCIENT BEAMS",
  "Die Schatzkammer": "The treasury",
  "Alles wird erspielt. Kein echtes Geld.":
    "Everything is earned through play. No real money.",
  "Dein täglicher Segen": "Your daily blessing",
  "Gold, 5 Mondsteine und Saisonfortschritt.":
    "Gold, 5 moonstones and season progress.",
  Abholen: "Claim",
  Abgeholt: "Claimed",
  "Heutige Angebote": "Today’s offers",
  Erworben: "Purchased",
  "Tägliche Aufgaben": "Daily quests",
  "Der erste Plan": "The first plan",
  "Ruf der Verstärkung": "Call for reinforcements",
  "Für die Holzhalle": "For the timber hall",
  "Pfad der Krone": "Path of the crown",
  "Königspfad · 200 Mondsteine": "Royal path · 200 moonstones",
  "✦ Königspfad aktiviert": "✦ Royal path activated",
  "ACHT ORTE. ACHT LEGENDEN.": "EIGHT PLACES. EIGHT LEGENDS.",
  "Die Königreiche": "The kingdoms",
  "Deine Trophäen öffnen neue Wege. Jedes Brett birgt eigene Geheimnisse.":
    "Your trophies open new paths. Every board holds its own secrets.",
  "Deine Arena": "Your arena",
  "Noch verschlossen": "Still locked",
  "Arena betreten": "Enter arena",
  "NAMEN, DIE BLEIBEN": "NAMES THAT ENDURE",
  "Die Chronik der Krone": "The royal chronicle",
  "Trophäen entscheiden den Rang. Elo misst deine Spielstärke.":
    "Trophies determine your rank. Elo measures your strength.",
  "Deine Replays": "Your replays",
  "Deine ersten Partien erscheinen hier.": "Your first games will appear here.",
  "DIE TORE STEHEN OFFEN": "THE GATES ARE OPEN",
  "Die Duellhalle": "The duel hall",
  "Mit der Arena verbunden": "Connected to the arena",
  "Verbindung wird wiederhergestellt …": "Reconnecting …",
  Ranglistenduell: "Ranked duel",
  "Gegner mit ähnlichen Trophäen · 5 + 3": "Similar trophies · 5 + 3",
  Runenchaos: "Rune chaos",
  "Zufälliges gemeinsames Deck · Stufe 1": "Shared random deck · level 1",
  "Ein würdiger Gegner wird gesucht …": "Searching for a worthy opponent …",
  "Suche beenden": "Cancel search",
  "Unter Freunden": "Among friends",
  "Duellraum eröffnen": "Create duel room",
  "DEIN RAUMCODE": "YOUR ROOM CODE",
  "Öffne das zweite Handy und tritt mit diesem Code bei.":
    "Open the second phone and join using this code.",
  "Einladung teilen": "Share invitation",
  "Raum- oder Turniercode": "Room or tournament code",
  Beitreten: "Join",
  Zuschauen: "Spectate",
  "Das Viererturnier": "The four-player tournament",
  "Turnier gründen": "Create tournament",
  "Mit Code beitreten": "Join using code",
  "Das Turnier läuft": "Tournament in progress",
  "Zurück in die Burghalle": "Return to the castle hall",
  "Für den König!": "For the king!",
  "Gut gespielt": "Well played",
  "Verflucht!": "Curses!",
  "Weiß / Schwarz": "White / Black",
  Chronik: "Chronicle",
  Spielklänge: "Game sounds",
  "Holz, Stahl und leise Runenklänge.": "Wood, steel and quiet rune chimes.",
  "Musik & Atmosphäre": "Music & ambience",
  "Laute, Flöte, Feuer und Wind deiner Arena.":
    "Lute, flute, fire and the winds of your arena.",
  Vibration: "Vibration",
  "Haptisches Feedback bei Zügen und Truhen.":
    "Haptic feedback for moves and chests.",
  Akkuschonmodus: "Battery saver",
  "Weniger Effekte, keine Hintergrundmusik.":
    "Fewer effects and no background music.",
  "Farbenblind-Modus": "Colourblind mode",
  "Blau und Pergament mit deutlichen Zielmarkierungen.":
    "Blue and parchment with clear target markers.",
  "Große Schrift": "Large text",
  "Lesbarere Texte und Bedienelemente.": "More readable text and controls.",
  Grafikqualität: "Graphics quality",
  Hoch: "High",
  Reduziert: "Reduced",
  Sprache: "Language",
  "Dein Name": "Your name",
  "Namen speichern": "Save name",
  Entwicklerwerkzeuge: "Developer tools",
  "Dein Gastprofil bleibt auf diesem Gerät gespeichert. Alle Inhalte sind mit Spielgeld erhältlich.":
    "Your guest profile stays on this device. All content uses in-game currency.",
  "Drei geführte Trainingspartien. Dein erster Schritt zur Krone.":
    "Three guided games. Your first steps towards the crown.",
  "Lektion beginnen →": "Begin lesson →",
  "Die ersten Schritte": "The first steps",
  "Das Geschenk der Runen": "The gift of runes",
  "Die Macht der Krone": "The power of the crown",
  "Gut gemacht. Spiele die Partie weiter oder schließe diese Lektion ab.":
    "Well done. Keep playing or complete this lesson.",
  "Lektion abschließen": "Complete lesson",
  "✦ Eldrins Lehrpfad abgeschlossen": "✦ Eldrin’s lessons completed",
  "Die Lektion ist geschafft": "Lesson complete",
  "Du bist offline. Deine Partie bleibt erhalten.":
    "You are offline. Your game is saved.",
  "Langsame Verbindung · Deine Züge brauchen etwas länger.":
    "Slow connection · Your moves take a little longer.",
  "Erneut versuchen": "Try again",
};
const descriptions = {
  "time-king":
    "Once per game, rewind the last two half-moves. Spent clock time is not restored.",
  "flee-king": "Escape to a safe empty square within two squares.",
  "shadow-king": "Hide in mist for two rounds to avoid targeted abilities.",
  "war-king": "Once per game, make a safe queen-like move.",
  "gold-king": "Gain one extra mana crystal when this king captures.",
  "marsh-witch": "Turn an enemy pawn into an immobile frog for three rounds.",
  "blood-countess": "Gain one extra mana crystal when capturing.",
  "mirror-mage":
    "Create a temporary illusion on an adjacent empty square for two rounds.",
  "storm-queen":
    "Capture and then take one extra orthogonal step as an ability.",
  bastion: "Entrench for two rounds: immobile but protected from captures.",
  ram: "Break through an enemy and capture the piece directly behind it.",
  catapult: "Shoot along a clear rook line up to three squares without moving.",
  seer: "Swap places with an allied piece while keeping your king safe.",
  priest:
    "Revive your most recently captured ally as a pawn on your starting pawn rank.",
  "fire-mage": "Send a fireball at an enemy up to three squares away.",
  necromancer: "Consume a captured enemy to summon a ghost pawn.",
  ranger: "Follow a clear diagonal, then turn once with an orthogonal step.",
  rider: "After jumping, also capture orthogonally adjacent enemies.",
  "shadow-horse": "Ignore blockades and disabling abilities when jumping.",
  "dragon-rider":
    "After landing, strike enemy pieces in the surrounding 3×3 area.",
  unicorn:
    "After jumping to a free square, take one additional orthogonal step.",
  shieldbearer: "Block one attack. This pawn cannot capture.",
  assassin: "Move diagonally forwards even when the square is empty.",
  phoenix: "Return once to your empty original square after being captured.",
  powder:
    "Explode when capturing or captured, destroying adjacent pieces but never kings.",
  miner: "Generate extra mana every second turn.",
  spy: "Reveal the opponent’s hand and chosen king spells.",
  flee: "Move your king to a safe empty square within two squares.",
  shield: "Protect an allied piece through the opponent’s next turn.",
  command: "After casting, take two consecutive actions.",
  "time-stop": "Stop time and take two consecutive actions.",
  meteor: "Destroy one chosen enemy in a 2×2 area. Kings are protected.",
  banish: "Remove an enemy for three rounds before it returns.",
  throne: "Swap your king with an allied piece, keeping the king safe.",
  prison: "Imprison a visible enemy for two rounds.",
};
for (const c of [...PIECES, ...SPELLS])
  if (descriptions[c.id]) phrases[c.description] = descriptions[c.id];
const tutorialEnglish = [
  "I am Eldrin, keeper of the timber hall. Tap a light piece: glowing squares show its legal moves. Keep your king safe.",
  "Mana grows after your own actions. Select a card from your hand and summon it on a free square in your starting ranks.",
  "Your three king spells can turn the tide. Select a spell, then a glowing target. Even magic must keep your king safe.",
];
TUTORIAL.forEach((t, i) => (phrases[t.text] = tutorialEnglish[i]));
function translate(text) {
  const trimmed = text.trim();
  if (phrases[trimmed]) return text.replace(trimmed, phrases[trimmed]);
  return text
    .replace(/Stufe (\d+)/g, "Level $1")
    .replace(/(\d+) Fragmente/g, "$1 fragments")
    .replace(/(\d+) Minuten/g, "$1 minutes")
    .replace(/(\d+) Züge Pause/g, "$1 turns cooldown")
    .replace(/(\d+) TROPHÄEN/g, "$1 TROPHIES")
    .replace(/ELDRINS LEHRPFAD/g, "ELDRIN’S LESSONS")
    .replace(/Sofort ·/g, "Instant ·")
    .replace(/Garantiert episch:/g, "Epic guaranteed:")
    .replace(/Legendär:/g, "Legendary:")
    .replace(/Gold aus der Truhe/g, "gold from the chest")
    .replace(
      /Sofort öffnen kostet (\d+) Mondsteine\./g,
      "Open instantly for $1 moonstones.",
    )
    .replace(/Gratis ·/g, "Free ·")
    .replace(/Krone ·/g, "Royal ·")
    .replace(/Weiß · Dein Königreich/g, "White · Your kingdom")
    .replace(/Schwarz · Dein Königreich/g, "Black · Your kingdom")
    .replace(/König · Varianten/g, "King · Variants")
    .replace(/Dame · Varianten/g, "Queen · Variants")
    .replace(/Turm · Varianten/g, "Rook · Variants")
    .replace(/Läufer · Varianten/g, "Bishop · Variants")
    .replace(/Springer · Varianten/g, "Knight · Variants")
    .replace(/Bauer · Varianten/g, "Pawn · Variants");
}
export function translateDOM(root, language) {
  if (!root || language !== "en") return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let node;
  while ((node = walker.nextNode())) {
    if (node.parentElement?.closest("script,style")) continue;
    node.nodeValue = translate(node.nodeValue);
  }
  root
    .querySelectorAll("[aria-label],[title],[placeholder]")
    .forEach((element) => {
      for (const key of ["aria-label", "title", "placeholder"])
        if (element.hasAttribute(key))
          element.setAttribute(key, translate(element.getAttribute(key)));
    });
}
