import { randomUUID, randomInt } from "node:crypto";
import { WebSocket } from "ws";
import { createGame, applyAction, publicState } from "./engine.js";
import {
  accountForToken,
  accountById,
  saveProfile,
  getMatch,
  saveMatch,
  listMatches,
  listProfiles,
  appendEvent,
  replayEvents,
  db,
} from "./store.js";
import { awardMatch, refreshProgress } from "./progression.js";
import { PIECES, SPELLS, BALANCE, ARENAS, EMOTES } from "../shared/catalog.js";
const assert = (ok, message) => {
  if (!ok) throw new Error(message);
};
const opposite = (c) => (c === "w" ? "b" : "w");
const code = () =>
  Array.from(
    { length: 6 },
    () => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[randomInt(31)],
  ).join("");
db.exec(
  "CREATE TABLE IF NOT EXISTS tournaments(id TEXT PRIMARY KEY,data TEXT NOT NULL)",
);
const saveTournament = (t) =>
  db
    .prepare(
      "INSERT INTO tournaments(id,data) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data",
    )
    .run(t.id, JSON.stringify(t));
export function createMultiplayer(wss) {
  const peers = new Set(),
    queue = new Map(),
    games = new Map(
      listMatches()
        .filter((m) => m.mode !== "training" && !m.closed && !m.state?.result)
        .map((m) => [m.id, m]),
    );
  const tournaments = new Map(
    db
      .prepare("SELECT data FROM tournaments")
      .all()
      .map((row) => {
        const t = JSON.parse(row.data);
        return [t.id, t];
      }),
  );
  const send = (ws, data) => {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data));
  };
  const allFor = (id, data) => {
    for (const ws of peers) if (ws.playerId === id) send(ws, data);
  };
  const get = (id) => games.get(id) || getMatch(id);
  function remaining(m, now = Date.now()) {
    if (!m.clock) return null;
    return {
      w: Math.max(
        0,
        m.clock.w -
          (m.state && !m.state.result && m.state.turn === "w"
            ? now - m.clock.lastAt
            : 0),
      ),
      b: Math.max(
        0,
        m.clock.b -
          (m.state && !m.state.result && m.state.turn === "b"
            ? now - m.clock.lastAt
            : 0),
      ),
      increment: m.clock.increment,
      serverTime: now,
    };
  }
  function view(m, id) {
    const color = m.players.w === id ? "w" : m.players.b === id ? "b" : null;
    return {
      matchId: m.id,
      code: m.code,
      mode: m.mode,
      color,
      state: m.state ? publicState(m.state, color) : null,
      clock: remaining(m),
      players: Object.fromEntries(
        Object.entries(m.players).map(([c, p]) => [
          c,
          p ? { id: p, name: accountById(p)?.name || "Wanderer" } : null,
        ]),
      ),
      tournamentId: m.tournamentId || null,
    };
  }
  function broadcast(m) {
    for (const ws of peers)
      if (
        Object.values(m.players).includes(ws.playerId) ||
        ws.watching === m.id
      )
        send(ws, { type: m.state ? "state" : "room", ...view(m, ws.playerId) });
  }
  function available(profile) {
    assert(
      ![...games.values()].some(
        (m) =>
          m.state &&
          !m.state.result &&
          Object.values(m.players).includes(profile.id),
      ),
      "Du hast bereits eine laufende Mehrspielerpartie.",
    );
  }
  function checkCollection(p) {
    for (const id of [...Object.values(p.deck), ...p.spells])
      assert(
        p.collection[id],
        `Die Karte ${(PIECES.find((c) => c.id === id) || SPELLS.find((c) => c.id === id))?.name || id} ist nur im Training verfügbar. Wähle für dieses Duell eine freigeschaltete Karte.`,
      );
  }
  function start(m) {
    const w = refreshProgress(accountById(m.players.w)),
      b = refreshProgress(accountById(m.players.b));
    let wd = w.deck,
      bd = b.deck,
      ws = w.spells,
      bs = b.spells;
    if (m.mode === "chaos") {
      wd = Object.fromEntries(
        ["k", "q", "r", "b", "n", "p"].map((role) => {
          const pool = PIECES.filter((p) => p.role === role);
          return [role, pool[randomInt(pool.length)].id];
        }),
      );
      bd = { ...wd };
      ws = [...SPELLS]
        .sort(() => randomInt(3) - 1)
        .slice(0, 3)
        .map((s) => s.id);
      bs = [...ws];
    } else {
      checkCollection(w);
      checkCollection(b);
    }
    const min = Math.min(w.trophies, b.trophies),
      arena = ARENAS.filter((a) => a.trophies <= min).at(-1).id;
    m.state = createGame({
      deckWhite: wd,
      deckBlack: bd,
      spellsWhite: ws,
      spellsBlack: bs,
      mode: "fantasy",
      arena,
      levelsWhite: m.mode === "chaos" ? {} : w.collection,
      levelsBlack: m.mode === "chaos" ? {} : b.collection,
    });
    m.initialState = structuredClone(m.state);
    m.rulesVersion = 1;
    m.clock = {
      w: BALANCE.clockSeconds * 1000,
      b: BALANCE.clockSeconds * 1000,
      increment: BALANCE.incrementSeconds * 1000,
      lastAt: Date.now(),
    };
    m.requestIds = [];
    queue.delete(w.id);
    queue.delete(b.id);
    for (const old of games.values())
      if (
        old.id !== m.id &&
        !old.state &&
        [w.id, b.id].includes(old.players.w)
      ) {
        old.closed = true;
        saveMatch(old);
        games.delete(old.id);
      }
    games.set(m.id, m);
    saveMatch(m);
    broadcast(m);
    return m;
  }
  function newMatch(w, b, mode = "friendly", extra = {}) {
    return start({
      id: randomUUID(),
      code: code(),
      mode,
      players: { w, b },
      createdAt: Date.now(),
      ...extra,
    });
  }
  function tournamentView(t) {
    return {
      ...t,
      participants: t.participants.map((id) => ({
        id,
        name: accountById(id)?.name || "Wanderer",
      })),
      bracket: t.matches.map((id) => {
        const m = get(id);
        return {
          id,
          players: Object.values(m.players).map((p) => ({
            id: p,
            name: accountById(p)?.name || "Wanderer",
          })),
          result: m.state?.result,
          code: m.code,
        };
      }),
    };
  }
  function announceTournament(t) {
    saveTournament(t);
    const info = { type: "tournament", tournament: tournamentView(t) };
    for (const id of t.participants) allFor(id, info);
  }
  function advanceTournament(m) {
    const t = tournaments.get(m.tournamentId);
    if (!t) return;
    const winnerId = m.players[m.state.result.winner || "w"];
    t.winners ??= {};
    t.winners[m.id] = winnerId;
    if (t.matches.length === 2 && t.matches.every((id) => t.winners[id])) {
      const final = newMatch(
        t.winners[t.matches[0]],
        t.winners[t.matches[1]],
        "tournament",
        { tournamentId: t.id },
      );
      t.matches.push(final.id);
      t.round = "final";
    } else if (t.matches.length === 3 && t.winners[t.matches[2]]) {
      t.champion = t.winners[t.matches[2]];
      t.status = "complete";
      t.round = "complete";
      const p = accountById(t.champion);
      p.gold += 500;
      saveProfile(p);
    }
    announceTournament(t);
  }
  function finish(m) {
    if (!m.state?.result || m.rewarded) return;
    const w = accountById(m.players.w),
      b = accountById(m.players.b);
    m.rewarded = true;
    for (const [p, c] of [
      [w, "w"],
      [b, "b"],
    ]) {
      awardMatch(p, m.state.result.winner, c);
    }
    if (m.mode === "ranked") {
      w.stats.rankedMatches = (w.stats.rankedMatches || 0) + 1;
      b.stats.rankedMatches = (b.stats.rankedMatches || 0) + 1;
      const expected = 1 / (1 + 10 ** ((b.elo - w.elo) / 400)),
        score =
          m.state.result.winner === null
            ? 0.5
            : m.state.result.winner === "w"
              ? 1
              : 0,
        delta = Math.round(32 * (score - expected));
      w.elo += delta;
      b.elo -= delta;
      if (m.state.result.winner) {
        const won = m.state.result.winner === "w" ? w : b,
          lost = won === w ? b : w;
        won.trophies += BALANCE.winTrophies;
        lost.trophies = Math.max(0, lost.trophies - BALANCE.lossTrophies);
      }
    }
    saveProfile(w);
    saveProfile(b);
    saveMatch(m);
    games.delete(m.id);
    broadcast(m);
    for (const p of [w, b]) allFor(p.id, { type: "profile", profile: p });
    if (m.tournamentId) advanceTournament(m);
  }
  function timeOut(m) {
    if (!m.state || m.state.result) return false;
    const left = remaining(m);
    if (left[m.state.turn] > 0) return false;
    m.state.result = { winner: opposite(m.state.turn), reason: "timeout" };
    m.state.version++;
    m.clock.w = left.w;
    m.clock.b = left.b;
    m.clock.lastAt = Date.now();
    finish(m);
    return true;
  }
  function action(ws, data) {
    const m = get(data.matchId);
    assert(m?.state, "Partie nicht gefunden.");
    const color =
      m.players.w === ws.playerId
        ? "w"
        : m.players.b === ws.playerId
          ? "b"
          : null;
    assert(color, "Zuschauer können keine Züge ausführen.");
    if (data.requestId && m.requestIds.includes(data.requestId)) {
      send(ws, {
        type: "state",
        ...view(m, ws.playerId),
        requestId: data.requestId,
      });
      return;
    }
    assert(!timeOut(m) && !m.state.result, "Die Partie ist bereits beendet.");
    assert(
      data.version === m.state.version,
      "Die Stellung hat sich geändert. Deine Partie wird synchronisiert.",
    );
    const left = remaining(m);
    let next;
    if (data.action?.type === "resign")
      next = {
        ...m.state,
        result: { winner: opposite(color), reason: "resignation" },
        version: m.state.version + 1,
      };
    else next = applyAction(m.state, data.action, color);
    m.clock.w = left.w;
    m.clock.b = left.b;
    if (data.action?.type !== "resign") m.clock[color] += m.clock.increment;
    m.clock.lastAt = Date.now();
    m.state = next;
    m.requestIds = [
      ...m.requestIds.slice(-99),
      String(data.requestId || randomUUID()).slice(0, 100),
    ];
    const p = accountById(ws.playerId);
    p.stats.moves++;
    if (data.action?.type === "summon") p.stats.summons++;
    if (data.action?.type === "spell") p.stats.spells++;
    saveProfile(p);
    appendEvent(m.id, {
      action: data.action,
      color,
      at: Date.now(),
      frame: publicState(m.state, null),
    });
    saveMatch(m);
    if (m.state.result) finish(m);
    else broadcast(m);
  }
  function handle(ws, data) {
    assert(data && typeof data.type === "string", "Ungültige Nachricht.");
    if (data.type === "auth") {
      const p = accountForToken(data.token);
      assert(p, "Gasttoken ist ungültig.");
      ws.playerId = p.id;
      send(ws, { type: "authenticated", profile: p });
      const active = [...games.values()].find((m) =>
        Object.values(m.players).includes(p.id),
      );
      if (active)
        send(ws, {
          type: active.state ? "state" : "room",
          ...view(active, p.id),
        });
      for (const t of tournaments.values())
        if (t.participants.includes(p.id) && t.status !== "complete")
          send(ws, { type: "tournament", tournament: tournamentView(t) });
      return;
    }
    assert(ws.playerId, "Bitte zuerst authentifizieren.");
    const p = refreshProgress(accountById(ws.playerId));
    if (data.type === "ping") {
      send(ws, { type: "pong", time: Date.now() });
      return;
    }
    if (data.type === "queue") {
      available(p);
      assert(["ranked", "chaos"].includes(data.mode), "Unbekannter Modus.");
      if (data.mode === "ranked") checkCollection(p);
      queue.set(p.id, {
        playerId: p.id,
        mode: data.mode,
        trophies: p.trophies,
        at: Date.now(),
      });
      send(ws, { type: "queued", mode: data.mode });
      pair();
      return;
    }
    if (data.type === "cancel-queue") {
      queue.delete(p.id);
      send(ws, { type: "queue-cancelled" });
      return;
    }
    if (data.type === "room-create") {
      available(p);
      checkCollection(p);
      const waiting = [...games.values()].find(
        (m) => !m.state && m.players.w === p.id,
      );
      if (waiting) {
        send(ws, { type: "room", ...view(waiting, p.id) });
        return;
      }
      const m = {
        id: randomUUID(),
        code: code(),
        mode: "friendly",
        players: { w: p.id, b: null },
        state: null,
        createdAt: Date.now(),
      };
      games.set(m.id, m);
      saveMatch(m);
      send(ws, { type: "room", ...view(m, p.id) });
      return;
    }
    if (data.type === "room-join") {
      available(p);
      checkCollection(p);
      const m = [...games.values()].find(
        (m) => m.code === String(data.code).toUpperCase(),
      );
      assert(m && !m.state && !m.players.b, "Dieser Raum ist nicht verfügbar.");
      assert(
        m.players.w !== p.id,
        "Öffne das zweite Handy für einen anderen Spieler.",
      );
      m.players.b = p.id;
      try {
        start(m);
      } catch (e) {
        m.players.b = null;
        throw e;
      }
      return;
    }
    if (data.type === "watch") {
      const m = [...games.values(), ...listMatches()].find(
        (m) => m.code === String(data.code).toUpperCase(),
      );
      assert(m?.state, "Diese Partie ist nicht verfügbar.");
      ws.watching = m.id;
      send(ws, { type: "state", ...view(m, p.id) });
      return;
    }
    if (data.type === "resume") {
      const m = get(data.matchId);
      assert(m?.state, "Partie nicht gefunden.");
      assert(
        Object.values(m.players).includes(p.id) || ws.watching === m.id,
        "Kein Zugriff auf diese Partie.",
      );
      timeOut(m);
      send(ws, { type: "state", ...view(m, p.id) });
      return;
    }
    if (data.type === "action") {
      action(ws, data);
      return;
    }
    if (data.type === "emote") {
      const m = get(data.matchId);
      assert(
        m && Object.values(m.players).includes(p.id),
        "Keine eigene Partie.",
      );
      assert(EMOTES.includes(data.text), "Unbekannte Grußformel.");
      assert(
        Date.now() - (ws.lastEmote || 0) > 2500,
        "Einen Augenblick zwischen Grußformeln warten.",
      );
      ws.lastEmote = Date.now();
      for (const other of peers)
        if (
          Object.values(m.players).includes(other.playerId) ||
          other.watching === m.id
        )
          send(other, {
            type: "emote",
            matchId: m.id,
            name: p.name,
            text: data.text,
          });
      return;
    }
    if (data.type === "tournament-create") {
      available(p);
      checkCollection(p);
      const t = {
        id: randomUUID(),
        code: code(),
        participants: [p.id],
        status: "waiting",
        round: "semifinal",
        matches: [],
        createdAt: Date.now(),
      };
      tournaments.set(t.id, t);
      announceTournament(t);
      return;
    }
    if (data.type === "tournament-join") {
      available(p);
      checkCollection(p);
      const t = [...tournaments.values()].find(
        (t) => t.code === String(data.code).toUpperCase(),
      );
      assert(
        t?.status === "waiting" && t.participants.length < 4,
        "Dieses Turnier ist nicht verfügbar.",
      );
      assert(!t.participants.includes(p.id), "Du bist bereits angemeldet.");
      t.participants.push(p.id);
      if (t.participants.length === 4) {
        t.status = "playing";
        for (const pair of [
          [0, 1],
          [2, 3],
        ]) {
          const m = newMatch(
            t.participants[pair[0]],
            t.participants[pair[1]],
            "tournament",
            { tournamentId: t.id },
          );
          t.matches.push(m.id);
        }
      }
      announceTournament(t);
      return;
    }
    throw new Error("Unbekannte Echtzeit-Aktion.");
  }
  function pair() {
    const entries = [...queue.values()];
    for (let i = 0; i < entries.length; i++) {
      const a = entries[i];
      if (!queue.has(a.playerId)) continue;
      const b = entries
        .slice(i + 1)
        .find(
          (b) =>
            queue.has(b.playerId) &&
            b.mode === a.mode &&
            Math.abs(a.trophies - b.trophies) <=
              BALANCE.matchmakingRange +
                Math.floor((Date.now() - a.at) / 1000) * 10,
        );
      if (b) {
        queue.delete(a.playerId);
        queue.delete(b.playerId);
        try {
          newMatch(a.playerId, b.playerId, a.mode);
        } catch (e) {
          allFor(a.playerId, { type: "error", error: e.message });
          allFor(b.playerId, { type: "error", error: e.message });
        }
      }
    }
  }
  wss.on("connection", (ws) => {
    peers.add(ws);
    ws.count = 0;
    ws.window = Date.now();
    send(ws, { type: "hello", phase: 3 });
    const authTimer = setTimeout(() => {
      if (!ws.playerId) ws.close(1008, "Authentifizierung fehlt");
    }, 10000);
    authTimer.unref();
    ws.on("message", (raw) => {
      let data;
      try {
        if (Date.now() - ws.window > 10000) {
          ws.count = 0;
          ws.window = Date.now();
        }
        assert(++ws.count < 60, "Zu viele Nachrichten.");
        data = JSON.parse(raw);
        handle(ws, data);
      } catch (e) {
        send(ws, {
          type: "error",
          error: e.message,
          requestId: data?.requestId,
        });
        if (data?.matchId) {
          const m = get(data.matchId);
          if (m && Object.values(m.players).includes(ws.playerId))
            send(ws, { type: "state", ...view(m, ws.playerId) });
        }
      }
    });
    ws.on("close", () => {
      clearTimeout(authTimer);
      peers.delete(ws);
      if (![...peers].some((p) => p.playerId === ws.playerId))
        queue.delete(ws.playerId);
    });
  });
  const interval = setInterval(() => {
    for (const m of games.values()) {
      if (m.state && !timeOut(m))
        for (const ws of peers)
          if (
            Object.values(m.players).includes(ws.playerId) ||
            ws.watching === m.id
          )
            send(ws, { type: "clock", matchId: m.id, clock: remaining(m) });
    }
    pair();
  }, 1000);
  interval.unref();
  return {
    http(path, method, profile) {
      if (path === "/api/leaderboard")
        return {
          players: listProfiles()
            .filter((p) => p.id === profile.id || p.stats.rankedMatches > 0)
            .map((p) => refreshProgress(p))
            .sort((a, b) => b.trophies - a.trophies || b.elo - a.elo)
            .slice(0, 100)
            .map((p, i) => ({
              rank: i + 1,
              id: p.id,
              name: p.name,
              trophies: p.trophies,
              elo: p.elo,
              wins: p.stats.wins,
            })),
        };
      if (path === "/api/replays")
        return {
          matches: listMatches()
            .filter(
              (m) => m.state && Object.values(m.players).includes(profile.id),
            )
            .slice(0, 30)
            .map((m) => ({
              id: m.id,
              mode: m.mode,
              result: m.state.result,
              createdAt: m.createdAt,
            })),
        };
      const replay = path.match(/^\/api\/replay\/([\w-]+)$/);
      if (replay) {
        const m = get(replay[1]);
        assert(m?.state, "Replay nicht gefunden.");
        const frames = [publicState(m.initialState, null)];
        let state = m.initialState;
        for (const e of replayEvents(m.id)) {
          if (e.frame) frames.push(e.frame);
          else {
            try {
              if (e.action?.type === "resign")
                state = {
                  ...state,
                  result: { winner: opposite(e.color), reason: "resignation" },
                };
              else state = applyAction(state, e.action, e.color);
              frames.push(publicState(state, null));
            } catch {
              break;
            }
          }
        }
        return {
          matchId: m.id,
          frames,
          mode: m.mode,
          players: view(m, profile.id).players,
        };
      }
      const match = path.match(/^\/api\/match\/([\w-]+)$/);
      if (match && method === "GET") {
        const m = get(match[1]);
        if (m && m.mode !== "training") {
          assert(
            Object.values(m.players).includes(profile.id),
            "Kein Zugriff auf diese Partie.",
          );
          timeOut(m);
          return view(m, profile.id);
        }
      }
      return null;
    },
    close() {
      clearInterval(interval);
      for (const ws of peers) ws.close();
    },
  };
}
