import test from "node:test";
import assert from "node:assert/strict";
import {
  createGame,
  applyAction,
  legalActions,
  publicState,
} from "../src/engine.js";
import { chooseAI } from "../src/ai.js";
import { DEFAULT_DECK } from "../shared/catalog.js";
const classic = (fen) => createGame({ mode: "classic", fen, seed: 42 });
const move = (s, from, to, promotion) =>
  applyAction(s, {
    type: "move",
    from,
    to,
    ...(promotion ? { promotion } : {}),
  });
const deck = (overrides) => ({ ...DEFAULT_DECK, ...overrides });

test("opening has twenty legal moves; actions never mutate their input", () => {
  const s = classic(),
    before = JSON.stringify(s);
  assert.equal(legalActions(s).length, 20);
  const n = move(s, "e2", "e4");
  assert.equal(n.turn, "b");
  assert.equal(n.position.e4.type, "p");
  assert.equal(JSON.stringify(s), before);
});
test("Fools mate ends with an authoritative winner", () => {
  let s = classic();
  for (const [from, to] of [
    ["f2", "f3"],
    ["e7", "e5"],
    ["g2", "g4"],
    ["d8", "h4"],
  ])
    s = move(s, from, to);
  assert.deepEqual(s.result, { winner: "b", reason: "checkmate" });
});
test("en passant removes the correct pawn and expires after one action", () => {
  let s = classic("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2");
  s = move(s, "e5", "d6");
  assert.equal(s.position.d5, undefined);
  assert.equal(s.position.d6.color, "w");
  let t = classic("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2");
  t = move(t, "e1", "f1");
  t = move(t, "e8", "f8");
  assert.throws(() => move(t, "e5", "d6"));
});
test("en passant cannot expose the own king", () => {
  const s = classic("4r1k1/8/8/3pP3/8/8/8/4K3 w - d6 0 2");
  assert.throws(() => move(s, "e5", "d6"));
});
test("castling relocates the rook and cannot pass through check", () => {
  const s = classic("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"),
    n = move(s, "e1", "g1");
  assert.equal(n.position.f1.type, "r");
  assert.equal(n.position.h1, undefined);
  const blocked = classic("r3kr1r/8/8/8/8/8/8/R3K2R w KQ - 0 1");
  assert.throws(() => move(blocked, "e1", "g1"));
});
test("promotion supports queen, rook, bishop and knight", () => {
  const s = classic("4k2r/P7/8/8/8/8/8/4K3 w - - 0 1");
  assert.deepEqual(
    legalActions(s)
      .filter((a) => a.from === "a7" && a.to === "a8")
      .map((a) => a.promotion)
      .sort(),
    ["b", "n", "q", "r"],
  );
  assert.equal(move(s, "a7", "a8", "n").position.a8.type, "n");
});
test("stalemate and insufficient material are draws", () => {
  assert.equal(
    classic("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1").result.reason,
    "stalemate",
  );
  assert.equal(
    classic("7k/8/6K1/8/8/8/8/8 w - - 0 1").result.reason,
    "insufficient-material",
  );
});
test("a spell can rescue a position that is standard chess mate", () => {
  const fen = "7k/6Q1/6K1/8/8/8/8/8 b - - 0 1";
  assert.equal(classic(fen).result.reason, "checkmate");
  let s = createGame({
    fen,
    seed: 1,
    spellsBlack: ["banish", "shield", "flee"],
  });
  assert.equal(s.result, null);
  s = applyAction(s, { type: "spell", spellId: "banish", to: "g7" });
  assert.equal(s.position.g7, undefined);
  assert.equal(s.banished.length, 1);
});
test("summoning validates hand, mana, home ranks and king safety", () => {
  const s = createGame({ fen: "4k3/8/8/8/8/8/8/4K3 w - - 0 1", seed: 1 });
  s.hands.w = ["rider", "rider", "rider"];
  s.mana.w = 5;
  const n = applyAction(s, { type: "summon", cardId: "rider", to: "b1" });
  assert.equal(n.position.b1.type, "n");
  assert.equal(n.mana.w, 3);
  assert.equal(n.hands.w.length, 3);
  assert.throws(() =>
    applyAction(s, { type: "summon", cardId: "rider", to: "b3" }),
  );
  assert.throws(() =>
    applyAction(s, { type: "summon", cardId: "gold-king", to: "a1" }),
  );
  const checked = createGame({
    fen: "4r1k1/8/8/8/8/8/8/4K3 w - - 0 1",
    seed: 1,
  });
  checked.hands.w = ["rider"];
  assert.throws(() =>
    applyAction(checked, { type: "summon", cardId: "rider", to: "a1" }),
  );
  assert.ok(
    applyAction(checked, { type: "summon", cardId: "rider", to: "e2" }),
  );
});
test("authority rejects wrong actors, malformed moves and classic magic", () => {
  const s = classic();
  assert.throws(() =>
    applyAction(s, { type: "move", from: "e7", to: "e5" }, "b"),
  );
  assert.throws(() => applyAction(s, { type: "spell", spellId: "command" }));
  assert.throws(() =>
    applyAction(s, { type: "teleport", from: "e2", to: "e8" }),
  );
});
test("public views do not leak opposing hands, RNG or rewind snapshots", () => {
  const s = createGame({ seed: 2 }),
    v = publicState(s, "w"),
    spectator = publicState(s, null);
  assert.equal(v.hand.length, 3);
  assert.equal(v.rng, undefined);
  assert.equal(v._snapshots, undefined);
  assert.equal(v.hands, undefined);
  assert.equal(v.enemyHand, null);
  assert.equal(spectator.hand.length, 0);
  assert.equal(spectator.legalActions.length, 0);
});
test("meteor destroys exactly one enemy in its 2x2 area, never a king", () => {
  const s = createGame({ fen: "4k3/8/8/8/8/pp6/8/4K3 w - - 0 1", seed: 3 });
  s.mana.w = 10;
  const n = applyAction(s, { type: "spell", spellId: "meteor", to: "a3" });
  assert.equal(
    Object.values(n.position).filter((p) => p.color === "b" && p.type === "p")
      .length,
    1,
  );
  assert.throws(() =>
    applyAction(s, { type: "spell", spellId: "meteor", to: "e8" }),
  );
});
test("rider splash is orthogonal; dragon-rider splash includes diagonals", () => {
  const options = {
    deckWhite: deck({ n: "rider", b: "priest" }),
    deckBlack: deck({ b: "priest" }),
    fen: "7k/8/8/8/8/2p5/8/1N2K3 w - - 0 1",
    seed: 4,
  };
  let s = move(createGame(options), "b1", "d2");
  assert.equal(s.position.c3.type, "p");
  s = move(
    createGame({
      ...options,
      deckWhite: deck({ n: "dragon-rider", b: "priest" }),
    }),
    "b1",
    "d2",
  );
  assert.equal(s.position.c3, undefined);
  assert.equal(s.position.h8.type, "k");
});
test("teleport cannot finish in check", () => {
  const s = createGame({
    deckWhite: deck({ k: "flee-king", b: "priest" }),
    fen: "r6k/8/8/8/8/8/8/2K5 w - - 0 1",
    seed: 5,
  });
  assert.throws(() =>
    applyAction(s, { type: "ability", from: "c1", to: "a2" }),
  );
  assert.ok(applyAction(s, { type: "ability", from: "c1", to: "d2" }));
});
test("rewind restores two actions without undoing its own consumption", () => {
  let s = createGame({ deckWhite: deck({ k: "time-king" }), seed: 6 });
  s = move(s, "e2", "e4");
  s = move(s, "e7", "e5");
  const t = applyAction(s, { type: "ability", from: "e1" });
  assert.equal(t.position.e2.type, "p");
  assert.equal(t.position.e7.type, "p");
  assert.equal(t.position.e4, undefined);
  assert.equal(t.usedAbilities.w.rewind, true);
  assert.equal(t.version, 3);
});
test("all three AI difficulties return legal actions", () => {
  const s = classic();
  for (const d of ["easy", "medium", "hard"]) {
    const a = chooseAI(s, d);
    assert.ok(a);
    assert.ok(applyAction(s, a));
  }
});
