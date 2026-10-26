import { createPolish } from "/polish.js";
import { createOnlineUI } from "/multiplayer-ui.js";
import { createProgressUI } from "/progression-ui.js";
import * as catalog from "/shared/catalog.js";
import { startFrame } from "/frame.js";

const PIECES = Array.isArray(catalog.PIECES)
  ? catalog.PIECES
  : Object.values(catalog.PIECES || {});
const SPELLS = Array.isArray(catalog.SPELLS)
  ? catalog.SPELLS
  : Object.values(catalog.SPELLS || {});
const DEFAULT_DECK = catalog.DEFAULT_DECK || {};
const DEFAULT_SPELLS = catalog.DEFAULT_SPELLS || [];
const params = new URLSearchParams(location.search);
const device = params.get("device") || "main";
const storageKey = `chess-royale:${device}`;
const roleNames = {
  k: "König",
  q: "Dame",
  r: "Turm",
  b: "Läufer",
  n: "Springer",
  p: "Bauer",
};
const glyphs = { k: "♚", q: "♛", r: "♜", b: "♝", n: "♞", p: "♟" };
const roleOrder = ["k", "q", "r", "b", "n", "p"];
const difficulties = { easy: "Leicht", medium: "Mittel", hard: "Schwer" };
const spellSymbols = ["✦", "❄", "♧", "↯", "◈", "☼"];
const icons = {
  crown: '<path d="m3 7 4 4 5-7 5 7 4-4-2 12H5L3 7Z"/><path d="M6 16h12"/>',
  home: '<path d="M3 21V8h5v13m8 0V8h5v13M2 8V3h2v2h3V3h2v5m6 0V3h2v2h3V3h2v5M8 11h8M10 21v-5a2 2 0 0 1 4 0v5M2 21h20"/>',
  cards:
    '<rect x="7" y="5" width="12" height="15" rx="2"/><path d="m7 17-4-1 1-13 12 1M13 10v5m-2.5-2.5h5"/>',
  shop: '<path d="M4 10h16v10H4zM3 10l2-6h14l2 6M8 4l-1 6m9-6 1 6M9 20v-6h6v6"/>',
  chest:
    '<path d="M3 11c0-5 3-7 9-7s9 2 9 7v8H3v-8Z"/><path d="M3 11h18M8 4v7m8-7v7"/><rect x="10" y="10" width="4" height="5" rx="1"/>',
  arena:
    '<path d="M3 20V9h5v11m8 0V9h5v11M2 9V5h2v2h3V5h2v4m6 0V5h2v2h3V5h2v4M8 12h8M10 20v-4a2 2 0 0 1 4 0v4M2 20h20"/>',
  trophy:
    '<path d="M7 3h10v6a5 5 0 0 1-10 0V3ZM7 5H3v3a4 4 0 0 0 5 4m9-7h4v3a4 4 0 0 1-5 4m-4 2v5m-4 2h8m-6-2h4"/>',
  coin: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="5"/><path d="M12 9v6"/>',
  gem: '<path d="m3 8 4-4h10l4 4-9 12L3 8Zm0 0h18M7 4l5 16 5-16"/>',
  settings:
    '<path d="m10 3-1 3-3 1-3-1-1 3 3 2v3l-2 2 2 3 3-1 2 2 1 2h3l1-3 3-1 2 1 2-3-2-2v-3l2-2-2-3-3 1-2-1-1-3h-4Z"/><circle cx="12" cy="12" r="3"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 0 1 5 0c0 2-2.5 2-2.5 4m0 3h.01"/>',
  arrow: '<path d="M4 12h15m-5-5 5 5-5 5"/>',
  back: '<path d="m14 5-7 7 7 7"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  sword: '<path d="m14 4 6-1-1 6-10 10-4-4L14 4ZM4 12l8 8M3 21l4-4"/>',
  wand: '<path d="m4 20 12-12 3 3L7 23m7-21v3m6-1 1 2m-1 11 2 1M8 5l1 2m-6 5h3"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 5v2"/>',
  flag: '<path d="M5 22V3m0 1c5-4 9 4 15 0v10c-6 4-10-4-15 0"/>',
  history: '<path d="M3 11a9 9 0 1 1 2 7M3 4v7h7m2-4v5l4 2"/>',
  bug: '<path d="M8 8h8v8a4 4 0 0 1-8 0V8ZM9 8V6a3 3 0 0 1 6 0v2m-7 3-4-2m4 6H3m5 3-4 3m12-10 4-2m-4 6h5m-5 3 4 3m-8-13v12"/>',
  sound:
    '<path d="m11 4-6 5H2v6h3l6 5V4Zm4 4a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14"/>',
  leaf: '<path d="M20 3C8 1 2 8 5 15s15 3 15-12ZM5 20 16 8"/>',
};
const icon = (name) =>
  `<span class="icon" aria-hidden="true"><svg viewBox="0 0 24 24">${icons[name] || icons.crown}</svg></span>`;
const esc = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (char) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        char
      ],
  );
const number = (value) =>
  new Intl.NumberFormat("de-DE").format(Number(value) || 0);
const pieceById = (id) => PIECES.find((item) => item.id === id);
const spellById = (id) => SPELLS.find((item) => item.id === id);
const spellSymbol = (id) =>
  spellSymbols[
    Math.max(
      0,
      SPELLS.findIndex((item) => item.id === id),
    ) % spellSymbols.length
  ];
const isLocal = ["localhost", "127.0.0.1", "[::1]"].includes(location.hostname);
const readStored = () => {
  try {
    return JSON.parse(localStorage.getItem(storageKey) || "{}");
  } catch {
    return {};
  }
};
const stored = readStored();
const ui = {
  tab: "home",
  profile: null,
  token: stored.token || "",
  match: null,
  savedMatchId: stored.matchId || "",
  difficulty: stored.difficulty || "medium",
  mode: stored.mode || "fantasy",
  arena: "hall",
  role: "k",
  collectionFilter: "all",
  collectionOwned: false,
  selection: null,
  modal: null,
  busy: false,
  bootError: "",
  network: "normal",
  toast: "",
  toastError: false,
  historyOpen: false,
  sound: stored.sound !== false,
  vibration: stored.vibration !== false,
  deckSaving: false,
  resultShown: "",
};
let app;
let toastTimer;
let audioContext;
let savingDeck = Promise.resolve();
const progress = createProgressUI({
  ui,
  request,
  render,
  toast,
  sound,
  vibrate,
});
const online = createOnlineUI({
  ui,
  request,
  render,
  toast,
  persist,
  showResult,
  progress,
  sound,
});
const polish = createPolish({
  ui,
  request,
  render,
  toast,
  persist,
  startMatch,
  performAction,
});
function persist() {
  try {
    localStorage.setItem(
      storageKey,
      JSON.stringify({
        token: ui.token,
        matchId: ui.match?.matchId || ui.savedMatchId,
        difficulty: ui.difficulty,
        mode: ui.mode,
        sound: ui.sound,
        vibration: ui.vibration,
        settings: ui.profile?.settings,
      }),
    );
  } catch {
    /* Private browsing may disable persistence. */
  }
}
async function request(path, data, method) {
  if (ui.network === "offline" || !navigator.onLine)
    throw new Error("Du bist offline. Verbinde dich, um weiterzuspielen.");
  if (ui.network === "slow")
    await new Promise((resolve) => setTimeout(resolve, 1800));
  const response = await fetch(path, {
    method: method || (data ? "POST" : "GET"),
    headers: {
      "Content-Type": "application/json",
      ...(ui.token ? { Authorization: `Bearer ${ui.token}` } : {}),
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok)
    throw new Error(
      payload.error?.message ||
        payload.error ||
        payload.message ||
        "Das hat gerade nicht geklappt. Versuch es erneut.",
    );
  return payload;
}
function sound(kind = "tap") {
  if (!ui.sound) return;
  try {
    audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
    if (audioContext.state === "suspended") audioContext.resume();
    if (kind === "legendary") {
      for (const [i, f] of [196, 246.94, 293.66, 392].entries()) {
        const o = audioContext.createOscillator(),
          g = audioContext.createGain();
        o.type = "sine";
        o.frequency.value = f;
        g.gain.setValueAtTime(0, audioContext.currentTime);
        g.gain.linearRampToValueAtTime(
          0.045,
          audioContext.currentTime + 0.15 + i * 0.05,
        );
        g.gain.exponentialRampToValueAtTime(
          0.001,
          audioContext.currentTime + 1.8,
        );
        o.connect(g);
        g.connect(audioContext.destination);
        o.start();
        o.stop(audioContext.currentTime + 2);
      }
      return;
    }
    const tone = audioContext.createOscillator();
    const gain = audioContext.createGain();
    tone.type = kind === "move" ? "triangle" : "sine";
    tone.frequency.setValueAtTime(
      kind === "capture" ? 190 : kind === "move" ? 410 : 660,
      audioContext.currentTime,
    );
    tone.frequency.exponentialRampToValueAtTime(
      kind === "capture" ? 80 : 290,
      audioContext.currentTime + 0.09,
    );
    gain.gain.setValueAtTime(0.035, audioContext.currentTime);
    gain.gain.exponentialRampToValueAtTime(
      0.001,
      audioContext.currentTime + 0.12,
    );
    tone.connect(gain);
    gain.connect(audioContext.destination);
    tone.start();
    tone.stop(audioContext.currentTime + 0.13);
  } catch {
    /* Audio is optional. */
  }
}
function vibrate() {
  if (ui.vibration && navigator.vibrate) navigator.vibrate(12);
}
function toast(message, error = false) {
  ui.toast = message;
  ui.toastError = error;
  clearTimeout(toastTimer);
  render();
  toastTimer = setTimeout(() => {
    ui.toast = "";
    render();
  }, 3400);
}
function boardEntries() {
  const board = ui.match?.state?.board || [];
  if (Array.isArray(board))
    return board
      .flat()
      .filter(Boolean)
      .map((piece, index) =>
        typeof piece === "object"
          ? piece
          : {
              square: `${"abcdefgh"[index % 8]}${8 - Math.floor(index / 8)}`,
              type: piece.toLowerCase(),
              color: piece === piece.toUpperCase() ? "w" : "b",
            },
      );
  return Object.entries(board)
    .filter(([, value]) => value)
    .map(([square, piece]) => ({ square, ...piece }));
}
function ownColor() {
  return ui.match?.color || "w";
}
function ownTurn() {
  return (
    !ui.replay &&
    ui.match?.color != null &&
    ui.match?.state?.turn === ownColor() &&
    !ui.match?.state?.result
  );
}
function legalActions() {
  return ui.match?.state?.legalActions || [];
}
function manaFor(color) {
  const value = ui.match?.state?.mana?.[color];
  return Number(value?.current ?? value?.amount ?? value ?? 0);
}
function selectedActions() {
  if (!ui.selection) return [];
  const selected = ui.selection;
  return legalActions().filter((action) => {
    if (selected.type === "move" || selected.type === "ability")
      return action.type === selected.type && action.from === selected.from;
    if (selected.type === "summon")
      return (
        action.type === "summon" &&
        (action.cardId === selected.cardId ||
          action.variantId === selected.cardId)
      );
    return action.type === "spell" && action.spellId === selected.spellId;
  });
}
function profileDeck() {
  return ui.profile?.deck || DEFAULT_DECK;
}
function profileSpells() {
  return ui.profile?.spells || DEFAULT_SPELLS;
}
function manaDisplay(color) {
  const value = manaFor(color);
  return `<div class="mana-display" aria-label="${value} von 10 Mana"><span class="mana-dots">${Array.from({ length: 10 }, (_, i) => `<i class="mana-dot ${i < value ? "filled" : ""}"></i>`).join("")}</span><span class="mana-number">${value}</span></div>`;
}
function header() {
  const profile = ui.profile;
  return `<header class="app-header"><div class="header-top"><div class="wordmark">${icon("crown")}<span>CHESS <b>ROYALE</b></span></div><div class="header-tools"><button class="icon-button" data-action="help" aria-label="Spielanleitung">${icon("help")}</button><button class="icon-button" data-action="settings" aria-label="Einstellungen">${icon("settings")}</button></div></div><div class="wallet"><div class="currency gold">${icon("coin")}<strong>${number(profile?.gold)}</strong><span>Gold</span></div><div class="currency gems">${icon("gem")}<strong>${number(profile?.gems)}</strong><span>Mondsteine</span></div><div class="currency trophies">${icon("trophy")}<strong>${number(profile?.trophies)}</strong><span>Trophäen</span></div></div></header>`;
}
function nav() {
  return `<nav class="bottom-nav" aria-label="Hauptnavigation">${[
    ["home", "home", "Start"],
    ["deck", "cards", "Deck"],
    ["shop", "shop", "Shop"],
    ["chests", "chest", "Truhen"],
    ["arenas", "arena", "Arenen"],
    ["leaderboard", "trophy", "Rangliste"],
  ]
    .map(
      ([id, symbol, label]) =>
        `<button class="nav-item ${ui.tab === id ? "active" : ""}" data-action="tab" data-tab="${id}" aria-label="${label}" ${ui.tab === id ? 'aria-current="page"' : ""}>${icon(symbol)}<span>${label}</span></button>`,
    )
    .join("")}</nav>`;
}
function home() {
  const arena=catalog.ARENAS.find(a=>a.id===ui.profile.arena)||catalog.ARENAS[0];
  const next=catalog.ARENAS.find(a=>a.trophies>ui.profile.trophies);
  return `<div class="home-profile"><div class="crest" aria-hidden="true">♞</div><div><div class="profile-name">${esc(ui.profile?.name || "Reisender")}</div><div class="profile-subtitle">Ein neues Kapitel beginnt</div></div><div class="level-badge"><span>LEVEL</span><b>${number(ui.profile?.level || 1)}</b></div></div>
  <section class="hero" aria-label="Dein Weg zur Krone"><img src="/art/war-room-fortress.jpg" alt="Eine mittelalterliche Festung im Fackelschein, umgeben von nächtlichem Nebel" fetchpriority="high"><div class="hero-top">DEIN WEG ZUR KRONE</div><div class="hero-caption"><div class="overline">${esc(arena.name.toUpperCase())}</div><h1>Jeder Zug.<br>Ein neues Königreich.</h1><p>Schach. Magie. Dein Vermächtnis.</p></div><div class="hero-number" aria-label="Arena ${catalog.ARENAS.indexOf(arena) + 1}">${["I", "II", "III", "IV", "V", "VI", "VII", "VIII"][catalog.ARENAS.indexOf(arena)]}</div></section>
  <div class="trophy-progress"><span>${number(ui.profile.trophies)} Trophäen</span><span>${next?`${number(next.trophies)} · ${esc(next.name)}`:"Alle Arenen entdeckt"}</span><progress max="${next?.trophies||1}" value="${next?ui.profile.trophies:1}" aria-label="Fortschritt zur nächsten Arena"></progress></div><div class="home-content"><div class="section-heading"><h2>Bereit für deinen Zug?</h2><span>Training</span></div><div class="training-card"><div class="mode-switch" aria-label="Spielmodus"><button data-action="mode" data-value="classic" class="${ui.mode === "classic" ? "active" : ""}" aria-pressed="${ui.mode === "classic"}">${icon("crown")}Klassisch</button><button data-action="mode" data-value="fantasy" class="${ui.mode === "fantasy" ? "active" : ""}" aria-pressed="${ui.mode === "fantasy"}">${icon("wand")}Fantasy</button></div><p class="mode-note">${ui.mode === "fantasy" ? "Dein Deck, Mana & Magie auf dem Schachbrett." : "Das zeitlose Spiel. Nur du und dein nächster Zug."}</p><div class="difficulty" aria-label="Schwierigkeitsgrad">${Object.entries(
    difficulties,
  )
    .map(
      ([key, label], index) =>
        `<button data-action="difficulty" data-value="${key}" class="${ui.difficulty === key ? "active" : ""}" aria-pressed="${ui.difficulty === key}"><span class="difficulty-stars" aria-hidden="true">${"★".repeat(index + 1)}</span>${label}</button>`,
    )
    .join(
      "",
    )}</div></div><button class="primary-button battle-button" data-action="battle" ${ui.busy ? "disabled" : ""}>${ui.busy ? '<span class="busy-dot"></span> Die Figuren nehmen Platz …' : `${icon("sword")}Schlacht starten<span class="arrow">${icon("arrow")}</span>`}</button><p class="cta-caption">GEGEN KI · OHNE ZEITDRUCK · DEIN TEMPO</p>${ui.savedMatchId ? '<button class="secondary-button" style="width:100%;margin-top:15px" data-action="resume">Laufende Partie fortsetzen</button>' : ""}<button class="secondary-button online-entry" data-action="online-open">⚔ Duellhalle · Gemeinsam spielen</button>${polish.home()}<div class="home-footer-note">${icon("leaf")}Ein guter Plan beginnt mit einem kleinen Zug.</div></div>`;
}
const roleEnglish = { k: "King", q: "Queen", r: "Rook", b: "Bishop", n: "Knight", p: "Pawn" };
const roleArt = (role) => `<span class="role-art art-${role}" aria-hidden="true"></span>`;
function deck() {
  const currentDeck = profileDeck();
  const selected = pieceById(currentDeck[ui.role]);
  const owned = (id) => Boolean(ui.profile?.collection?.[id]);
  const items = [...PIECES, ...SPELLS].filter((card) =>
    (ui.collectionFilter === "all" || card.role === ui.collectionFilter) &&
    (!ui.collectionOwned || owned(card.id))
  );
  const ranks = [Array(8).fill("p"), ["r", "n", "b", "q", "k", "b", "n", "r"]];
  return `<div class="page-content war-deck">
    <div class="overline muted">DER KRIEGSRAT</div><h1 class="page-title">Deine Aufstellung</h1>
    <p class="deck-intro">Sechs Rollen. Ein Plan. Dein Königreich.</p>
    <section class="formation-panel" aria-label="Deine Startaufstellung">
      <div class="formation-heading"><span class="section-label">DIE ERSTEN REIHEN</span><span>16 Figuren</span></div>
      <div class="formation-board" role="group" aria-label="Eigene zwei Schachreihen; Figur auswählen">${ranks.map((rank, row) => rank.map((role, col) => {
        const piece = pieceById(currentDeck[role]);
        return `<button class="formation-slot ${(row + col) % 2 ? "slate" : "oak"} ${ui.role === role ? "active" : ""}" data-action="role" data-role="${role}" data-position="${col}-${row}" aria-pressed="${ui.role === role}" aria-label="${String.fromCharCode(97 + col)}${2 - row}: ${roleNames[role]}, ${esc(piece?.name)}">${roleArt(role)}<span class="formation-glyph" aria-hidden="true">${glyphs[role]}</span></button>`;
      }).join("")).join("")}</div>
      <div class="formation-caption"><span>${glyphs[ui.role]} ${esc(selected?.name || roleNames[ui.role])}</span><small>Figur antippen · Varianten wählen</small></div>
    </section>
    <section class="deck-section equipped-section"><div class="section-heading"><h2>Dein Kartendeck</h2><span>6 Figuren · 3 Zauber</span></div>
      <div class="deck-grid">${roleOrder.map((role) => {
        const piece = pieceById(currentDeck[role]);
        return `<button class="piece-card ${ui.role === role ? "active" : ""}" data-action="role" data-role="${role}" data-rarity="${esc(piece?.rarity)}" aria-pressed="${ui.role === role}" aria-label="${roleNames[role]}: ${esc(piece?.name)}, ${piece?.mana || 0} Mana">
          ${roleArt(role)}<span class="mana-cost" title="Mana zum Beschwören">${number(piece?.mana)}</span><span class="card-role">${glyphs[role]} ${roleNames[role]}</span><span class="piece-card-name">${esc(piece?.name)}</span><span class="card-type">(${roleEnglish[role]})</span><span class="rarity-line"></span></button>`;
      }).join("")}</div>
      <div class="deck-spells">${profileSpells().map((id, index) => {
        const spell = spellById(id);
        return `<button class="spell-card" data-action="edit-spell" data-index="${index}" aria-label="${esc(spell?.name || "Zauber")} austauschen"><span class="mana-cost" title="Manakosten">${number(spell?.mana)}</span><span class="spell-symbol" aria-hidden="true">${spellSymbol(id)}</span><strong>${esc(spell?.name || "Zauber wählen")}</strong><small>ZAUBER ${index + 1} · ÄNDERN</small></button>`;
      }).join("")}</div>
      <div class="save-state" role="status">${ui.deckSaving ? '<span class="busy-dot"></span> Wird gespeichert …' : `${icon("check")}Aufstellung gespeichert`}</div>
    </section>
    <section class="deck-section collection-table"><div class="section-heading"><h2>Deine Sammlung</h2><span>${items.length} Varianten</span></div>
      <div class="collection-filters" role="group" aria-label="Nach Figurentyp filtern">${[["all", "Alle"], ["p", "Bauer"], ["n", "Springer"], ["b", "Läufer"], ["r", "Turm"], ["q", "Dame"], ["k", "König"], ["spell", "Zauber"]].map(([role, label]) => `<button data-action="collection-filter" data-value="${role}" aria-pressed="${ui.collectionFilter === role}" class="${ui.collectionFilter === role ? "active" : ""}">${label}</button>`).join("")}</div>
      <div class="collection-toolbar"><span>Im Training alle frei</span><button data-action="collection-owned" aria-pressed="${ui.collectionOwned}">${ui.collectionOwned ? "✓" : "◇"} Nur freigeschaltet</button></div>
      <div class="variants">${items.map((card) => {
        const spell = card.role === "spell";
        const equipped = spell ? profileSpells().includes(card.id) : currentDeck[card.role] === card.id;
        return `<button class="variant-card ${equipped ? "active" : ""}" data-action="${spell ? "equip-spell" : "variant"}" data-id="${esc(card.id)}" data-role="${card.role}" data-rarity="${card.rarity}" aria-pressed="${equipped}">
          <span class="variant-portrait">${spell ? `<span class="spell-symbol">${spellSymbol(card.id)}</span>` : roleArt(card.role)}<span class="mana-cost" title="Manakosten">${number(card.mana)}</span></span>
          <span class="variant-card-copy"><span class="variant-type">${spell ? "Zauber" : `${roleNames[card.role]} (${roleEnglish[card.role]})`} · ${catalog.RARITIES[card.rarity]?.name || ""}</span><strong>${esc(card.name)}</strong><span class="variant-description">${esc(card.description)}</span><span class="variant-ownership">${equipped ? "✓ Ausgerüstet" : owned(card.id) ? "Freigeschaltet · Ausrüsten" : "Im Training verfügbar"}</span></span></button>`;
      }).join("") || '<p class="collection-empty">Für diesen Typ ist noch keine Karte freigeschaltet. Im Training kannst du alle Varianten ausprobieren.</p>'}</div>
    </section>
    <button class="primary-button deck-ready" data-action="home">${icon("sword")}Bereit zur Schlacht ${icon("arrow")}</button>
  </div>`;
}

const comingCopy = {
  shop: {
    icon: "shop",
    title: "Der Marktplatz",
    description:
      "Neue Figuren und kleine Schätze finden bald ihren Weg in dein Königreich.",
  },
  chests: {
    icon: "chest",
    title: "Schätze warten",
    description:
      "Verdiene Truhen in deinen Schlachten und entdecke, was sich darin verbirgt.",
  },
  arenas: {
    icon: "arena",
    title: "Eine weite Welt",
    description:
      "Von der Holzhalle bis zur Drachenzitadelle. Jede Arena erzählt ihre eigene Geschichte.",
  },
  leaderboard: {
    icon: "trophy",
    title: "Ein Platz in der Geschichte",
    description:
      "Fordere andere Königreiche heraus und kämpfe um deinen Platz an der Spitze.",
  },
};
function coming() {
  const copy = comingCopy[ui.tab];
  return `<section class="coming-page"><div class="coming-art">${icon(copy.icon)}</div><span class="coming-pill">Das nächste Kapitel · Phase 2</span><h1>${copy.title}</h1><p>${copy.description}</p><button class="secondary-button" data-action="tab" data-tab="home">Im Training vorbereiten ${icon("arrow")}</button></section>`;
}
function game() {
  const state = ui.match.state;
  const color = ownColor();
  const opponent = color === "w" ? "b" : "w";
  const board = boardEntries();
  const targets = selectedActions().map((action) => action.to);
  const ranks =
    color === "w" ? [8, 7, 6, 5, 4, 3, 2, 1] : [1, 2, 3, 4, 5, 6, 7, 8];
  const files = color === "w" ? [..."abcdefgh"] : [..."hgfedcba"];
  const history = state.history || [];
  const last = history.at(-1)?.action || history.at(-1) || {};
  const fantasy = (state.mode || ui.mode) !== "classic";
  const hand =
    (Array.isArray(state.hand) ? state.hand : state.hand?.[color]) || [];
  const spells =
    (Array.isArray(state.spells) ? state.spells : state.spells?.[color]) ||
    profileSpells();
  const abilityAvailable =
    ui.selection?.from &&
    legalActions().some(
      (action) =>
        action.type === "ability" && action.from === ui.selection.from,
    );
  let status = state.result
    ? "Die Partie ist beendet."
    : ui.busy || !ownTurn()
      ? "Dein Gegenüber denkt nach …"
      : state.check
        ? "Schach! Bring deinen König in Sicherheit."
        : "Du bist am Zug. Wähle eine Figur.";
  if (ui.selection && !ui.busy)
    status =
      ui.selection.type === "summon"
        ? "Wähle ein markiertes Feld zum Beschwören."
        : ui.selection.type === "spell"
          ? "Wähle das Ziel für deinen Zauber."
          : ui.selection.type === "ability"
            ? "Wähle ein Ziel für die Fähigkeit."
            : "Tippe auf ein markiertes Zielfeld.";
  return `<header class="game-header"><button class="icon-button" data-action="leave-game" aria-label="Zum Startbildschirm">${icon("back")}</button><div class="game-heading"><h2>${fantasy ? "Schach & Magie" : "Das königliche Spiel"}</h2><p>${ui.replay ? "Replay" : ui.match.mode === "training" ? "Training" : ui.match.color === null ? "Zuschauer" : "Duell"} · ${difficulties[state.difficulty || ui.difficulty] || "Mittel"} · ${esc(catalog.ARENAS.find((a) => a.id === state.arena)?.name || "Holzhalle")}</p></div><button class="icon-button" data-action="help" aria-label="Spielanleitung">${icon("help")}</button></header>
  ${online.controls()}<div class="screen game-screen">${polish.guide()}<div class="player-bar"><div class="player-avatar enemy" aria-hidden="true">♞</div><div class="player-info"><strong>${esc(ui.match.players?.[opponent]?.name || state.opponent?.name || "Der Hofstratege")}</strong><span>${ui.match.mode === "training" ? `KI · ${difficulties[state.difficulty || ui.difficulty] || "Mittel"}` : "Ein würdiger Gegner"}</span></div>${fantasy ? manaDisplay(opponent) : '<span class="turn-badge">SCHWARZ</span>'}</div>
  <div class="board-wrap"><div class="chess-board" role="group" aria-label="Schachbrett">${ranks
    .map((rank, row) =>
      files
        .map((file, col) => {
          const square = `${file}${rank}`;
          const piece = board.find((item) => item.square === square);
          const dark = (file.charCodeAt(0) - 97 + rank) % 2 === 1;
          const terrain = (state.terrain || []).find(
            (t) => t.square === square,
          );
          const checked =
            state.check && state.turn === piece?.color && piece?.type === "k";
          const effects = Array.isArray(piece?.effects)
            ? piece.effects
            : Object.keys(piece?.effects || {});
          const effectNames = effects
            .map((effect) =>
              typeof effect === "string"
                ? effect
                : effect.kind || effect.type || effect.id,
            )
            .join(" ");
          return `<button class="square ${dark ? "dark" : ""} ${piece ? "occupied" : ""} ${targets.includes(square) ? "legal" : ""} ${ui.selection?.from === square ? "selected" : ""} ${[last.from, last.to].includes(square) ? "last" : ""} ${checked ? "checked" : ""}" data-terrain="${terrain?.kind || ""}" data-warning="${terrain?.starts > state.ply}" data-action="square" data-square="${square}" aria-label="${square}${piece ? `, ${piece.color === "w" ? "weißer" : "schwarzer"} ${roleNames[piece.type] || piece.type}${piece.variantId ? `, ${pieceById(piece.variantId)?.name || ""}` : ""}` : ", leer"}${targets.includes(square) ? ", mögliches Ziel" : ""}">${col === 0 ? `<span class="coordinate rank">${rank}</span>` : ""}${row === 7 ? `<span class="coordinate file">${file}</span>` : ""}${piece ? `<span class="piece-glyph ${piece.color === "w" ? "white" : "black"}" aria-hidden="true">${glyphs[piece.type] || "♟"}</span>${fantasy && piece.variantId && !/standard|classic|basic/.test(piece.variantId) ? '<span class="variant-dot"></span>' : ""}${effects.length ? `<span class="piece-effect" title="${esc(effectNames)}">${/frozen|freeze|ice/.test(effectNames) ? "❄" : /shield/.test(effectNames) ? "◇" : "✦"}</span>` : ""}` : ""}</button>`;
        })
        .join(""),
    )
    .join("")}</div></div>
  <div class="player-bar own-bar"><div class="player-avatar" aria-hidden="true">♜</div><div class="player-info"><strong>${esc(ui.profile?.name || "Du")}</strong><span>${color === "w" ? "Weiß" : "Schwarz"} · Dein Königreich</span></div>${fantasy ? manaDisplay(color) : `<span class="turn-badge">${ownTurn() ? "DEIN ZUG" : "KI AM ZUG"}</span>`}</div>
  ${state.arenaNotice ? `<div class="arena-notice">${esc(state.arenaNotice)}</div>` : ""}<div class="game-status ${ui.busy ? "thinking" : state.check ? "check" : ""}" role="status">${ui.busy ? '<span class="busy-dot"></span>' : icon(state.check ? "crown" : "leaf")}${status}</div>
  ${
    fantasy
      ? `<div class="game-actions"><span class="section-label">Deine Verstärkung</span>${abilityAvailable ? `<button class="ability-button ${ui.selection.type === "ability" ? "active" : ""}" data-action="ability">${ui.selection.type === "ability" ? "Normal ziehen" : "Fähigkeit nutzen"}</button>` : `<button class="text-button" data-action="summon-help">So funktioniert’s</button>`}</div><div class="hand">${[
          0, 1, 2,
        ]
          .map((index) => {
            const card = hand[index];
            const id =
              typeof card === "object"
                ? card?.cardId || card?.id || card?.variantId
                : card;
            if (!id)
              return '<div class="hand-card empty"><span>✧</span>Kein Nachschub</div>';
            const piece = pieceById(id);
            const legal = legalActions().some(
              (action) =>
                action.type === "summon" &&
                (action.cardId === id || action.variantId === id),
            );
            return `<button class="hand-card ${ui.selection?.cardId === id ? "active" : ""}" data-action="summon" data-id="${esc(id)}" ${!legal || ui.busy ? "disabled" : ""} aria-label="${esc(piece?.name || id)} beschwören, ${piece?.mana || 0} Mana"><span class="mana-cost">${number(piece?.mana)}</span><span class="piece-glyph" aria-hidden="true">${glyphs[piece?.role] || "♟"}</span><strong>${esc(piece?.name || id)}</strong></button>`;
          })
          .join("")}</div><div class="game-spells">${spells
          .map((value) => {
            const id =
              typeof value === "object" ? value.id || value.spellId : value;
            const spell = spellById(id);
            const legal = legalActions().some(
              (action) => action.type === "spell" && action.spellId === id,
            );
            const cooldowns = state.cooldowns?.[color] || state.cooldowns || {};
            const cooldown = Number(
              value?.remainingCooldown ??
                value?.cooldownRemaining ??
                Math.max(
                  0,
                  (cooldowns[id] || 0) - (state.ownTurns?.[color] || 0),
                ),
            );
            return `<button class="spell-card ${ui.selection?.spellId === id ? "active" : ""}" data-action="cast" data-id="${esc(id)}" ${!legal || ui.busy ? "disabled" : ""} aria-label="${esc(spell?.name || id)} zaubern, ${spell?.mana || 0} Mana"><span class="mana-cost">${number(spell?.mana)}</span><span class="spell-symbol" aria-hidden="true">${spellSymbol(id)}</span><strong>${esc(spell?.name || id)}</strong>${cooldown > 0 ? `<span class="cooldown-label">${cooldown} Züge Pause</span>` : ""}</button>`;
          })
          .join("")}</div>`
      : `<p class="game-tip"><strong>Ein Feld nach dem anderen.</strong><br>Wähle eine Figur, um ihre legalen Züge zu sehen.<br>Rochade, en passant und Umwandlung sind dabei.</p>`
  }
  ${state.enemyHand ? `<aside class="spy-intel">Spionage · Hand: ${state.enemyHand.map((id) => esc(pieceById(id)?.name || id)).join(", ")}<br>Zauber: ${(state.enemySpells || []).map((id) => esc(spellById(id)?.name || id)).join(", ")}</aside>` : ""}<div class="game-tools"><button class="text-button" data-action="history">${icon("history")}Zugverlauf</button><button class="text-button" data-action="resign" ${state.result ? "disabled" : ""}>${icon("flag")}Aufgeben</button>${isLocal ? `<button class="text-button" data-action="dev">${icon("bug")}Dev</button>` : ""}</div>${ui.historyOpen ? `<div class="history"><span class="section-label">Die Geschichte deiner Partie</span>${history.length ? `<ol>${history.map((move) => `<li>${esc(typeof move === "string" ? move : move.san || move.label || move.notation || `${move.action?.from || move.from || ""} → ${move.action?.to || move.to || move.type || ""}`)}</li>`).join("")}</ol>` : "<p>Noch kein Zug. Deine Geschichte beginnt jetzt.</p>"}</div>` : ""}</div>`;
}
function modal() {
  const current = ui.modal;
  if (!current) return "";
  let title = "";
  let content = "";
  let extraClass = "";
  if (current.type === "treasure") {
    title = "Dein Fund";
    content = progress.modal();
  } else if (current.type === "settings") {
    title = "Dein Königreich";
    content = polish.settings();
  } else if (current.type === "help" || current.type === "summon-help") {
    title =
      current.type === "help"
        ? "Ein königlicher Einstieg"
        : "Verstärkung & Magie";
    content = `<p class="modal-copy">Klassisches Schach trifft auf neue Möglichkeiten. Dein Ziel bleibt: Setze den gegnerischen König schachmatt.</p><ol class="guide-list"><li><span>01</span><div><strong>Tippen, planen, ziehen.</strong><br>Wähle eine Figur. Die Punkte zeigen legale Zielfelder. Ein zweiter Tipp führt den Zug aus.</div></li><li><span>02</span><div><strong>Mana ist deine Ressource.</strong><br>Im Fantasy-Modus bekommst du pro Zug Mana. Spare es für Verstärkung, Zauber und Fähigkeiten.</div></li><li><span>03</span><div><strong>Dein Deck macht den Unterschied.</strong><br>Wähle Varianten im Deck. Tippe in der Partie auf eine Handkarte und dann auf ein markiertes Feld.</div></li><li><span>04</span><div><strong>Magie braucht ein Ziel.</strong><br>Wähle einen verfügbaren Zauber und sein Zielfeld. Besondere Figuren zeigen beim Auswählen ihre Fähigkeit.</div></li><li><span>05</span><div><strong>Der König hat Vorrang.</strong><br>Auch Magie darf deinen eigenen König nicht im Schach lassen. Im klassischen Modus gelten die üblichen Schachregeln.</div></li></ol>`;
  } else if (current.type === "equip-spell") {
    const spell = spellById(current.id);
    title = `${esc(spell?.name)} ausrüsten`;
    content = `<p class="modal-copy">Welchen Zauberplatz möchtest du ersetzen?</p>${profileSpells().map((id, index) => `<button class="spell-option" data-action="choose-spell" data-id="${esc(current.id)}" data-index="${index}"><span class="spell-symbol">${spellSymbol(id)}</span><span><strong>Platz ${index + 1} · ${esc(spellById(id)?.name)}</strong></span>${icon("arrow")}</button>`).join("")}`;
  } else if (current.type === "edit-spell") {
    title = `Zauberplatz ${current.index + 1}`;
    content = `<p class="modal-copy">Wähle die Magie, die zu deinem Spiel passt.</p>${SPELLS.map((spell) => `<button class="spell-option ${profileSpells()[current.index] === spell.id ? "active" : ""}" data-action="choose-spell" data-id="${esc(spell.id)}" data-index="${current.index}"><span class="spell-symbol">${spellSymbol(spell.id)}</span><div><strong>${esc(spell.name)}</strong><p>${esc(spell.description || spell.effect?.description || spell.effect || "")}${spell.cooldown ? ` · ${spell.cooldown} Züge Abklingzeit` : ""}</p></div><span class="mana-cost">${number(spell.mana)}</span></button>`).join("")}`;
  } else if (current.type === "promotion") {
    title = "Eine neue Bestimmung";
    content = `<p class="modal-copy">Dein Bauer hat die letzte Reihe erreicht. In welche Figur soll er sich verwandeln?</p><div class="promotion-grid">${current.actions.map((action, index) => `<button data-action="promote" data-index="${index}"><span class="piece-glyph">${glyphs[action.promotion]}</span>${roleNames[action.promotion]}</button>`).join("")}</div>`;
  } else if (current.type === "resign") {
    title = "Die Fahne senken?";
    content =
      '<p class="modal-copy">Du gibst diese Partie auf. Dein Deck wartet bereits auf die nächste Herausforderung.</p><div class="modal-actions"><button class="secondary-button" data-action="close-modal">Weiterspielen</button><button class="primary-button" data-action="confirm-resign">Aufgeben</button></div>';
  } else if (current.type === "leave-game") {
    title = "Eine kleine Pause";
    content =
      '<p class="modal-copy">Deine Partie bleibt gespeichert. Du kannst sie auf der Startseite jederzeit fortsetzen.</p><div class="modal-actions"><button class="secondary-button" data-action="close-modal">Weiterspielen</button><button class="primary-button" data-action="home">Zur Startseite</button></div>';
  } else if (current.type === "dev") {
    title = "Entwicklerwerkzeuge";
    content = `<p class="modal-copy">Nur lokal verfügbar. Die Änderungen werden serverseitig geprüft und im aktuellen Profil gespeichert.</p><div class="dev-grid"><button class="secondary-button" data-action="dev-value" data-kind="gold" data-value="1000">${icon("coin")}+1.000 Gold</button><button class="secondary-button" data-action="dev-value" data-kind="gems" data-value="100">${icon("gem")}+100 Mondsteine</button><button class="secondary-button" data-action="dev-value" data-kind="trophies" data-value="50">${icon("trophy")}Trophäen: 50 setzen</button><button class="secondary-button" data-action="dev-value" data-kind="mana" data-value="2" ${!ui.match ? "disabled" : ""}>${icon("wand")}Mana füllen</button><button class="secondary-button" data-action="dev-value" data-kind="open-chest">Truhe bereitstellen</button><button class="secondary-button" data-action="dev-value" data-kind="pity">Pity anzeigen</button><button class="secondary-button" data-action="dev-trophies">Trophäen setzen …</button></div><p class="fine-print">Pity: ${esc(JSON.stringify(ui.profile?.pity || {}))}</p>`;
  } else if (current.type === "result") {
    const result = ui.match?.state?.result || {};
    const winner = result.winner;
    const draw =
      result.draw ||
      winner === null ||
      winner === "draw" ||
      result.type === "draw";
    const learned = ui.match?.tutorial?.goalReached;
    const win = winner === ownColor();
    extraClass = "result-sheet";
    const reasons = {
      timeout: "Die Bedenkzeit ist abgelaufen.",
      "threefold-repetition": "Remis durch dreifache Stellungswiederholung.",
      "insufficient-material": "Remis wegen unzureichenden Materials.",
      "fifty-move": "Remis nach der 50-Züge-Regel.",
      checkmate: "Schachmatt. Der letzte Zug gehört dir.",
      stalemate: "Patt. Kein legaler Zug mehr möglich.",
      resignation: "Die Partie wurde durch Aufgabe beendet.",
      resign: "Die Partie wurde durch Aufgabe beendet.",
      repetition: "Remis durch Stellungswiederholung.",
      insufficient: "Nicht genug Material für ein Schachmatt.",
      fifty_move: "Remis nach der 50-Züge-Regel.",
    };
    content = `<div class="result-emblem" aria-hidden="true">${draw ? "♔" : win ? "♛" : "♚"}</div><div class="overline muted">TRAINING ABGESCHLOSSEN</div><h2>${learned ? "Die Lektion ist geschafft" : draw ? "Ein würdiges Remis" : win ? "Dein Königreich triumphiert" : "Jeder Zug lehrt etwas"}</h2><p>${esc(reasons[result.reason] || result.message || (draw ? "Eine ausgeglichene Begegnung." : win ? "Gut geplant. Klug gespielt. Verdient gewonnen." : "Dein nächster Plan wartet schon auf dich."))}</p><div class="result-details"><div><strong>${number(ui.match?.state?.history?.length || 0)}</strong>Halbzüge</div><div><strong>${difficulties[ui.difficulty]}</strong>Gegner</div><div><strong>${ui.mode === "classic" ? "♜" : "✦"}</strong>${ui.mode === "classic" ? "Klassisch" : "Fantasy"}</div></div><button class="primary-button" data-action="rematch">Noch eine Partie ${icon("arrow")}</button><button class="text-button" style="margin-top:10px" data-action="home">Zurück ins Königreich</button>`;
  }
  return `<div class="modal-backdrop" data-action="backdrop"><section class="modal-sheet ${extraClass}" role="dialog" aria-modal="true" aria-label="${esc(title || "Partieergebnis")}"><div class="modal-grip"></div>${title ? `<div class="modal-top"><h2>${title}</h2><button class="icon-button" data-action="close-modal" aria-label="Schließen">${icon("close")}</button></div>` : ""}${content}</section></div>`;
}
function render() {
  if (!app) return;
  const previousScroll = app.querySelector(".screen")?.scrollTop || 0;
  const focused = document.activeElement;
  const focusSelector = app.contains(focused) && focused?.dataset.action
    ? Object.entries(focused.dataset).map(([key, value]) => `[data-${key.replace(/[A-Z]/g, c => `-${c.toLowerCase()}`)}="${CSS.escape(value)}"]`).join("")
    : null;
  if (ui.bootError && !ui.profile) {
    app.innerHTML = `<div class="error-screen"><div class="coming-art">${icon("arena")}</div><h1>Das Tor öffnet sich gleich.</h1><p>${esc(ui.bootError)}</p><button class="primary-button" data-action="retry">Erneut versuchen</button></div>`;
    return;
  }
  if (!ui.profile) return;
  const network =
    ui.network === "offline" || !navigator.onLine
      ? '<div class="network-banner" role="status">Du bist offline. Deine Partie bleibt erhalten.</div>'
      : ui.network === "slow"
        ? '<div class="network-banner" role="status">Langsame Verbindung · Deine Züge brauchen etwas länger.</div>'
        : "";
  app.innerHTML = `${network}${ui.match && ui.tab === "game" ? game() : `${header()}<div class="screen">${ui.tab === "home" ? home() : ui.tab === "deck" ? deck() : (progress.page(ui.tab) ?? online.page(ui.tab) ?? coming())}</div>${nav()}`}${modal()}${ui.toast ? `<div class="toast ${ui.toastError ? "error" : ""}" role="status">${esc(ui.toast)}</div>` : ""}`;
  const screen = app.querySelector(".screen");
  if (screen) screen.scrollTop = previousScroll;
  polish.apply();
  if (focusSelector) app.querySelector(focusSelector)?.focus({ preventScroll: true });
}

function setTab(tab) {
  if (tab === "leaderboard") online.load();
  if (["shop", "chests", "arenas"].includes(tab)) progress.load();
  ui.tab = tab;
  ui.modal = null;
  ui.selection = null;
  render();
  app.querySelector(".screen")?.scrollTo(0, 0);
}
async function initialize() {
  ui.bootError = "";
  try {
    const result = await request(
      "/api/guest",
      ui.token ? { token: ui.token } : {},
    );
    ui.token = result.token || ui.token;
    ui.profile = result.profile;
    if (!ui.profile) throw new Error("Das Profil konnte nicht geladen werden.");
    await progress.load(false);
    persist();
    render();
  } catch (error) {
    ui.bootError = error.message;
    render();
  }
}
async function startMatch() {
  if (ui.busy) return;
  ui.busy = true;
  ui.modal = null;
  render();
  try {
    await savingDeck;
    const result = await request("/api/training", {
      difficulty: ui.difficulty,
      mode: ui.mode,
      arena: ui.arena,
      tutorial: Boolean(ui.tutorialRequested),
    });
    ui.tutorialRequested = false;
    ui.match = result;
    ui.savedMatchId = result.matchId;
    ui.selection = null;
    ui.resultShown = "";
    ui.historyOpen = false;
    ui.tab = "game";
    persist();
    sound("move");
  } catch (error) {
    toast(error.message, true);
  } finally {
    ui.busy = false;
    render();
    app.querySelector(".screen")?.scrollTo(0, 0);
  }
}
async function resumeMatch() {
  if (!ui.savedMatchId || ui.busy) return;
  ui.busy = true;
  render();
  try {
    const result = await request(
      `/api/match/${encodeURIComponent(ui.savedMatchId)}`,
    );
    ui.match = result;
    ui.mode = result.state.mode || ui.mode;
    ui.tab = "game";
    ui.selection = null;
    showResult();
  } catch (error) {
    toast(error.message, true);
  } finally {
    ui.busy = false;
    render();
  }
}
function showResult() {
  if (ui.match?.state?.result && ui.resultShown !== ui.match.matchId) {
    ui.resultShown = ui.match.matchId;
    ui.modal = { type: "result" };
    ui.savedMatchId = "";
    try {
      const cache = readStored();
      cache.matchId = "";
      localStorage.setItem(storageKey, JSON.stringify(cache));
    } catch {
      /* Optional persistence. */
    }
  }
}
async function performAction(action) {
  if (ui.busy || !ui.match || ui.replay || ui.match.color === null) return;
  if (ui.match.mode !== "training") return online.action(action);
  const capture =
    action.to &&
    boardEntries().some(
      (piece) => piece.square === action.to && piece.color !== ownColor(),
    );
  ui.busy = true;
  ui.modal = null;
  ui.selection = null;
  render();
  try {
    const result = await request(
      `/api/match/${encodeURIComponent(ui.match.matchId)}/action`,
      {
        action,
        version: ui.match.state.version,
        actionId:
          globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`,
      },
    );
    ui.match = { ...ui.match, ...result };
    sound(capture ? "capture" : "move");
    vibrate();
    persist();
    showResult();
    if (result.profile) ui.profile = result.profile;
  } catch (error) {
    toast(error.message, true);
  } finally {
    ui.busy = false;
    render();
    if (action.type === "spell" || action.type === "ability")
      requestAnimationFrame(() => runeEffect(action.spellId || "ability"));
  }
}
function selectSquare(square) {
  if (ui.busy || !ownTurn()) return;
  const available = selectedActions().filter((action) => action.to === square);
  if (available.length) {
    if (available.length > 1 && available.some((action) => action.promotion)) {
      ui.modal = { type: "promotion", actions: available };
      render();
    } else performAction(available[0]);
    return;
  }
  const piece = boardEntries().find(
    (item) => item.square === square && item.color === ownColor(),
  );
  if (piece) {
    ui.selection =
      ui.selection?.from === square ? null : { type: "move", from: square };
    sound();
    render();
  } else if (ui.selection) {
    ui.selection = null;
    render();
  }
}
function saveDeck(deck, spells) {
  const previous = { deck: { ...profileDeck() }, spells: [...profileSpells()] };
  ui.profile = { ...ui.profile, deck, spells };
  ui.deckSaving = true;
  render();
  savingDeck = savingDeck.then(async () => {
    try {
      const result = await request("/api/deck", { deck, spells });
      if (result.profile) ui.profile = result.profile;
    } catch (error) {
      ui.profile = { ...ui.profile, ...previous };
      toast(error.message, true);
    } finally {
      ui.deckSaving = false;
      render();
    }
  });
}
async function devAction(kind, value) {
  if (!isLocal) return;
  try {
    const result = await request("/api/dev", {
      action: kind,
      value: Number(value),
      matchId: ui.match?.matchId,
    });
    if (result.profile) ui.profile = result.profile;
    if (result.state && ui.match)
      ui.match = { ...ui.match, state: result.state };
    else if (kind === "mana" && ui.match) {
      const fresh = await request(
        `/api/match/${encodeURIComponent(ui.match.matchId)}`,
      );
      ui.match = { ...ui.match, ...fresh };
    }
    if (kind === "pity") toast("Pity: " + JSON.stringify(result.pity));
    else toast("Änderung gespeichert.");
  } catch (error) {
    toast(error.message, true);
  }
}
async function handleClick(event) {
  const button = event.target.closest("[data-action]");
  if (!button || button.disabled) return;
  const { action, value, id, index } = button.dataset;
  if (action.startsWith("pref-") || action.startsWith("tutorial-"))
    return polish.handle(action, button.dataset);
  if (action.startsWith("online-"))
    return online.handle(action, button.dataset);
  if (action.startsWith("progress-"))
    return progress.handle(action, button.dataset);
  if (action !== "square") sound();
  if (action === "backdrop") {
    if (event.target === button && ui.modal?.type !== "promotion") {
      ui.modal = null;
      render();
    }
    return;
  }
  if (action === "tab") return setTab(button.dataset.tab);
  if (action === "home") return setTab("home");
  if (action === "retry") return initialize();
  if (action === "mode") {
    ui.mode = value;
    persist();
    render();
    return;
  }
  if (action === "difficulty") {
    ui.difficulty = value;
    persist();
    render();
    return;
  }
  if (action === "battle" || action === "rematch") return startMatch();
  if (action === "resume") return resumeMatch();
  if (action === "square") return selectSquare(button.dataset.square);
  if (action === "role") {
    ui.role = button.dataset.role;
    ui.collectionFilter = ui.role;
    render();
    return;
  }
  if (action === "collection-filter") {
    ui.collectionFilter = value;
    render();
    return;
  }
  if (action === "collection-owned") {
    ui.collectionOwned = !ui.collectionOwned;
    render();
    return;
  }
  if (action === "equip-spell") {
    ui.modal = { type: "equip-spell", id };
    render();
    return;
  }
  if (action === "variant") {
    const piece = pieceById(id);
    if (!piece || ui.deckSaving) return;
    ui.role = piece.role;
    saveDeck({ ...profileDeck(), [piece.role]: id }, [...profileSpells()]);
    return;
  }
  if (action === "choose-spell") {
    const spells = [...profileSpells()];
    const existing = spells.indexOf(id);
    const old = spells[Number(index)];
    if (existing !== -1 && existing !== Number(index)) spells[existing] = old;
    spells[Number(index)] = id;
    ui.modal = null;
    saveDeck({ ...profileDeck() }, spells);
    return;
  }
  if (action === "summon" || action === "cast") {
    if (!ownTurn() || ui.busy) return;
    const same =
      action === "summon"
        ? ui.selection?.cardId === id
        : ui.selection?.spellId === id;
    ui.selection = same
      ? null
      : action === "summon"
        ? { type: "summon", cardId: id }
        : { type: "spell", spellId: id };
    const actions = selectedActions();
    if (actions.length === 1 && !actions[0].to)
      return performAction(actions[0]);
    render();
    return;
  }
  if (action === "ability") {
    if (ui.selection?.from)
      ui.selection.type = ui.selection.type === "ability" ? "move" : "ability";
    const actions = selectedActions();
    if (actions.length === 1 && !actions[0].to)
      return performAction(actions[0]);
    render();
    return;
  }
  if (action === "promote") {
    const move = ui.modal?.actions[Number(index)];
    if (move) performAction(move);
    return;
  }
  if (action === "history") {
    ui.historyOpen = !ui.historyOpen;
    render();
    if (ui.historyOpen)
      app
        .querySelector(".history")
        ?.scrollIntoView({ behavior: "smooth", block: "nearest" });
    return;
  }
  if (action === "close-modal") {
    ui.modal = null;
    render();
    return;
  }
  if (action === "toggle-sound") {
    ui.sound = !ui.sound;
    persist();
    render();
    return;
  }
  if (action === "toggle-vibration") {
    ui.vibration = !ui.vibration;
    persist();
    vibrate();
    render();
    return;
  }
  if (action === "confirm-resign") return performAction({ type: "resign" });
  if (action === "dev-trophies") {
    const value = prompt(
      "Trophäen setzen (0–100.000)",
      String(ui.profile.trophies),
    );
    if (value !== null) return devAction("trophies", Number(value));
    return;
  }
  if (action === "dev-value") return devAction(button.dataset.kind, value);
  if (
    [
      "settings",
      "help",
      "summon-help",
      "edit-spell",
      "resign",
      "leave-game",
      "dev",
    ].includes(action)
  ) {
    ui.modal = { type: action, index: Number(index) };
    render();
  }
}
function setNetwork(mode) {
  if (!["normal", "slow", "offline"].includes(mode)) return;
  ui.network = mode;
  online.setNetwork(mode);
  render();
}
async function initApp() {
  app = document.querySelector("#app");
  if (params.has("device")) document.body.classList.add("simulator-child");
  app.addEventListener("click", handleClick);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      ui.modal = null;
      ui.selection = null;
      render();
    }
  });
  window.addEventListener("online", render);
  window.addEventListener("offline", render);
  window.addEventListener("message", (event) => {
    if (event.origin === location.origin && event.data?.type === "network")
      setNetwork(event.data.mode);
  });
  window.chessRoyale = {
    reload: initialize,
    setNetwork,
    getState: () => ({ ...ui }),
    setDevAction: devAction,
  };
  await initialize();
  progress.startTimers();
  online.connect();
  if (
    "serviceWorker" in navigator &&
    (location.protocol === "https:" || isLocal)
  )
    navigator.serviceWorker.register("/sw.js").catch(() => {});
  window.dispatchEvent(new CustomEvent("chessroyale:ready"));
}

if (!(await startFrame())) await initApp();

function runeEffect(id) {
  const king = boardEntries().find(
    (p) => p.type === "k" && p.color === ownColor(),
  );
  const square =
    king && app.querySelector('[data-square="' + king.square + '"]');
  if (!square) return;
  const rune = document.createElement("span");
  rune.className = "rune-effect";
  rune.dataset.spell = id;
  rune.textContent = spellSymbol(id);
  rune.setAttribute("aria-hidden", "true");
  square.append(rune);
  setTimeout(() => rune.remove(), 1600);
}
