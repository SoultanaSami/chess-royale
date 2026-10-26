import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { WebSocket } from "ws";
const port = 4500 + Math.floor(Math.random() * 700),
  base = `http://127.0.0.1:${port}`;
let server,
  log = "",
  a,
  b,
  c,
  d;
const sockets = [];
async function api(path, token, data) {
  const res = await fetch(base + path, {
    method: data ? "POST" : "GET",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(data ? { body: JSON.stringify(data) } : {}),
  });
  return res.json();
}
async function client(token) {
  if (!token) token = (await api("/api/guest", null, {})).token;
  const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`);
  sockets.push(ws);
  const messages = [];
  ws.on("message", (raw) => messages.push(JSON.parse(raw)));
  const wait = async (type, since = 0, predicate = () => true) => {
    for (let i = 0; i < 250; i++) {
      const message = messages
        .slice(since)
        .find((m) => m.type === type && predicate(m));
      if (message) return message;
      await new Promise((r) => setTimeout(r, 20));
    }
    throw new Error(
      `Missing ${type}: ${JSON.stringify(messages.slice(since))}`,
    );
  };
  const send = async (data, type, predicate) => {
    const since = messages.length;
    ws.send(JSON.stringify(data));
    return type ? wait(type, since, predicate) : undefined;
  };
  await new Promise((resolve, reject) => {
    ws.once("open", resolve);
    ws.once("error", reject);
  });
  const auth = await send({ type: "auth", token }, "authenticated");
  return { ws, token, messages, wait, send, profile: auth.profile };
}
before(async () => {
  server = spawn(process.execPath, ["src/server.js"], {
    env: {
      ...process.env,
      PORT: String(port),
      DB_PATH: ":memory:",
      NODE_ENV: "test",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  server.stdout.on("data", (d) => (log += d));
  server.stderr.on("data", (d) => (log += d));
  for (let i = 0; i < 100; i++) {
    try {
      await api("/api/health");
      break;
    } catch {}
    if (server.exitCode !== null) throw Error(log);
    await new Promise((r) => setTimeout(r, 40));
  }
  [a, b, c, d] = await Promise.all([client(), client(), client(), client()]);
});
after(() => {
  for (const ws of sockets) ws.terminate();
  server?.kill();
});
test("room duel, authorization, idempotency, clocks, spectator privacy and reconnect", async () => {
  const room = await a.send({ type: "room-create" }, "room");
  const am = a.messages.length;
  const black = await b.send({ type: "room-join", code: room.code }, "state");
  let white = await a.wait("state", am);
  assert.equal(white.matchId, black.matchId);
  assert.equal(white.color, "w");
  assert.equal(black.color, "b");
  const attempted = await b.send(
    {
      type: "action",
      matchId: white.matchId,
      version: 0,
      action: { type: "move", from: "e2", to: "e4" },
    },
    "error",
  );
  assert.match(attempted.error, /nicht am Zug/);
  const move = {
    type: "action",
    matchId: white.matchId,
    version: 0,
    requestId: "once",
    action: { type: "move", from: "e2", to: "e4" },
  };
  white = await a.send(move, "state", (m) => m.state.version === 1);
  assert.equal(white.state.turn, "b");
  assert.ok(white.clock.w > 300000);
  const repeat = await a.send(move, "state");
  assert.equal(repeat.state.version, 1);
  const watched = await c.send({ type: "watch", code: room.code }, "state");
  assert.equal(watched.color, null);
  assert.deepEqual(watched.state.hand, []);
  assert.deepEqual(watched.state.legalActions, []);
  assert.match(
    (await c.send({ ...move, version: 1, requestId: "cheat" }, "error")).error,
    /Zuschauer/,
  );
  a.ws.close();
  a = await client(a.token);
  const restored = await a.wait("state");
  assert.equal(restored.matchId, white.matchId);
  assert.equal(restored.state.version, 1);
  const ended = await b.send(
    {
      type: "action",
      matchId: white.matchId,
      version: 1,
      requestId: "resign",
      action: { type: "resign" },
    },
    "state",
    (m) => m.state.result,
  );
  assert.equal(ended.state.result.winner, "w");
  const replay = await api("/api/replay/" + white.matchId, a.token);
  assert.equal(replay.frames.length, 3);
  assert.equal(replay.frames[1].turn, "b");
  assert.equal(replay.frames[1].hand.length, 0);
});
test("ranked matchmaking changes Elo/trophies once", async () => {
  await a.send({ type: "queue", mode: "ranked" }, "queued");
  const mark = a.messages.length;
  await b.send({ type: "queue", mode: "ranked" }, "queued");
  const match = await a.wait("state", mark, (m) => m.mode === "ranked");
  const before = (await api("/api/profile", a.token)).profile;
  const bm = b.messages.length;
  await b.send({
    type: "action",
    matchId: match.matchId,
    version: 0,
    requestId: "rank-end",
    action: { type: "resign" },
  });
  await b.wait("state", bm, (m) => m.state.result);
  const after = (await api("/api/profile", a.token)).profile;
  assert.equal(after.trophies, before.trophies + 30);
  assert.ok(after.elo > before.elo);
  await b.send(
    {
      type: "action",
      matchId: match.matchId,
      version: 0,
      requestId: "rank-end",
      action: { type: "resign" },
    },
    "state",
  );
  assert.equal(
    (await api("/api/profile", a.token)).profile.trophies,
    after.trophies,
  );
});
test("four-player tournament advances through semifinals to a champion", async () => {
  const event = await a.send({ type: "tournament-create" }, "tournament");
  const code = event.tournament.code;
  await b.send({ type: "tournament-join", code }, "tournament");
  await c.send({ type: "tournament-join", code }, "tournament");
  const bm = b.messages.length,
    dm = d.messages.length;
  await d.send({ type: "tournament-join", code }, "tournament");
  const first = await b.wait("state", bm),
    second = await d.wait("state", dm);
  await b.send(
    {
      type: "action",
      matchId: first.matchId,
      version: 0,
      requestId: "semi-a",
      action: { type: "resign" },
    },
    "state",
    (m) => m.state.result,
  );
  const cm = c.messages.length;
  await d.send(
    {
      type: "action",
      matchId: second.matchId,
      version: 0,
      requestId: "semi-b",
      action: { type: "resign" },
    },
    "state",
    (m) => m.state.result,
  );
  const final = await c.wait("state", cm, (m) => m.matchId !== second.matchId);
  const mark = a.messages.length;
  await c.send(
    {
      type: "action",
      matchId: final.matchId,
      version: 0,
      requestId: "final",
      action: { type: "resign" },
    },
    "state",
    (m) => m.state.result,
  );
  const completed = await a.wait(
    "tournament",
    mark,
    (m) => m.tournament.status === "complete",
  );
  assert.equal(completed.tournament.champion, a.profile.id);
  assert.equal(completed.tournament.bracket.length, 3);
});
