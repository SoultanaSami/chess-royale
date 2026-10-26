import { createMultiplayer } from "./multiplayer.js";
import http from "node:http";
import { readFile, stat } from "node:fs/promises";
import { resolve, extname, sep } from "node:path";
import { randomUUID } from "node:crypto";
import { networkInterfaces } from "node:os";
import { WebSocketServer, WebSocket } from "ws";
import { createGame, applyAction, publicState } from "./engine.js";
import { chooseAI } from "./ai.js";
import {
  accountForToken,
  createAccount,
  saveProfile,
  validateDeck,
  getMatch,
  saveMatch,
  appendEvent,
} from "./store.js";
import {
  refreshProgress,
  progressionView,
  progressAction,
  awardMatch,
} from "./progression.js";
import { BALANCE, ARENAS } from "../shared/catalog.js";

const root = resolve(".");
const port = Number(process.env.PORT || 3000);
const production = process.env.NODE_ENV === "production";
const clients = new Set();
const busy = new Set();
const rate = new Map();
export const server = http.createServer(handleRequest);
const wss = new WebSocketServer({ noServer: true, maxPayload: 16384 });
const multiplayer = createMultiplayer(wss);

export function isLocal(req) {
  const remote = req.socket.remoteAddress;
  const host = (req.headers.host || "").split(":")[0];
  return (
    !production &&
    ["127.0.0.1", "::1", "::ffff:127.0.0.1"].includes(remote) &&
    ["localhost", "127.0.0.1", "["].includes(host)
  );
}
function checkOrigin(req) {
  if (
    req.headers.origin &&
    new URL(req.headers.origin).host !== req.headers.host
  )
    throw Object.assign(new Error("Fremder Ursprung ist nicht erlaubt."), {
      status: 403,
    });
}
function send(res, status, data) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  res.end(JSON.stringify(data));
}
async function body(req) {
  let result = "";
  for await (const chunk of req) {
    result += chunk;
    if (result.length > 32768)
      throw Object.assign(new Error("Anfrage ist zu groß."), { status: 413 });
  }
  try {
    return result ? JSON.parse(result) : {};
  } catch {
    throw new Error("Ungültige JSON-Anfrage.");
  }
}
function authenticate(req) {
  const token = (req.headers.authorization || "").replace(/^Bearer /, "");
  const profile = accountForToken(token);
  if (!profile)
    throw Object.assign(new Error("Bitte melde dich erneut als Gast an."), {
      status: 401,
    });
  return saveProfile(refreshProgress(profile));
}
function ownedMatch(id, profile) {
  const match = getMatch(id);
  if (!match)
    throw Object.assign(new Error("Partie nicht gefunden."), { status: 404 });
  if (!Object.values(match.players).includes(profile.id))
    throw Object.assign(
      new Error("Diese Partie gehört einem anderen Spieler."),
      { status: 403 },
    );
  return match;
}
function view(match, profile) {
  const color =
    match.players.w === profile.id
      ? "w"
      : match.players.b === profile.id
        ? "b"
        : null;
  return {
    matchId: match.id,
    state: publicState(match.state, color),
    color,
    mode: match.mode,
    code: match.code || null,
    tutorial: match.tutorial || null,
  };
}
function allowRequest(req) {
  const key = req.socket.remoteAddress;
  const now = Date.now();
  let bucket = rate.get(key);
  if (!bucket || now - bucket.since > 10000) {
    bucket = { since: now, count: 0 };
    rate.set(key, bucket);
  }
  if (++bucket.count > 300)
    throw Object.assign(
      new Error("Zu viele Anfragen. Warte einen Augenblick."),
      { status: 429 },
    );
}
async function handleRequest(req, res) {
  try {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname.startsWith("/api/")) {
      allowRequest(req);
      checkOrigin(req);
      if (url.pathname === "/api/health")
        return send(res, 200, { ok: true, phase: 4 });
      if (url.pathname === "/api/guest" && req.method === "POST") {
        const data = await body(req);
        const existing = accountForToken(data.token);
        return send(
          res,
          200,
          existing ? { token: data.token, profile: existing } : createAccount(),
        );
      }
      const profile = authenticate(req);
      const realtimeResponse = multiplayer.http(
        url.pathname,
        req.method,
        profile,
      );
      if (realtimeResponse) return send(res, 200, realtimeResponse);
      if (url.pathname === "/api/progression" && req.method === "GET")
        return send(res, 200, progressionView(profile));
      if (
        [
          "/api/chests/start",
          "/api/chests/open",
          "/api/shop/buy",
          "/api/upgrade",
          "/api/login/claim",
          "/api/quests/claim",
          "/api/pass/buy",
          "/api/pass/claim",
          "/api/arena",
        ].includes(url.pathname) &&
        req.method === "POST"
      ) {
        const result = progressAction(profile, url.pathname, await body(req));
        saveProfile(profile);
        return send(res, 200, result);
      }
      if (url.pathname === "/api/profile" && req.method === "GET")
        return send(res, 200, { profile, dev: isLocal(req) });
      if (url.pathname === "/api/settings" && req.method === "POST") {
        const data = await body(req);
        const allowed = {
          sound: "boolean",
          music: "boolean",
          vibration: "boolean",
          battery: "boolean",
          colorblind: "boolean",
          largeText: "boolean",
        };
        if (data.settings) {
          for (const [key, type] of Object.entries(allowed))
            if (typeof data.settings[key] === type)
              profile.settings[key] = data.settings[key];
          if (["de", "en"].includes(data.settings.language))
            profile.settings.language = data.settings.language;
          if (["high", "low"].includes(data.settings.quality))
            profile.settings.quality = data.settings.quality;
        }
        if (typeof data.name === "string") {
          const name = data.name.trim().slice(0, 24);
          if (name.length < 2)
            throw new Error("Dein Name benötigt mindestens zwei Zeichen.");
          profile.name = name;
        }
        return send(res, 200, { profile: saveProfile(profile) });
      }
      if (url.pathname === "/api/deck" && req.method === "POST") {
        Object.assign(
          profile,
          validateDeck(
            ...((data) => [data.deck, data.spells])(await body(req)),
          ),
        );
        return send(res, 200, { profile: saveProfile(profile) });
      }
      if (url.pathname === "/api/training" && req.method === "POST") {
        const data = await body(req);
        const lesson =
          data.tutorial && profile.tutorial < 3 ? profile.tutorial + 1 : null;
        const difficulty = lesson
          ? "easy"
          : ["easy", "medium", "hard"].includes(data.difficulty)
            ? data.difficulty
            : "easy";
        const mode = lesson
          ? lesson === 1
            ? "classic"
            : "fantasy"
          : data.mode === "classic"
            ? "classic"
            : "fantasy";
        const state = createGame({
          deckWhite: profile.deck,
          spellsWhite:
            lesson === 3 ? ["shield", "flee", "meteor"] : profile.spells,
          difficulty,
          mode,
          arena: lesson ? "hall" : profile.arena,
          levelsWhite: profile.collection,
          ...(lesson === 2
            ? {
                fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1",
              }
            : {}),
        });
        if (lesson === 2)
          state.hands.w = [profile.deck.p, profile.deck.n, profile.deck.b];
        const match = {
          id: randomUUID(),
          tutorial: lesson
            ? {
                lesson,
                goal: ["move", "summon", "spell"][lesson - 1],
                goalReached: false,
              }
            : null,
          mode: "training",
          players: { w: profile.id, b: "ai" },
          difficulty,
          state,
          initialState: structuredClone(state),
          createdAt: Date.now(),
          requestIds: [],
        };
        saveMatch(match);
        return send(res, 201, view(match, profile));
      }
      const actionMatch = url.pathname.match(
        /^\/api\/match\/([a-zA-Z0-9-]+)\/action$/,
      );
      if (actionMatch && req.method === "POST") {
        const data = await body(req);
        const match = ownedMatch(actionMatch[1], profile);
        if (match.mode !== "training")
          throw new Error(
            "Für diese Partie ist die Echtzeit-Verbindung erforderlich.",
          );
        if (data.actionId && match.requestIds.includes(data.actionId))
          return send(res, 200, view(match, profile));
        if (match.state.result) throw new Error("Diese Partie ist bereits beendet.");
        if (busy.has(match.id))
          throw new Error("Dein vorheriger Zug wird noch verarbeitet.");
        if (data.version !== match.state.version)
          throw Object.assign(
            new Error(
              "Die Stellung hat sich geändert. Aktualisiere die Partie.",
            ),
            { status: 409 },
          );
        busy.add(match.id);
        try {
          if (data.action?.type === "resign")
            match.state = {
              ...match.state,
              result: { winner: "b", reason: "resignation" },
              version: match.state.version + 1,
            };
          else match.state = applyAction(match.state, data.action, "w");
          appendEvent(match.id, {
            action: data.action,
            color: "w",
            at: Date.now(),
            version: match.state.version,
          });
          if (match.tutorial && data.action?.type === match.tutorial.goal)
            match.tutorial.goalReached = true;
          profile.stats.moves++;
          if (data.action?.type === "summon") profile.stats.summons++;
          if (data.action?.type === "spell") profile.stats.spells++;
          let aiTurns = 0;
          while (
            !match.state.result &&
            match.state.turn === "b" &&
            aiTurns++ < 3
          ) {
            const action = chooseAI(match.state, match.difficulty);
            if (!action) break;
            match.state = applyAction(match.state, action, "b");
            appendEvent(match.id, {
              action,
              color: "b",
              at: Date.now(),
              version: match.state.version,
            });
          }
          if (match.state.result && !match.rewarded) {
            match.rewarded = true;
            awardMatch(profile, match.state.result.winner, "w");
            if (
              match.tutorial?.goalReached &&
              profile.tutorial === match.tutorial.lesson - 1
            )
              profile.tutorial = match.tutorial.lesson;
          }
          if (data.actionId)
            match.requestIds = [...match.requestIds.slice(-49), data.actionId];
          saveProfile(profile);
          saveMatch(match);
          return send(res, 200, { ...view(match, profile), profile });
        } finally {
          busy.delete(match.id);
        }
      }
      const matchUrl = url.pathname.match(/^\/api\/match\/([a-zA-Z0-9-]+)$/);
      if (matchUrl && req.method === "GET")
        return send(res, 200, view(ownedMatch(matchUrl[1], profile), profile));
      if (url.pathname === "/api/dev" && req.method === "POST") {
        if (!isLocal(req))
          throw Object.assign(
            new Error("Entwicklerwerkzeuge sind nur auf localhost verfügbar."),
            { status: 403 },
          );
        const data = await body(req);
        const value = Math.max(
          0,
          Math.min(
            100000,
            Number.isFinite(Number(data.value)) ? Number(data.value) : 1000,
          ),
        );
        if (data.action === "gold") profile.gold += value;
        else if (data.action === "gems") profile.gems += value;
        else if (data.action === "trophies") profile.trophies = value;
        else if (data.action === "open-chest") {
          const slot = Number.isInteger(data.slot)
            ? data.slot
            : profile.chests.findIndex((c) => c);
          if (slot < 0) throw new Error("Keine Truhe vorhanden.");
          profile.chests[slot].status = "opening";
          profile.chests[slot].readyAt = Date.now();
        } else if (data.action === "mana") {
          const match = ownedMatch(data.matchId, profile);
          match.state.mana.w = BALANCE.maxMana;
          match.state.version++;
          saveMatch(match);
          return send(res, 200, { ...view(match, profile), profile });
        } else if (data.action === "pity")
          return send(res, 200, { pity: profile.pity, profile });
        else throw new Error("Unbekanntes Entwicklerwerkzeug.");
        return send(res, 200, { profile: saveProfile(profile) });
      }
      return send(res, 404, { error: "Dieser Weg ist noch verschlossen." });
    }
    if (req.method !== "GET" && req.method !== "HEAD")
      return send(res, 405, { error: "Methode nicht erlaubt." });
    let file;
    if (url.pathname === "/vendor/html-to-image.js")
      file = resolve(root, "node_modules/html-to-image/dist/html-to-image.js");
    else {
      const base = url.pathname.startsWith("/shared/")
        ? resolve(root, "shared")
        : resolve(root, "public");
      const relative = url.pathname.startsWith("/shared/")
        ? url.pathname.slice(8)
        : url.pathname === "/"
          ? "index.html"
          : url.pathname.slice(1);
      file = resolve(base, decodeURIComponent(relative));
      if (!file.startsWith(base + sep))
        return send(res, 403, { error: "Verbotener Pfad." });
    }
    const contents = await readFile(file);
    const mime =
      {
        ".html": "text/html",
        ".js": "text/javascript",
        ".css": "text/css",
        ".json": "application/json",
        ".webmanifest": "application/manifest+json",
        ".svg": "image/svg+xml",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".ttf": "font/ttf",
        ".webp": "image/webp",
        ".woff2": "font/woff2",
        ".ico": "image/x-icon",
      }[extname(file)] || "application/octet-stream";
    res.writeHead(200, {
      "Content-Type": mime + "; charset=utf-8",
      "Cache-Control": "no-cache",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "same-origin",
      "Service-Worker-Allowed": "/",
    });
    res.end(req.method === "HEAD" ? undefined : contents);
  } catch (error) {
    if (error.code === "ENOENT")
      return send(res, 404, { error: "Datei nicht gefunden." });
    if (error.status >= 500) console.error(error);
    if (!res.headersSent)
      send(res, error.status || 400, {
        error: error.message || "Ein Fehler ist aufgetreten.",
      });
  }
}
server.on("upgrade", (req, socket, head) => {
  try {
    checkOrigin(req);
    if (new URL(req.url, "http://localhost").pathname !== "/ws")
      return socket.destroy();
    wss.handleUpgrade(req, socket, head, (ws) =>
      wss.emit("connection", ws, req),
    );
  } catch {
    socket.destroy();
  }
});
server.listen(port, process.env.HOST || "0.0.0.0", () => {
  console.log(`Chess Royale läuft: http://localhost:${port}`);
  for (const entries of Object.values(networkInterfaces()))
    for (const entry of entries || [])
      if (entry.family === "IPv4" && !entry.internal)
        console.log(`Im WLAN: http://${entry.address}:${port}`);
});
function shutdown() {
  multiplayer.close();
  for (const ws of clients) ws.close();
  wss.close();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1500).unref();
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
