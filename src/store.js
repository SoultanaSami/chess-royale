import { DatabaseSync } from "node:sqlite";
import { randomBytes, randomUUID, createHash } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import {
  BALANCE,
  DEFAULT_DECK,
  DEFAULT_SPELLS,
  ALL_CARDS,
} from "../shared/catalog.js";

const filename = process.env.DB_PATH || resolve("data/chess-royale.sqlite");
if (filename !== ":memory:") mkdirSync(dirname(filename), { recursive: true });
export const db = new DatabaseSync(filename);
db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
 CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL, data TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS matches (id TEXT PRIMARY KEY, data TEXT NOT NULL, updated_at INTEGER NOT NULL);
 CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY AUTOINCREMENT, match_id TEXT, data TEXT NOT NULL);
 CREATE INDEX IF NOT EXISTS events_match ON events(match_id);
`);
const hash = (token) => createHash("sha256").update(token).digest("hex");
export function accountForToken(token) {
  if (typeof token !== "string" || !/^[a-f0-9]{64}$/.test(token)) return null;
  const row = db
    .prepare("SELECT data FROM accounts WHERE token_hash=?")
    .get(hash(token));
  return row ? JSON.parse(row.data) : null;
}
export function accountById(id) {
  const row = db.prepare("SELECT data FROM accounts WHERE id=?").get(id);
  return row ? JSON.parse(row.data) : null;
}
export function createAccount() {
  const token = randomBytes(32).toString("hex");
  const id = randomUUID();
  const owned = [...Object.values(DEFAULT_DECK), ...DEFAULT_SPELLS];
  const profile = {
    id,
    name: `Wanderer ${id.slice(0, 4).toUpperCase()}`,
    level: 1,
    gold: BALANCE.startGold,
    gems: BALANCE.startGems,
    trophies: 0,
    elo: 1000,
    arena: "hall",
    deck: { ...DEFAULT_DECK },
    spells: [...DEFAULT_SPELLS],
    collection: Object.fromEntries(
      owned.map((card) => [card, { level: 1, fragments: 0 }]),
    ),
    unlocked: owned,
    chests: [
      { id: randomUUID(), type: "wood", status: "locked", readyAt: null },
      null,
      null,
      null,
    ],
    pity: {},
    stats: { matches: 0, wins: 0, moves: 0, summons: 0, spells: 0, chests: 0 },
    quests: { day: "", claimed: [] },
    loginDay: "",
    season: { id: "", xp: 0, premium: false, claimed: [] },
    tutorial: 0,
    settings: {
      sound: true,
      music: false,
      vibration: true,
      quality: "high",
      language: "de",
      battery: false,
      colorblind: false,
      largeText: false,
    },
    createdAt: Date.now(),
  };
  db.prepare("INSERT INTO accounts(id,token_hash,data) VALUES(?,?,?)").run(
    id,
    hash(token),
    JSON.stringify(profile),
  );
  return { token, profile };
}
export function saveProfile(profile) {
  db.prepare("UPDATE accounts SET data=? WHERE id=?").run(
    JSON.stringify(profile),
    profile.id,
  );
  return profile;
}
export function saveMatch(match) {
  db.prepare(
    "INSERT INTO matches(id,data,updated_at) VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data,updated_at=excluded.updated_at",
  ).run(match.id, JSON.stringify(match), Date.now());
  return match;
}
export function getMatch(id) {
  const row = db.prepare("SELECT data FROM matches WHERE id=?").get(id);
  return row ? JSON.parse(row.data) : null;
}
export function listMatches() {
  return db
    .prepare("SELECT data FROM matches ORDER BY updated_at DESC LIMIT 500")
    .all()
    .map((row) => JSON.parse(row.data));
}
export function listProfiles() {
  return db
    .prepare("SELECT data FROM accounts")
    .all()
    .map((row) => JSON.parse(row.data));
}
export function appendEvent(matchId, event) {
  db.prepare("INSERT INTO events(match_id,data) VALUES(?,?)").run(
    matchId,
    JSON.stringify(event),
  );
}
export function replayEvents(matchId) {
  return db
    .prepare("SELECT data FROM events WHERE match_id=? ORDER BY id")
    .all(matchId)
    .map((row) => JSON.parse(row.data));
}
export function validateDeck(deck, spells) {
  if (
    !deck ||
    typeof deck !== "object" ||
    !Array.isArray(spells) ||
    spells.length !== 3 ||
    new Set(spells).size !== 3
  )
    throw new Error("Wähle sechs Figuren und drei verschiedene Zauber.");
  for (const role of ["k", "q", "r", "b", "n", "p"])
    if (!ALL_CARDS.some((c) => c.id === deck[role] && c.role === role))
      throw new Error("Ungültige Figur im Deck.");
  for (const id of spells)
    if (!ALL_CARDS.some((c) => c.id === id && c.role === "spell"))
      throw new Error("Unbekannter Königszauber.");
  return {
    deck: Object.fromEntries(
      ["k", "q", "r", "b", "n", "p"].map((role) => [role, deck[role]]),
    ),
    spells: [...spells],
  };
}
