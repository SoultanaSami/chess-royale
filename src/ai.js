import { legalActions, simulateAction } from "./engine.js";
const VALUE = { p: 100, n: 320, b: 335, r: 500, q: 900, k: 0 },
  opp = (c) => (c === "w" ? "b" : "w");
function evaluate(s, c) {
  if (s.result)
    return s.result.winner === c ? 100000 : s.result.winner ? -100000 : 0;
  let value = (s.mana[c] - s.mana[opp(c)]) * 14;
  for (const [q, p] of Object.entries(s.position)) {
    const x = q.charCodeAt(0) - 97,
      y = Number(q[1]) - 1,
      center = 7 - (Math.abs(3.5 - x) + Math.abs(3.5 - y)),
      forward = p.color === "w" ? y : 7 - y;
    value +=
      (p.color === c ? 1 : -1) *
      (VALUE[p.type] +
        center * (p.type === "n" ? 10 : 3) +
        (p.type === "p" ? forward * 7 : 0));
  }
  if (s.check) value += s.turn === c ? -45 : 45;
  return value;
}
function ranked(s, actions, c) {
  return actions
    .map((action) => {
      try {
        const next = simulateAction(s, action);
        return { action, next, score: evaluate(next, c) };
      } catch {
        return null;
      }
    })
    .filter(Boolean)
    .sort((a, b) => b.score - a.score);
}
export function chooseAI(s, difficulty = s.difficulty || "easy") {
  const actions = legalActions(s);
  if (!actions.length) return null;
  const c = s.turn;
  if (difficulty === "easy")
    return actions[
      ((Math.imul(s.rng || 1, 1103515245) + 12345) >>> 0) % actions.length
    ];
  const options = ranked(s, actions, c);
  if (difficulty === "medium") return options[0].action;
  const deadline = Date.now() + 1400;
  let best = options[0],
    bestScore = -Infinity;
  for (const option of options.slice(0, 10)) {
    if (Date.now() > deadline) break;
    const replies = legalActions(option.next);
    let score = option.score;
    if (!replies.length)
      score = option.next.check
        ? option.next.turn === c
          ? -100000
          : 100000
        : 0;
    else {
      const r = ranked(option.next, replies, c);
      score = option.next.turn === c ? r[0].score : r.at(-1).score;
    }
    if (score > bestScore) {
      best = option;
      bestScore = score;
    }
  }
  return best.action;
}
