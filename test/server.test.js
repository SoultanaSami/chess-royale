import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
const port = 3400 + Math.floor(Math.random() * 1000),
  base = `http://127.0.0.1:${port}`;
let child,
  token,
  profile,
  output = "";
async function request(
  path,
  data,
  auth = token,
  method = data === undefined ? "GET" : "POST",
) {
  const res = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(auth ? { Authorization: `Bearer ${auth}` } : {}),
    },
    ...(data !== undefined ? { body: JSON.stringify(data) } : {}),
  });
  return { status: res.status, ...(await res.json()) };
}
before(async () => {
  child = spawn(process.execPath, ["src/server.js"], {
    env: {
      ...process.env,
      PORT: String(port),
      DB_PATH: ":memory:",
      NODE_ENV: "test",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  child.stdout.on("data", (d) => (output += d));
  child.stderr.on("data", (d) => (output += d));
  for (let i = 0; i < 100; i++) {
    try {
      const response = await request("/api/health");
      if (response.ok) break;
    } catch {}
    if (child.exitCode !== null) throw new Error(output);
    await new Promise((r) => setTimeout(r, 50));
    if (i === 99) throw new Error("Server start timeout " + output);
  }
  const guest = await request("/api/guest", {}, null);
  token = guest.token;
  profile = guest.profile;
});
after(() => child?.kill());
test("guest accounts persist by token and reject forged tokens", async () => {
  const resumed = await request("/api/guest", { token }, null);
  assert.equal(resumed.profile.id, profile.id);
  const forged = await request("/api/profile", undefined, "a".repeat(64));
  assert.equal(forged.status, 401);
});
test("deck validates roles and unique spells", async () => {
  const invalid = await request("/api/deck", {
    deck: { ...profile.deck, k: profile.deck.p },
    spells: profile.spells,
  });
  assert.equal(invalid.status, 400);
  const duplicate = await request("/api/deck", {
    deck: profile.deck,
    spells: ["flee", "flee", "meteor"],
  });
  assert.equal(duplicate.status, 400);
  const valid = await request("/api/deck", {
    deck: profile.deck,
    spells: profile.spells,
  });
  assert.equal(valid.status, 200);
});
test("server owns chess state, rejects illegal moves, stale actions and foreign players", async () => {
  const match = await request("/api/training", {
    mode: "classic",
    difficulty: "easy",
  });
  assert.equal(match.status, 201);
  const initial = match.state.version;
  const illegal = await request(`/api/match/${match.matchId}/action`, {
    version: initial,
    action: { type: "move", from: "e2", to: "e5" },
  });
  assert.equal(illegal.status, 400);
  const good = await request(`/api/match/${match.matchId}/action`, {
    version: initial,
    actionId: "first-move",
    action: { type: "move", from: "e2", to: "e4" },
  });
  assert.equal(good.status, 200);
  assert.equal(good.state.turn, "w");
  assert.ok(good.state.version > initial);
  const retried = await request(`/api/match/${match.matchId}/action`, {
    version: initial,
    actionId: "first-move",
    action: { type: "move", from: "e2", to: "e4" },
  });
  assert.equal(retried.state.version, good.state.version);
  const stale = await request(`/api/match/${match.matchId}/action`, {
    version: initial,
    action: { type: "move", from: "d2", to: "d4" },
  });
  assert.equal(stale.status, 409);
  const second = await request("/api/guest", {}, null);
  const stranger = await request(
    `/api/match/${match.matchId}`,
    undefined,
    second.token,
  );
  assert.equal(stranger.status, 403);
});
test("development API rejects nonlocal origins", async () => {
  const res = await fetch(base + "/api/dev", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      Origin: "https://unrelated.example",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ action: "gold" }),
  });
  assert.equal(res.status, 403);
});

test("settings persist only allowed fields; tutorial advances after its actual goal", async () => {
  const before = await request('/api/profile');
  const settings = await request('/api/settings', {settings:{sound:false,language:'en',battery:true,gold:999999},gold:999999});
  assert.equal(settings.profile.settings.sound,false);
  assert.equal(settings.profile.settings.language,'en');
  assert.equal(settings.profile.gold,before.profile.gold);
  for(let lesson=1;lesson<=3;lesson++){
    const match=await request('/api/training',{tutorial:true});
    assert.equal(match.tutorial.lesson,lesson);
    const action=lesson===1?{type:'move',from:'e2',to:'e4'}:lesson===2?{type:'summon',cardId:profile.deck.p,to:'e2'}:{type:'spell',spellId:'shield',to:'e1'};
    const played=await request(`/api/match/${match.matchId}/action`,{version:match.state.version,action});
    assert.equal(played.tutorial.goalReached,true);
    const finished=await request(`/api/match/${match.matchId}/action`,{version:played.state.version,action:{type:'resign'}});
    assert.equal(finished.profile.tutorial,lesson);
    const repeated=await request(`/api/match/${match.matchId}/action`,{version:finished.state.version,action:{type:'resign'}});
    assert.equal(repeated.status,400);
  }
});
