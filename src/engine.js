import { terrainCheck, arenaStep } from "./arenas.js";
import { Chess } from "chess.js";
import { randomBytes } from "node:crypto";
import {
  PIECES,
  SPELLS,
  DEFAULT_DECK,
  DEFAULT_SPELLS,
  BALANCE,
} from "../shared/catalog.js";
// Durations count completed plies; cooldowns count the owner's completed actions.
const FILES = "abcdefgh",
  ROLES = ["k", "q", "r", "b", "n", "p"];
const SQUARES = Array.from(
  { length: 64 },
  (_, i) => FILES[i % 8] + (1 + Math.floor(i / 8)),
);
const CARD = Object.fromEntries(PIECES.map((p) => [p.id, p])),
  SPELL = Object.fromEntries(SPELLS.map((p) => [p.id, p]));
const MAX = BALANCE?.maxMana ?? 10,
  INITIAL = BALANCE?.initialMana ?? 5,
  HAND = BALANCE?.handSize ?? 3;
const clone = (x) => structuredClone(x),
  opp = (c) => (c === "w" ? "b" : "w");
const xy = (q) => [FILES.indexOf(q?.[0]), Number(q?.[1]) - 1],
  sq = (x, y) =>
    x >= 0 && x < 8 && y >= 0 && y < 8 ? FILES[x] + (y + 1) : null;
const dist = (a, b) => {
  const [x, y] = xy(a),
    [u, v] = xy(b);
  return Math.max(Math.abs(x - u), Math.abs(y - v));
};
const check = (ok, message) => {
  if (!ok) throw new Error(message);
};
const effect = (s, q, kind) =>
  s.pieces[q]?.effects.find((e) => e.kind === kind && e.until > s.ply);
const immune = (s, q) => effect(s, q, "immune") || effect(s, q, "shield");
const locked = (s, q) =>
  s.mode !== "classic" &&
  s.pieces[q]?.variantId !== "shadow-horse" &&
  (effect(s, q, "rooted") || effect(s, q, "prison") || effect(s, q, "frog"));
const variant = (s, q) => s.pieces[q]?.variantId;
const home = (q, c) => (c === "w" ? /[12]$/.test(q) : /[78]$/.test(q));
const half = (q, c) => (c === "w" ? Number(q[1]) <= 4 : Number(q[1]) >= 5);
function deck(input) {
  if (Array.isArray(input))
    input = Object.fromEntries(input.map((id) => [CARD[id]?.role, id]));
  const d = { ...DEFAULT_DECK, ...input };
  for (const r of ROLES)
    check(
      CARD[d[r]]?.role === r,
      "Das Deck benötigt eine gültige Karte je Rolle.",
    );
  return Object.fromEntries(ROLES.map((r) => [r, d[r]]));
}
function spells(input) {
  const a = [...(input || DEFAULT_SPELLS)];
  check(
    a.length === 3 && new Set(a).size === 3 && a.every((id) => SPELL[id]),
    "Wähle drei unterschiedliche gültige Königszauber.",
  );
  return a;
}
function sync(s) {
  const ranks = [];
  for (let y = 7; y >= 0; y--) {
    let line = "",
      empty = 0;
    for (let x = 0; x < 8; x++) {
      const p = s.position[sq(x, y)];
      if (!p) empty++;
      else {
        if (empty) line += empty;
        empty = 0;
        line += p.color === "w" ? p.type.toUpperCase() : p.type;
      }
    }
    if (empty) line += empty;
    ranks.push(line);
  }
  s.fen = `${ranks.join("/")} ${s.turn} ${s.castling || "-"} ${s.enPassant || "-"} ${s.halfmove} ${s.fullmove}`;
}
function rights(s, q, p) {
  if (!p) return;
  if (p.type === "k")
    s.castling = s.castling.replace(p.color === "w" ? /[KQ]/g : /[kq]/g, "");
  const flags = { a1: "Q", h1: "K", a8: "q", h8: "k" };
  if (flags[q]) s.castling = s.castling.replace(flags[q], "");
  s.castling ||= "-";
}
function random(s) {
  s.rng = (Math.imul(s.rng, 1664525) + 1013904223) >>> 0;
  return s.rng / 4294967296;
}
function draw(s, c) {
  const pool = ROLES.filter((r) => r !== "k").map((r) => s.decks[c][r]);
  while (s.hands[c].length < HAND)
    s.hands[c].push(pool[Math.floor(random(s) * pool.length)]);
}
function mana(s, c, n) {
  s.mana[c] = Math.min(MAX, Math.max(0, s.mana[c] + n));
}
function pay(s, c, n) {
  check(s.mana[c] >= n, "Nicht genug Mana.");
  mana(s, c, -n);
}
function addEffect(s, q, kind, duration, extra = {}) {
  check(s.position[q], "Auf diesem Feld steht keine Figur.");
  s.pieces[q].effects = s.pieces[q].effects.filter((e) => e.kind !== kind);
  s.pieces[q].effects.push({ kind, until: s.ply + duration + 1, ...extra });
}
function place(s, q, type, color, id, extra = {}) {
  check(SQUARES.includes(q) && !s.position[q], "Das Zielfeld ist nicht frei.");
  check(
    type !== "p" || !/[18]$/.test(q),
    "Bauern können nicht auf einer Grundreihe entstehen.",
  );
  s.position[q] = { type, color };
  s.pieces[q] = {
    variantId: id || s.decks[color][type],
    effects: [],
    moved: true,
    startSquare: q,
    ...extra,
  };
}
function remove(s, q) {
  const p = s.position[q];
  check(p && p.type !== "k", "Ein König kann nicht entfernt werden.");
  const meta = s.pieces[q];
  rights(s, q, p);
  delete s.position[q];
  delete s.pieces[q];
  return { ...p, square: q, meta: clone(meta) };
}
function capture(s, q, c, splash = false) {
  const p = s.position[q];
  if (!p) return false;
  if (splash && (p.type === "k" || immune(s, q))) return false;
  check(p.type !== "k", "Könige werden durch Schachmatt besiegt.");
  check(!immune(s, q), "Diese Figur ist geschützt.");
  if (
    s.mode !== "classic" &&
    variant(s, q) === "shieldbearer" &&
    !s.pieces[q].shieldUsed
  ) {
    s.pieces[q].shieldUsed = true;
    return false;
  }
  const dead = remove(s, q);
  s._deaths.push(dead);
  s._capturedEvents?.push(dead);
  if (!dead.meta.ephemeral && !dead.meta.illusion)
    s.graveyard.push({ ...dead, capturedBy: c, ply: s.ply });
  s._captures[c]++;
  s.halfmove = 0;
  return true;
}
function relocate(s, from, to, c, allowCapture = true) {
  check(
    SQUARES.includes(from) && SQUARES.includes(to) && from !== to,
    "Ungültiges Start- oder Zielfeld.",
  );
  const p = s.position[from];
  check(p?.color === c, "Du kannst nur eigene Figuren bewegen.");
  check(!locked(s, from), "Diese Figur kann sich gerade nicht bewegen.");
  const target = s.position[to];
  check(
    !target || (target.color !== c && allowCapture),
    "Das Zielfeld ist besetzt.",
  );
  if (target && !capture(s, to, c)) return false;
  rights(s, from, p);
  s.position[to] = p;
  s.pieces[to] = s.pieces[from];
  s.pieces[to].moved = true;
  delete s.position[from];
  delete s.pieces[from];
  return true;
}
function ray(s, from, to, diagonal = false, straight = false) {
  if (!SQUARES.includes(from) || !SQUARES.includes(to)) return false;
  const [x, y] = xy(from),
    [u, v] = xy(to),
    dx = u - x,
    dy = v - y;
  if (!dx && !dy) return false;
  if (
    !(diagonal && Math.abs(dx) === Math.abs(dy)) &&
    !(straight && (!dx || !dy))
  )
    return false;
  for (let i = 1; i < Math.max(Math.abs(dx), Math.abs(dy)); i++)
    if (s.position[sq(x + Math.sign(dx) * i, y + Math.sign(dy) * i)])
      return false;
  return true;
}
function jump(a, b) {
  const [x, y] = xy(a),
    [u, v] = xy(b);
  return Math.abs(x - u) * Math.abs(y - v) === 2;
}
function step(a, b) {
  const [x, y] = xy(a),
    [u, v] = xy(b);
  return Math.abs(x - u) + Math.abs(y - v) === 1;
}
function attacked(s, q, by) {
  sync(s);
  if (new Chess(s.fen).isAttacked(q, by)) return true;
  if (s.mode === "classic") return false;
  for (const [from, p] of Object.entries(s.position)) {
    if (p.color !== by || locked(s, from)) continue;
    const id = variant(s, from);
    if (
      s.mana[by] < abilityCost(id) ||
      (s.pieces[from].readyTurn || 0) > s.ownTurns[by]
    ) continue;
    if (
      id === "war-king" &&
      !s.pieces[from].warUsed &&
      ray(s, from, q, true, true)
    )
      return true;
    if (id === "ranger")
      for (const via of SQUARES)
        if (step(via, q) && !s.position[via] && ray(s, from, via, true))
          return true;
    if (id === "unicorn")
      for (const via of SQUARES)
        if (!s.position[via] && jump(from, via) && step(via, q)) return true;
  }
  return false;
}
function king(s, c) {
  return Object.keys(s.position).find(
    (q) => s.position[q].type === "k" && s.position[q].color === c,
  );
}
function inCheck(s, c) {
  const q = king(s, c);
  return !q || attacked(s, q, opp(c));
}
function landing(s, to, c, didCapture) {
  if (s.mode === "classic" || !s.position[to]) return;
  const id = variant(s, to),
    [x, y] = xy(to);
  if (id === "rider" || id === "dragon-rider")
    for (let dx = -1; dx <= 1; dx++)
      for (let dy = -1; dy <= 1; dy++) {
        if (!dx && !dy) continue;
        if (id === "rider" && Math.abs(dx) + Math.abs(dy) !== 1) continue;
        const target = sq(x + dx, y + dy);
        if (s.position[target]?.color === opp(c)) capture(s, target, c, true);
      }
  if (id === "powder" && didCapture) capture(s, to, c, true);
  if (id === "shadow-horse") s.pieces[to].effects = [];
}
function standardMove(s, a, c) {
  const p = s.position[a.from];
  check(p?.color === c, "Auf dem Startfeld steht keine eigene Figur.");
  check(!locked(s, a.from), "Diese Figur kann sich gerade nicht bewegen.");
  if (s.position[a.to]) check(!immune(s, a.to), "Diese Figur ist geschützt.");
  sync(s);
  const chess = new Chess(s.fen);
  let m;
  try {
    m = chess.move({
      from: a.from,
      to: a.to,
      ...(a.promotion ? { promotion: a.promotion } : {}),
    });
  } catch {
    check(false, "Dieser Schachzug ist nicht erlaubt.");
  }
  check(m, "Dieser Schachzug ist nicht erlaubt.");
  const meta = s.pieces[a.from];
  check(
    !(s.mode !== "classic" && meta.variantId === "shieldbearer" && m.captured),
    "Schildträger können nicht schlagen.",
  );
  if (m.flags.includes("k") || m.flags.includes("q")) {
    const transit =
      (m.flags.includes("k") ? "f" : "d") + (c === "w" ? "1" : "8");
    check(
      !inCheck(s, c) && !attacked(s, transit, opp(c)),
      "Eine Rochade durch Schach ist nicht erlaubt.",
    );
  }
  if (m.flags.includes("e")) capture(s, a.to[0] + a.from[1], c);
  if (!relocate(s, a.from, a.to, c)) {
    s.enPassant = "-";
    s._notation = "Schild pariert";
    return;
  }
  if (m.flags.includes("k") || m.flags.includes("q")) {
    const r = c === "w" ? "1" : "8";
    relocate(
      s,
      (m.flags.includes("k") ? "h" : "a") + r,
      (m.flags.includes("k") ? "f" : "d") + r,
      c,
      false,
    );
  }
  if (m.promotion) {
    s.position[a.to].type = m.promotion;
    s.pieces[a.to] = {
      ...meta,
      variantId: s.decks[c][m.promotion],
      effects: [],
      moved: true,
    };
  }
  const parts = chess.fen().split(" ");
  s.castling =
    parts[2]
      .split("")
      .filter((flag) => s.castling.includes(flag))
      .join("") || "-";
  s.enPassant = parts[3];
  s.halfmove = Number(parts[4]);
  s._notation = m.san;
  landing(s, a.to, c, Boolean(m.captured));
}
function deaths(s) {
  let guard = 0;
  while (s._deaths.length) {
    check(guard++ < 128, "Zu viele verkettete Effekte.");
    const d = s._deaths.shift(),
      id = d.meta.variantId;
    if (s.mode === "classic") continue;
    if (id === "phoenix" && !d.meta.reborn) {
      const r = d.color === "w" ? "2" : "7",
        q = d.meta.startSquare || d.square[0] + r;
      if (q && !s.position[q]) place(s, q, "p", d.color, id, { reborn: true });
    }
    if (id === "powder") {
      const [x, y] = xy(d.square);
      for (let dx = -1; dx <= 1; dx++)
        for (let dy = -1; dy <= 1; dy++) {
          const q = sq(x + dx, y + dy);
          if (q && s.position[q]) capture(s, q, opp(d.color), true);
        }
    }
  }
}
function summon(s, a, c) {
  const card = CARD[a.cardId],
    i = s.hands[c].indexOf(a.cardId);
  check(card && card.role !== "k", "Könige können nicht beschworen werden.");
  check(i >= 0, "Diese Karte ist nicht auf deiner Hand.");
  check(
    SQUARES.includes(a.to) && home(a.to, c),
    "Beschwöre auf einer freien eigenen Startreihe.",
  );
  pay(s, c, card.mana);
  place(s, a.to, card.role, c, a.cardId);
  s.hands[c].splice(i, 1);
  s.halfmove = 0;
  s._notation = `${card.name} → ${a.to}`;
}
function swap(s, from, to) {
  const a = s.position[from],
    b = s.position[to],
    am = s.pieces[from],
    bm = s.pieces[to];
  check(
    a && b && a.color === b.color,
    "Tauschen erfordert zwei eigene Figuren.",
  );
  check(
    !(a.type === "p" && /[18]$/.test(to)) &&
      !(b.type === "p" && /[18]$/.test(from)),
    "Bauern können nicht auf eine Grundreihe getauscht werden.",
  );
  rights(s, from, a);
  rights(s, to, b);
  s.position[from] = b;
  s.position[to] = a;
  s.pieces[from] = bm;
  s.pieces[to] = am;
  am.moved = bm.moved = true;
}
function cast(s, a, c) {
  const card = SPELL[a.spellId],
    k = king(s, c);
  check(
    card && s.spells[c].includes(a.spellId),
    "Dieser Königszauber ist nicht ausgerüstet.",
  );
  check(
    (s.cooldowns[c][a.spellId] || 0) <= s.ownTurns[c],
    "Dieser Zauber lädt noch auf.",
  );
  check(!locked(s, k), "Der König kann gerade nicht zaubern.");
  pay(s, c, card.mana);
  const t = s.position[a.to];
  switch (a.spellId) {
    case "flee":
      check(
        SQUARES.includes(a.to) && dist(k, a.to) <= 2 && !t,
        "Flucht benötigt ein freies Feld in Reichweite 2.",
      );
      relocate(s, k, a.to, c, false);
      break;
    case "shield":
      check(t?.color === c, "Wähle eine eigene Figur.");
      addEffect(s, a.to, "immune", card.duration || 2);
      break;
    case "command":
    case "time-stop":
      s.extraTurns[c] += 2;
      break;
    case "meteor": {
      check(SQUARES.includes(a.to), "Wähle ein Meteorfeld.");
      const [x, y] = xy(a.to),
        victims = [
          sq(x, y),
          sq(x + 1, y),
          sq(x, y + 1),
          sq(x + 1, y + 1),
        ].filter(
          (q) =>
            q &&
            s.position[q]?.color === opp(c) &&
            s.position[q].type !== "k" &&
            !immune(s, q),
        );
      check(
        victims.length,
        "In diesem 2×2-Gebiet steht kein ungeschütztes gegnerisches Ziel.",
      );
      const victim = a.target || victims[0];
      check(victims.includes(victim), "Das Ziel liegt nicht im Meteor-Gebiet.");
      capture(s, victim, c);
      break;
    }
    case "banish":
      check(
        t?.color === opp(c) && t.type !== "k" && !immune(s, a.to),
        "Wähle eine ungeschützte gegnerische Figur außer dem König.",
      );
      s.banished.push({
        ...remove(s, a.to),
        returnPly: s.ply + (card.duration || 6) + 1,
      });
      break;
    case "throne":
      check(
        t?.color === c && t.type !== "k" && !locked(s, a.to),
        "Wähle eine bewegliche eigene Figur.",
      );
      swap(s, k, a.to);
      break;
    case "prison":
      check(
        t?.color === opp(c) &&
          !immune(s, a.to) &&
          !effect(s, a.to, "invisible"),
        "Wähle eine sichtbare, ungeschützte gegnerische Figur.",
      );
      check(
        variant(s, a.to) !== "shadow-horse",
        "Das Schattenross ignoriert solche Effekte.",
      );
      addEffect(s, a.to, "prison", card.duration || 4);
      break;
    default:
      check(false, "Unbekannter Königszauber.");
  }
  s.cooldowns[c][a.spellId] = s.ownTurns[c] + card.cooldown + 1;
  s._notation = card.name;
}
const ACTIVE = new Set([
  "time-king",
  "flee-king",
  "shadow-king",
  "war-king",
  "marsh-witch",
  "mirror-mage",
  "storm-queen",
  "bastion",
  "ram",
  "catapult",
  "seer",
  "priest",
  "fire-mage",
  "necromancer",
  "ranger",
  "unicorn",
  "assassin",
  "spy",
]);
export function abilityCost(id) {
  return Math.max(1, Math.ceil((CARD[id]?.mana || 2) / 2));
}
function ability(s, a, c) {
  const p = s.position[a.from],
    meta = s.pieces[a.from],
    id = meta?.variantId;
  check(
    p?.color === c && ACTIVE.has(id),
    "Diese Figur besitzt keine aktive Fähigkeit.",
  );
  check(
    !locked(s, a.from),
    "Diese Figur kann gerade keine Fähigkeit einsetzen.",
  );
  check(
    (meta.readyTurn || 0) <= s.ownTurns[c],
    "Diese Fähigkeit lädt noch auf.",
  );
  const cost = abilityCost(id);
  pay(s, c, cost);
  const t = s.position[a.to];
  switch (id) {
    case "time-king": {
      check(
        !s.usedAbilities[c].rewind && s._snapshots.length >= 2,
        "Zeitumkehr ist einmal pro Partie nach zwei vergangenen Aktionen verfügbar.",
      );
      const old = s._snapshots.at(-2);
      for (const field of [
        "ply",
        "terrain",
        "resonance",
        "position",
        "pieces",
        "castling",
        "enPassant",
        "halfmove",
        "fullmove",
        "hands",
        "mana",
        "graveyard",
        "banished",
        "rng",
        "cooldowns",
        "ownTurns",
        "extraTurns",
      ])
        s[field] = clone(old[field]);
      s.turn = c;
      s.usedAbilities[c].rewind = true;
      pay(s, c, cost);
      break;
    }
    case "flee-king":
      check(
        SQUARES.includes(a.to) && dist(a.from, a.to) <= 2 && !t,
        "Teleport benötigt ein freies Feld in Reichweite 2.",
      );
      relocate(s, a.from, a.to, c, false);
      break;
    case "shadow-king":
      addEffect(s, a.from, "invisible", 4);
      break;
    case "war-king":
      check(
        !meta.warUsed && ray(s, a.from, a.to, true, true),
        "Der einmalige Damenzug ist hier nicht möglich.",
      );
      meta.warUsed = true;
      relocate(s, a.from, a.to, c);
      landing(s, a.to, c, Boolean(t));
      break;
    case "marsh-witch":
      check(
        t?.color === opp(c) && t.type === "p" && !immune(s, a.to),
        "Wähle eine ungeschützte gegnerische Figur außer dem König.",
      );
      check(
        !/[18]$/.test(a.to),
        "Auf einer Grundreihe kann kein Frosch entstehen.",
      );
      check(
        variant(s, a.to) !== "shadow-horse",
        "Das Schattenross ignoriert Verwandlungen.",
      );
      check(!effect(s, a.to, "frog"), "Diese Figur ist bereits verwandelt.");
      addEffect(s, a.to, "frog", 6, { originalType: t.type });
      rights(s, a.to, t);
      t.type = "p";
      break;
    case "mirror-mage":
      check(
        SQUARES.includes(a.to) && dist(a.from, a.to) <= 1 && !t,
        "Das Trugbild benötigt ein freies Feld in Reichweite 2.",
      );
      place(s, a.to, "q", c, id, { illusion: true, ephemeral: true });
      addEffect(s, a.to, "illusion", 4);
      break;
    case "storm-queen":
      check(
        SQUARES.includes(a.via) &&
          s.position[a.via]?.color === opp(c) &&
          ray(s, a.from, a.via, true, true),
        "Zuerst muss die Dame eine gegnerische Figur schlagen.",
      );
      check(
        step(a.via, a.to) && !t && a.to !== a.from,
        "Danach folgt ein freier orthogonaler Schritt.",
      );
      relocate(s, a.from, a.via, c);
      relocate(s, a.via, a.to, c, false);
      break;
    case "bastion":
      addEffect(s, a.from, "immune", 4);
      addEffect(s, a.from, "rooted", 4);
      break;
    case "ram": {
      check(SQUARES.includes(a.to), "Wähle ein gültiges Durchbruchsziel.");
      const [x, y] = xy(a.from),
        [u, v] = xy(a.to),
        dx = Math.sign(u - x),
        dy = Math.sign(v - y);
      check(
        (x === u || y === v) && a.from !== a.to && t?.color === opp(c),
        "Durchbruch benötigt zwei Gegner auf einer Turmlinie.",
      );
      const blockers = [];
      for (let i = 1; i < dist(a.from, a.to); i++) {
        const q = sq(x + dx * i, y + dy * i);
        if (s.position[q]) blockers.push(q);
      }
      check(
        blockers.length === 1 &&
          s.position[blockers[0]].color === opp(c) &&
          dist(blockers[0], a.to) === 1,
        "Das zweite Ziel muss direkt hinter dem ersten Gegner stehen.",
      );
      check(capture(s, blockers[0], c), "Der Schild stoppt den Durchbruch.");
      relocate(s, a.from, a.to, c);
      break;
    }
    case "catapult":
      check(
        t?.color === opp(c) &&
          dist(a.from, a.to) <= 3 &&
          ray(s, a.from, a.to, false, true),
        "Fernschuss benötigt ein Ziel auf freier Turmlinie in Reichweite 3.",
      );
      capture(s, a.to, c);
      break;
    case "seer":
      check(
        t?.color === c && a.from !== a.to && !locked(s, a.to),
        "Wähle eine andere bewegliche eigene Figur.",
      );
      swap(s, a.from, a.to);
      break;
    case "priest": {
      const i = s.graveyard.findLastIndex((p) => p.color === c && !p.revived);
      check(i >= 0, "Es gibt keine eigene gefallene Figur zur Wiederbelebung.");
      check(
        SQUARES.includes(a.to) && a.to[1] === (c === "w" ? "2" : "7") && !t,
        "Wiederbelebung benötigt eine freie eigene Bauernstartreihe.",
      );
      s.graveyard[i].revived = true;
      place(s, a.to, "p", c, s.decks[c].p);
      break;
    }
    case "fire-mage":
      check(
        t?.color === opp(c) && dist(a.from, a.to) <= 3,
        "Feuerball benötigt ein gegnerisches Ziel in Reichweite 3.",
      );
      capture(s, a.to, c);
      break;
    case "necromancer": {
      const corpse = s.graveyard.findLast(
        (p) => p.color === opp(c) && !p.consumed,
      );
      check(corpse, "Du benötigst eine gefallene gegnerische Figur.");
      corpse.consumed = true;
      check(
        SQUARES.includes(a.to) && half(a.to, c) && !t && !/[18]$/.test(a.to),
        "Der Geisterbauer benötigt ein freies Feld in deiner Hälfte.",
      );
      place(s, a.to, "p", c, s.decks[c].p, { ephemeral: true });
      addEffect(s, a.to, "ghost", 6);
      break;
    }
    case "ranger":
      check(
        SQUARES.includes(a.via) &&
          !s.position[a.via] &&
          ray(s, a.from, a.via, true) &&
          step(a.via, a.to) &&
          a.to !== a.from,
        "Winkelzug: freie Läuferdiagonale, danach ein orthogonaler Schritt.",
      );
      relocate(s, a.from, a.to, c);
      landing(s, a.to, c, Boolean(t));
      break;
    case "unicorn":
      check(
        SQUARES.includes(a.via) &&
          !s.position[a.via] &&
          jump(a.from, a.via) &&
          step(a.via, a.to) &&
          a.to !== a.from,
        "Einhorn: freier Springersprung, danach ein orthogonaler Schritt.",
      );
      relocate(s, a.from, a.to, c);
      landing(s, a.to, c, Boolean(t));
      break;
    case "assassin": {
      const [x, y] = xy(a.from),
        [u, v] = xy(a.to);
      check(
        Math.abs(x - u) === 1 &&
          v - y === (c === "w" ? 1 : -1) &&
          !t &&
          !/[18]$/.test(a.to),
        "Assassinen ziehen diagonal vorwärts auf ein freies Feld.",
      );
      relocate(s, a.from, a.to, c, false);
      break;
    }
    case "spy":
      s.reveals[c] = s.ply + 5;
      break;
    default:
      check(false, "Unbekannte Fähigkeit.");
  }
  if (s.pieces[a.from] === meta || s.pieces[a.to] === meta)
    meta.readyTurn = s.ownTurns[c] + 3;
  s._notation = `${CARD[id].name}: Fähigkeit`;
}
function expire(s) {
  for (const [q, meta] of Object.entries(s.pieces)) {
    if (!s.position[q]) continue;
    for (const e of meta.effects.filter((e) => e.until <= s.ply)) {
      if (e.kind === "frog") s.position[q].type = e.originalType;
      if (
        (e.kind === "ghost" || e.kind === "illusion") &&
        s.position[q]?.type !== "k"
      )
        remove(s, q);
    }
    if (s.pieces[q])
      s.pieces[q].effects = meta.effects.filter((e) => e.until > s.ply);
  }
  const pending = [];
  for (const item of s.banished) {
    if (item.returnPly > s.ply) {
      pending.push(item);
      continue;
    }
    const q = [
      item.square,
      ...SQUARES.filter((q) => q !== item.square).sort(
        (a, b) => dist(a, item.square) - dist(b, item.square),
      ),
    ].find((q) => !s.position[q] && (item.type !== "p" || !/[18]$/.test(q)));
    if (q) place(s, q, item.type, item.color, item.meta.variantId, item.meta);
    else pending.push({ ...item, returnPly: s.ply + 1 });
  }
  s.banished = pending;
}
function transition(state, action, c) {
  check(state && !state.result, "Diese Partie ist bereits beendet.");
  check(c === state.turn, "Du bist nicht am Zug.");
  check(action && typeof action === "object", "Ungültige Aktion.");
  const s = clone(state),
    a = clone(action);
  s._deaths = [];
  s._capturedEvents = [];
  s._captures = { w: 0, b: 0 };
  s._notation = "";
  s.enPassant = a.type === "move" ? state.enPassant : "-";
  s.halfmove++;
  terrainCheck(s, a);
  if (a.type === "move") standardMove(s, a, c);
  else {
    check(
      s.mode !== "classic",
      "Im klassischen Modus sind nur Schachzüge erlaubt.",
    );
    if (a.type === "summon") summon(s, a, c);
    else if (a.type === "spell") cast(s, a, c);
    else if (a.type === "ability") ability(s, a, c);
    else check(false, "Unbekannte Aktionsart.");
  }
  deaths(s);
  arenaStep(s, a, c, { random, capture, place, inCheck, relocate });
  deaths(s);
  s.ownTurns[c]++;
  if (s.mode !== "classic") {
    const captures = s._captures[c];
    if (captures && variant(state, a.from) === "gold-king") mana(s, c, 1);
    if (captures && variant(state, a.from) === "blood-countess") mana(s, c, 1);
    mana(s, c, BALANCE?.manaPerTurn ?? 1);
    const sourceId = a.spellId || a.cardId || variant(state, a.from);
    const level = Math.min(
      10,
      Math.max(1, s.levels?.[c]?.[sourceId]?.level || 1),
    );
    s.resonance ??= { w: 0, b: 0 };
    s.resonance[c] += level - 1;
    if (s.resonance[c] >= 10) {
      mana(s, c, Math.floor(s.resonance[c] / 10));
      s.resonance[c] %= 10;
    }
    if (s.ownTurns[c] % 2 === 0)
      mana(
        s,
        c,
        Object.keys(s.position).filter(
          (q) => s.position[q].color === c && variant(s, q) === "miner",
        ).length,
      );
    draw(s, c);
  }
  s.ply++;
  expire(s);
  check(
    king(s, "w") && king(s, "b"),
    "Beide Könige müssen auf dem Brett bleiben.",
  );
  check(!inCheck(s, c), "Dein König würde im Schach stehen.");
  if (s.extraTurns[c] > 0) {
    s.extraTurns[c]--;
    s.turn = c;
  } else s.turn = opp(c);
  if (c === "b") s.fullmove++;
  s.version = state.version + 1;
  sync(s);
  s.check = inCheck(s, s.turn);
  s.history.push({
    ply: s.ply,
    color: c,
    action: a,
    notation: s._notation,
    fen: s.fen,
  });
  delete s._deaths;
  delete s._capturedEvents;
  delete s._captures;
  delete s._notation;
  return s;
}
function* candidates(s, c) {
  let chess;
  try {
    chess = new Chess(s.fen);
  } catch {
    return;
  }
  for (const m of chess.moves({ verbose: true }))
    yield {
      type: "move",
      from: m.from,
      to: m.to,
      ...(m.promotion ? { promotion: m.promotion } : {}),
    };
  if (s.mode === "classic") return;
  for (const cardId of new Set(s.hands[c])) {
    if (CARD[cardId].mana > s.mana[c]) continue;
    for (const to of SQUARES)
      if (
        home(to, c) &&
        !s.position[to] &&
        (CARD[cardId].role !== "p" || !/[18]$/.test(to))
      )
        yield { type: "summon", cardId, to };
  }
  for (const spellId of s.spells[c]) {
    if (
      SPELL[spellId].mana > s.mana[c] ||
      (s.cooldowns[c][spellId] || 0) > s.ownTurns[c]
    )
      continue;
    if (["command", "time-stop"].includes(spellId)) {
      yield { type: "spell", spellId };
      continue;
    }
    for (const to of SQUARES) yield { type: "spell", spellId, to };
  }
  for (const [from, p] of Object.entries(s.position)) {
    if (p.color !== c) continue;
    const id = variant(s, from);
    if (
      !ACTIVE.has(id) ||
      locked(s, from) ||
      abilityCost(id) > s.mana[c] ||
      (s.pieces[from].readyTurn || 0) > s.ownTurns[c]
    )
      continue;
    if (["time-king", "shadow-king", "bastion", "spy"].includes(id)) {
      yield { type: "ability", from };
      continue;
    }
    if (["ranger", "unicorn", "storm-queen"].includes(id)) {
      for (const via of SQUARES) {
        const viable =
          id === "ranger"
            ? !s.position[via] && ray(s, from, via, true)
            : id === "unicorn"
              ? !s.position[via] && jump(from, via)
              : s.position[via]?.color === opp(c) &&
                ray(s, from, via, true, true);
        if (!viable) continue;
        const [x, y] = xy(via);
        for (const [dx, dy] of [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1],
        ]) {
          const to = sq(x + dx, y + dy);
          if (to && to !== from) yield { type: "ability", from, via, to };
        }
      }
      continue;
    }
    for (const to of SQUARES)
      if (to !== from) yield { type: "ability", from, to };
  }
}
export function legalActions(state, color = state.turn) {
  if (state.result || color !== state.turn) return [];
  const result = [];
  for (const a of candidates(state, color))
    try {
      transition(state, a, color);
      result.push(a);
    } catch {}
  return result;
}
function repetition(s) {
  if (s.mode === "classic") return s.fen.split(" ").slice(0, 4).join(" ");
  return JSON.stringify([
    s.fen.split(" ").slice(0, 4),
    s.pieces,
    s.mana,
    s.hands,
    s.cooldowns,
    s.banished,
    s.extraTurns,
    s.usedAbilities,
  ]);
}
function adjudicate(s) {
  const chess = new Chess(s.fen);
  if (!legalActions(s).length)
    s.result = {
      winner: s.check ? opp(s.turn) : null,
      reason: s.check ? "checkmate" : "stalemate",
    };
  else if (s.mode === "classic" && chess.isInsufficientMaterial())
    s.result = { winner: null, reason: "insufficient-material" };
  else if (s.mode === "classic" && s.halfmove >= 100)
    s.result = { winner: null, reason: "fifty-move" };
  else if ((s.repetitions[repetition(s)] || 0) >= 3)
    s.result = { winner: null, reason: "threefold-repetition" };
}
export function createGame({
  deckWhite,
  deckBlack,
  spellsWhite,
  spellsBlack,
  mode = "fantasy",
  difficulty = "easy",
  arena = "hall",
  fen,
  seed,
  levelsWhite = {},
  levelsBlack = {},
} = {}) {
  check(["classic", "fantasy"].includes(mode), "Unbekannter Spielmodus.");
  const chess = new Chess(fen),
    parts = chess.fen().split(" ");
  const s = {
    mode,
    difficulty,
    arena,
    terrain: [],
    levels: { w: clone(levelsWhite), b: clone(levelsBlack) },
    resonance: { w: 0, b: 0 },
    version: 0,
    ply: 0,
    turn: parts[1],
    fen: chess.fen(),
    castling: parts[2],
    enPassant: parts[3],
    halfmove: Number(parts[4]),
    fullmove: Number(parts[5]),
    position: {},
    pieces: {},
    decks: { w: deck(deckWhite), b: deck(deckBlack) },
    spells: { w: spells(spellsWhite), b: spells(spellsBlack) },
    mana: { w: INITIAL, b: INITIAL },
    hands: { w: [], b: [] },
    cooldowns: { w: {}, b: {} },
    ownTurns: { w: 0, b: 0 },
    extraTurns: { w: 0, b: 0 },
    usedAbilities: { w: {}, b: {} },
    reveals: { w: 0, b: 0 },
    graveyard: [],
    banished: [],
    history: [],
    result: null,
    check: false,
    rng: seed === undefined ? randomBytes(4).readUInt32LE() : seed >>> 0,
    repetitions: {},
    _snapshots: [],
  };
  for (const row of chess.board())
    for (const p of row)
      if (p) {
        s.position[p.square] = { type: p.type, color: p.color };
        s.pieces[p.square] = {
          variantId: s.decks[p.color][p.type],
          effects: [],
          moved: false,
          startSquare: p.square,
        };
      }
  if (mode !== "classic") {
    draw(s, "w");
    draw(s, "b");
  }
  s.check = inCheck(s, s.turn);
  s.repetitions[repetition(s)] = 1;
  adjudicate(s);
  return s;
}
export function applyAction(state, action, color = state.turn) {
  const next = transition(state, action, color),
    snapshot = clone(state);
  delete snapshot._snapshots;
  next._snapshots = [...state._snapshots, snapshot].slice(-4);
  const key = repetition(next);
  next.repetitions[key] = (next.repetitions[key] || 0) + 1;
  adjudicate(next);
  return next;
}
export function publicState(s, color) {
  const c = color === "w" || color === "b" ? color : null,
    board = Object.entries(s.position).map(([square, p]) => ({
      square,
      ...p,
      variantId: s.pieces[square].variantId,
      effects: clone(s.pieces[square].effects),
      abilityCost: abilityCost(s.pieces[square].variantId),
    }));
  return {
    mode: s.mode,
    difficulty: s.difficulty,
    arena: s.arena,
    terrain: clone(s.terrain || []),
    arenaNotice: s.arenaNotice || "",
    resonance: clone(s.resonance || {}),
    board,
    fen: s.fen,
    turn: s.turn,
    color: c,
    version: s.version,
    ply: s.ply,
    check: s.check,
    result: clone(s.result),
    mana: clone(s.mana),
    hand: c ? clone(s.hands[c]) : [],
    handCounts: { w: s.hands.w.length, b: s.hands.b.length },
    spells: c
      ? s.spells[c].map((id) => ({
          ...SPELL[id],
          remainingCooldown: Math.max(
            0,
            (s.cooldowns[c][id] || 0) - s.ownTurns[c],
          ),
        }))
      : [],
    cooldowns: c ? clone(s.cooldowns[c]) : {},
    ownTurns: clone(s.ownTurns),
    enemyHand: c && s.reveals[c] > s.ply ? clone(s.hands[opp(c)]) : null,
    enemySpells: c && s.reveals[c] > s.ply ? clone(s.spells[opp(c)]) : null,
    history: clone(s.history),
    legalActions: c === s.turn ? legalActions(s, c) : [],
    graveyard: clone(s.graveyard),
    banished: s.banished.map(({ square, type, color, returnPly }) => ({
      square,
      type,
      color,
      returnPly,
    })),
  };
}
export function simulateAction(state, action, color = state.turn) {
  return transition(state, action, color);
}
