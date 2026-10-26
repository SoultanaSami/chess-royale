const files = "abcdefgh";
const squares = Array.from(
  { length: 64 },
  (_, i) => files[i % 8] + (1 + Math.floor(i / 8)),
);
const xy = (q) => [files.indexOf(q[0]), Number(q[1]) - 1];
const square = (x, y) =>
  x >= 0 && x < 8 && y >= 0 && y < 8 ? files[x] + (y + 1) : null;
export function terrainCheck(s, a) {
  if (s.mode === "classic" || !s.terrain?.length) return;
  const blocked = (q) =>
    s.terrain.some(
      (t) =>
        t.square === q &&
        ["roots", "mist", "collapse"].includes(t.kind) &&
        t.until > s.ply &&
        t.starts <= s.ply,
    );
  const shadow = s.pieces[a.from]?.variantId === "shadow-horse";
  if (a.to && blocked(a.to) && !shadow)
    throw new Error("Dieses Feld ist durch die Arena versperrt.");
  if (a.from && blocked(a.from) && !shadow)
    throw new Error("Diese Figur wird von der Arena festgehalten.");
  if (a.type === "move" && s.position[a.from]?.type !== "n") {
    const [x, y] = xy(a.from),
      [u, v] = xy(a.to),
      dx = Math.sign(u - x),
      dy = Math.sign(v - y);
    if (x === u || y === v || Math.abs(x - u) === Math.abs(y - v))
      for (let i = 1; i < Math.max(Math.abs(u - x), Math.abs(v - y)); i++)
        if (blocked(square(x + dx * i, y + dy * i)))
          throw new Error("Der Weg wird durch die Arena versperrt.");
  }
}
export function arenaStep(s, a, c, h) {
  if (s.mode === "classic" || s.arena === "hall") return;
  s.terrain ??= [];
  const now = s.ply + 1;
  s.terrain = s.terrain.filter((t) => t.until > now);
  const choose = (pool) =>
    pool.length ? pool[Math.floor(h.random(s) * pool.length)] : null;
  const empty = () =>
    squares.filter(
      (q) => !s.position[q] && !s.terrain.some((t) => t.square === q),
    );
  const add = (kind, q, delay = 0, lifetime = 4) => {
    if (q)
      s.terrain.push({
        kind,
        square: q,
        starts: now + delay,
        until: now + delay + lifetime,
      });
  };
  if (s.arena === "forest" && now % 4 === 0) {
    s.terrain = s.terrain.filter((t) => t.kind !== "roots");
    add("roots", choose(empty()));
  }
  if (s.arena === "forge" && now % 4 === 0)
    add(
      "fire",
      choose(squares.filter((q) => s.position[q]?.type !== "k")),
      2,
      2,
    );
  if (s.arena === "grove" && now % 4 === 0)
    add("mist", choose(empty()), 0, 1000000);
  if (s.arena === "mines") {
    if (now % 6 === 0) add("collapse", choose(empty()), 2, 1000000);
    if (now % 4 === 0) add("treasure", choose(empty()), 0, 8);
  }
  if (s.arena === "dragon") {
    if (now % 4 === 0) add("gold", choose(empty()), 0, 8);
    if (now % 8 === 4) {
      const rank = 1 + Math.floor(h.random(s) * 8);
      for (const file of files) add("dragon", file + rank, 4, 1);
    }
  }
  if (s.arena === "ice" && a.type === "move" && s.position[a.to]) {
    const [x, y] = xy(a.from),
      [u, v] = xy(a.to),
      next = square(u + Math.sign(u - x), v + Math.sign(v - y));
    if (
      next &&
      !s.position[next] &&
      !(s.position[a.to].type === "p" && /[18]$/.test(next))
    ) {
      const snapshot = {
        position: structuredClone(s.position),
        pieces: structuredClone(s.pieces),
        castling: s.castling,
      };
      try {
        h.relocate(s, a.to, next, c, false);
        if (h.inCheck(s, c)) Object.assign(s, snapshot);
        else s.arenaNotice = `Eis: ${a.to} → ${next}`;
      } catch {
        Object.assign(s, snapshot);
      }
    }
  }
  if (s.arena === "graveyard")
    for (const dead of s._capturedEvents || []) {
      if (dead.meta.ephemeral || h.random(s) >= 0.2) continue;
      const rank = dead.color === "w" ? "2" : "7",
        q = choose(
          [...files].map((f) => f + rank).filter((q) => !s.position[q]),
        );
      if (q) {
        h.place(s, q, "p", dead.color, s.decks[dead.color].p, {
          ephemeral: true,
          ghost: true,
        });
        s.arenaNotice = "Ein Geisterbauer kehrt aus dem Nebel zurück.";
      }
    }
  for (const t of s.terrain) {
    if (t.starts > now) continue;
    const piece = s.position[t.square];
    if (
      ["fire", "dragon", "collapse"].includes(t.kind) &&
      piece &&
      piece.type !== "k"
    )
      h.capture(s, t.square, piece.color === "w" ? "b" : "w", true);
    if (
      ["treasure", "gold"].includes(t.kind) &&
      a.to === t.square &&
      piece?.color === c
    ) {
      s.mana[c] = Math.min(10, s.mana[c] + 2);
      t.until = now;
      s.arenaNotice = "Ein Schatzfeld schenkt dir zwei Manakristalle.";
    }
  }
}
