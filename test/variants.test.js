import test from "node:test";
import assert from "node:assert/strict";
import { createGame, applyAction, legalActions } from "../src/engine.js";
import { DEFAULT_DECK } from "../shared/catalog.js";
const game = (fen, w = {}, b = {}) =>
  createGame({
    fen,
    seed: 14,
    deckWhite: { ...DEFAULT_DECK, ...w },
    deckBlack: { ...DEFAULT_DECK, ...b },
  });
const move = (s, from, to) => applyAction(s, { type: "move", from, to });
test("shieldbearer blocks exactly one capture without moving the attacker", () => {
  let s = game("7k/8/8/8/8/p7/8/R3K3 w - - 0 1", {}, { p: "shieldbearer" });
  s = move(s, "a1", "a3");
  assert.equal(s.position.a1.type, "r");
  assert.equal(s.position.a3.type, "p");
  assert.equal(s.pieces.a3.shieldUsed, true);
  s = move(s, "h8", "g8");
  s = move(s, "a1", "a3");
  assert.equal(s.position.a3.type, "r");
  assert.equal(s.position.a1, undefined);
  const own = game("7k/8/8/8/8/1p6/P7/4K3 w - - 0 1", { p: "shieldbearer" });
  assert.throws(() => move(own, "a2", "b3"), /Schildträger/);
});
test("ram breaks through first enemy and captures directly behind it", () => {
  const s = game("7k/8/8/8/p7/p7/8/R3K3 w - - 0 1");
  const next = applyAction(s, { type: "ability", from: "a1", to: "a4" });
  assert.equal(next.position.a3, undefined);
  assert.equal(next.position.a4.color, "w");
  assert.equal(next.graveyard.length, 2);
});
test("necromancer consumes a captured enemy once, and cannot invent corpses", () => {
  let s = game("7k/8/8/3p4/8/8/8/2BQK3 w - - 0 1", { b: "necromancer" });
  assert.throws(
    () => applyAction(s, { type: "ability", from: "c1", to: "b2" }),
    /gefallene/,
  );
  s = move(s, "d1", "d5");
  s = move(s, "h8", "h7");
  s = applyAction(s, { type: "ability", from: "c1", to: "b2" });
  assert.equal(s.position.b2.type, "p");
  assert.equal(s.graveyard[0].consumed, true);
});
test("marsh witch targets pawns and frog cannot move", () => {
  let s = game("7k/8/8/3pn3/8/8/8/3QK3 w - - 0 1", { q: "marsh-witch" });
  assert.throws(() =>
    applyAction(s, { type: "ability", from: "d1", to: "e5" }),
  );
  s = applyAction(s, { type: "ability", from: "d1", to: "d5" });
  assert.ok(s.pieces.d5.effects.some((e) => e.kind === "frog"));
  assert.ok(!legalActions(s).some((a) => a.from === "d5"));
});
test("gold king grants capture mana only for its own captures", () => {
  const s = game("7k/8/8/8/8/p7/8/R3K3 w - - 0 1");
  s.mana.w = 0;
  assert.equal(move(s, "a1", "a3").mana.w, 1);
  const k = game("7k/8/8/8/8/8/3p4/4K3 w - - 0 1");
  k.mana.w = 0;
  assert.equal(move(k, "e1", "d2").mana.w, 2);
});
test("powder pawn explodes on capture without destroying either king", () => {
  const s = game("7k/8/8/8/2p5/1p6/P7/4K3 w - - 0 1", { p: "powder" });
  const n = move(s, "a2", "b3");
  assert.equal(n.position.b3, undefined);
  assert.equal(n.position.c4, undefined);
  assert.equal(n.position.e1.type, "k");
  assert.equal(n.position.h8.type, "k");
});
test("phoenix returns once to its original start square", () => {
  let s = game("7k/p7/8/8/8/8/8/R3K3 b - - 0 1", {}, { p: "phoenix" });
  s = move(s, "a7", "a6");
  s = move(s, "a1", "a6");
  assert.equal(s.position.a7.type, "p");
  assert.equal(s.pieces.a7.reborn, true);
});

test("command yields two own moves after casting; invisible king resists prison", () => {
  let s = createGame({ seed: 8, spellsWhite: ["command", "shield", "flee"] });
  s = applyAction(s, { type: "spell", spellId: "command" });
  assert.equal(s.turn, "w");
  s = move(s, "e2", "e4");
  assert.equal(s.turn, "w");
  s = move(s, "d2", "d4");
  assert.equal(s.turn, "b");
  let hidden = createGame({
    seed: 9,
    deckWhite: { ...DEFAULT_DECK, k: "shadow-king" },
    spellsBlack: ["prison", "shield", "flee"],
  });
  hidden = applyAction(hidden, { type: "ability", from: "e1" });
  assert.throws(() =>
    applyAction(hidden, { type: "spell", spellId: "prison", to: "e1" }),
  );
});
