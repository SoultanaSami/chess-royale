import test from "node:test";
import assert from "node:assert/strict";
import {
  chestAction,
  rollChest,
  progressAction,
  refreshProgress,
} from "../src/progression.js";
import { createGame, applyAction } from "../src/engine.js";
const now = Date.UTC(2026, 9, 25, 12);
const profile = () =>
  refreshProgress(
    {
      gold: 5000,
      gems: 200,
      trophies: 0,
      collection: {},
      unlocked: [],
      pity: {},
      chests: [
        { id: "a", type: "wood", status: "locked", readyAt: null },
        { id: "b", type: "iron", status: "locked", readyAt: null },
        null,
        null,
      ],
      stats: {
        moves: 0,
        matches: 0,
        wins: 0,
        summons: 0,
        spells: 0,
        chests: 0,
      },
      quests: { day: "", claimed: [] },
      season: { id: "", xp: 0, premium: false, claimed: [] },
      loginDay: "",
    },
    now,
  );
test("chest timers are server-owned; only one unlocks; reward can be claimed once", () => {
  const p = profile();
  chestAction(p, "start", { slot: 0 }, now);
  assert.equal(p.chests[0].readyAt, now + 60000);
  assert.throws(() => chestAction(p, "start", { slot: 1 }, now));
  assert.throws(() => chestAction(p, "open", { slot: 0 }, now + 100));
  const loot = chestAction(p, "open", { slot: 0 }, now + 60000);
  assert.equal(loot.loot.cards.length, 2);
  assert.equal(p.chests[0], null);
  assert.throws(() => chestAction(p, "open", { slot: 0 }, now + 60000));
});
test("pity guarantees rarity and royal chests only contain kings and spells", () => {
  const p = profile();
  p.pity.wood = { epic: 0, legendary: 49 };
  const loot = rollChest(p, "wood", () => 0);
  assert.equal(loot.cards[0].rarity, "legendary");
  assert.equal(p.pity.wood.legendary, 0);
  p.pity.royal = { epic: 2, legendary: 0 };
  const royal = rollChest(p, "royal", () => 0);
  assert.ok(royal.cards.every((c) => c.role === "k" || c.role === "spell"));
  assert.equal(royal.cards[0].rarity, "epic");
});
test("duplicate fragments pay for upgrades and levels cap at ten", () => {
  const p = profile();
  rollChest(p, "wood", () => 0);
  const loot = rollChest(p, "wood", () => 0);
  assert.ok(loot.cards[0].duplicate);
  const id = loot.cards[0].id;
  assert.ok(p.collection[id].fragments >= 10);
  progressAction(p, "/api/upgrade", { cardId: id }, now);
  assert.equal(p.collection[id].level, 2);
  p.collection[id].level = 10;
  assert.throws(() => progressAction(p, "/api/upgrade", { cardId: id }, now));
});
test("login and quest rewards are idempotent and reset at UTC day boundaries", () => {
  const p = profile();
  progressAction(p, "/api/login/claim", {}, now);
  assert.throws(() => progressAction(p, "/api/login/claim", {}, now));
  p.stats.moves = 10;
  progressAction(p, "/api/quests/claim", { questId: "moves" }, now);
  assert.throws(() =>
    progressAction(p, "/api/quests/claim", { questId: "moves" }, now),
  );
  refreshProgress(p, now + 86400000);
  assert.throws(() =>
    progressAction(
      p,
      "/api/quests/claim",
      { questId: "moves" },
      now + 86400000,
    ),
  );
  progressAction(p, "/api/login/claim", {}, now + 86400000);
  assert.equal(p.loginStreak, 2);
});
test("shop enforces currency and four chest slots, pass enforces unlocked tiers", () => {
  const p = profile();
  progressAction(p, "/api/shop/buy", { offerId: "chest-wood" }, now);
  progressAction(p, "/api/shop/buy", { offerId: "chest-wood" }, now);
  assert.throws(() =>
    progressAction(p, "/api/shop/buy", { offerId: "chest-wood" }, now),
  );
  assert.throws(() =>
    progressAction(p, "/api/pass/claim", { tier: 1, track: "premium" }, now),
  );
  progressAction(p, "/api/pass/buy", {}, now);
  p.season.xp = 50;
  progressAction(p, "/api/pass/claim", { tier: 1, track: "premium" }, now);
  assert.throws(() =>
    progressAction(p, "/api/pass/claim", { tier: 1, track: "premium" }, now),
  );
});
test("arena events are deterministic and keep both kings; card levels generate resonance", () => {
  const options = {
    seed: 92,
    arena: "forest",
    levelsWhite: { miner: { level: 10 } },
  };
  const play = () => {
    let s = createGame(options);
    for (const [from, to] of [
      ["e2", "e4"],
      ["e7", "e5"],
      ["d2", "d4"],
      ["d7", "d5"],
    ])
      s = applyAction(s, { type: "move", from, to });
    return s;
  };
  const a = play(),
    b = play();
  assert.deepEqual(a.terrain, b.terrain);
  assert.equal(a.terrain.length, 1);
  assert.equal(a.position.e1.type, "k");
  assert.equal(a.position.e8.type, "k");
  assert.equal(a.resonance.w, 8);
});
