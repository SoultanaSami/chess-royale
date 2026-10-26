import {
  ALL_CARDS,
  PIECES,
  SPELLS,
  CHESTS,
  ARENAS,
  RARITIES,
} from "/shared/catalog.js";
const esc = (s) =>
  String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const glyph = { k: "♚", q: "♛", r: "♜", b: "♝", n: "♞", p: "♟", spell: "✦" };
const chestArt = (type) =>
  `<div class="treasure-chest chest-${type}"><div class="chest-glow"></div><div class="chest-lid"></div><div class="chest-base"><span>✦</span></div></div>`;
const remaining = (item, now) =>
  Math.max(0, Math.ceil((item.readyAt - now) / 1000));
const duration = (s) =>
  s > 59 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${s}s`;
export function createProgressUI({
  ui,
  request,
  render,
  toast,
  sound,
  vibrate,
}) {
  let timer, holdTimer;
  async function load(paint = true) {
    try {
      ui.progress = await request("/api/progression");
      ui.profile = ui.progress.profile;
      ui.serverOffset = ui.progress.serverTime - Date.now();
      if (paint) render();
    } catch (error) {
      if (paint) toast(error.message, true);
    }
  }
  function page(tab) {
    const profile = ui.profile,
      p = ui.progress,
      now = Date.now() + (ui.serverOffset || 0);
    if (tab === "leaderboard") return null;
    if (!p)
      return '<section class="page-intro"><h1>Die Schatzkammer öffnet …</h1></section>';
    if (tab === "chests")
      return `<section class="page-intro"><span class="overline">SCHÄTZE DEINES KÖNIGREICHS</span><h1>Die Truhenkammer</h1><p>Jedes Schloss verbirgt eine neue Geschichte.</p></section><div class="chest-grid">${profile.chests
        .map((item, slot) => {
          if (!item)
            return `<div class="chest-slot empty"><span>＋</span><strong>Freier Platz</strong><small>Gewinne eine Partie oder besuche die Schatzkammer.</small></div>`;
          const def = CHESTS.find((c) => c.id === item.type),
            seconds = item.status === "opening" ? remaining(item, now) : null,
            pity = profile.pity[item.type] || { epic: 0, legendary: 0 };
          return `<article class="chest-slot">${chestArt(item.type)}<h3>${def.name}</h3><span class="chest-time" data-ready="${item.readyAt || 0}">${seconds === null ? `${def.seconds / 60} Minuten` : seconds ? duration(seconds) : "Bereit zum Öffnen"}</span><button class="${seconds === 0 ? "primary" : "secondary"}-button" data-action="progress-${seconds === null ? "start" : "reveal"}" data-slot="${slot}">${seconds === null ? "Aufschließen" : seconds ? "Beschleunigen" : "Siegel brechen"}</button>${seconds === null ? `<button class="text-button" data-action="progress-reveal" data-slot="${slot}">Sofort · ${def.gems} ◈</button>` : ""}<small>Garantiert episch: ≤ ${def.pityEpic - pity.epic}<br>Legendär: ≤ ${def.pityLegendary - pity.legendary}</small></article>`;
        })
        .join(
          "",
        )}</div><p class="page-footnote">Ein Schloss kann gleichzeitig aufschließen. Ein Sieg bringt eine Truhe, wenn ein Platz frei ist.</p><section class="collection-section"><div class="section-heading"><h2>Deine Sammlung</h2><span>${Object.keys(profile.collection).length}/${ALL_CARDS.length}</span></div><div class="collection-grid">${ALL_CARDS.map(
        (card) => {
          const owned = profile.collection[card.id];
          return `<article class="collection-card ${owned ? "" : "unowned"}" data-rarity="${card.rarity}" style="--rarity:${RARITIES[card.rarity].color}"><span class="collection-glyph">${glyph[card.role]}</span><strong>${esc(card.name)}</strong><small>${owned ? `Stufe ${owned.level} · ${owned.fragments} Fragmente` : "Noch unentdeckt"}</small>${owned ? `<button class="text-button" data-action="progress-upgrade" data-id="${card.id}" ${owned.level === 10 ? "disabled" : ""}>${owned.level === 10 ? "MAXIMAL" : `↑ ${owned.level * 100} Gold · ${owned.level * 10} ✧`}</button>` : ""}</article>`;
        },
      ).join(
        "",
      )}</div><p class="page-footnote">Jede Stufe erhöht die Runenresonanz um 10 %. Alle zehn gesammelten Resonanzpunkte entsteht zusätzliches Mana.</p></section>`;
    if (tab === "shop")
      return `<section class="page-intro"><span class="overline">HANDEL UNTER ALTEN BALKEN</span><h1>Die Schatzkammer</h1><p>Alles wird erspielt. Kein echtes Geld.</p></section><div class="daily-banner"><div><strong>Dein täglicher Segen</strong><p>Gold, 5 Mondsteine und Saisonfortschritt.</p></div><button class="primary-button" data-action="progress-login" ${p.loginAvailable ? "" : "disabled"}>${p.loginAvailable ? "Abholen" : "Abgeholt"}</button></div><section class="progress-section"><h2>Heutige Angebote</h2><div class="offer-grid">${p.offers.map((offer) => `<article class="offer-card">${offer.kind === "chest" ? chestArt(offer.chestId) : `<span class="offer-glyph">${glyph[ALL_CARDS.find((c) => c.id === offer.cardId)?.role]}</span>`}<h3>${esc(offer.name)}</h3><button class="secondary-button" data-action="progress-buy" data-id="${offer.id}" ${offer.purchased ? "disabled" : ""}>${offer.purchased ? "Erworben" : `${offer.price} Gold`}</button></article>`).join("")}</div></section><section class="progress-section"><h2>Tägliche Aufgaben</h2>${p.quests.map((q) => `<article class="quest-row"><div><strong>${q.name}</strong><p>${q.description} · ${Math.min(q.progress, q.target)}/${q.target}</p><progress value="${q.progress}" max="${q.target}"></progress></div><button class="secondary-button" data-action="progress-quest" data-id="${q.id}" ${q.claimed || q.progress < q.target ? "disabled" : ""}>${q.claimed ? "✓" : `${q.gold} Gold`}</button></article>`).join("")}</section><section class="progress-section"><div class="section-heading"><h2>Pfad der Krone</h2><span>${p.season.xp} XP</span></div><p class="fine-print">Saison bis ${new Date(p.season.endsAt).toLocaleDateString("de-DE")}. Zwei Belohnungsreihen, ein gemeinsamer Weg.</p>${p.season.premium ? '<p class="pass-active">✦ Königspfad aktiviert</p>' : '<button class="primary-button" data-action="progress-pass-buy">Königspfad · 200 Mondsteine</button>'}<div class="pass-track">${p.season.tiers.map((t) => `<article><b>Stufe ${t.tier} · ${t.xp} XP</b><button class="secondary-button" data-action="progress-pass-claim" data-tier="${t.tier}" data-track="free" ${p.season.xp < t.xp || p.season.claimed.includes(`free-${t.tier}`) ? "disabled" : ""}>Gratis · ${t.gold} Gold ${p.season.claimed.includes(`free-${t.tier}`) ? "✓" : ""}</button><button class="secondary-button premium" data-action="progress-pass-claim" data-tier="${t.tier}" data-track="premium" ${!p.season.premium || p.season.xp < t.xp || p.season.claimed.includes(`premium-${t.tier}`) ? "disabled" : ""}>Krone · ${t.gems} ◈ ${p.season.claimed.includes(`premium-${t.tier}`) ? "✓" : ""}</button></article>`).join("")}</div></section>`;
    if (tab === "arenas")
      return `<section class="page-intro"><span class="overline">ACHT ORTE. ACHT LEGENDEN.</span><h1>Die Königreiche</h1><p>Deine Trophäen öffnen neue Wege. Jedes Brett birgt eigene Geheimnisse.</p></section><div class="arena-list">${ARENAS.map((a, i) => `<article class="arena-card ${a.id === profile.arena ? "selected" : ""}" style="--arena:${a.color}"><div class="arena-number">${["I", "II", "III", "IV", "V", "VI", "VII", "VIII"][i]}</div><div><span class="overline">${a.trophies} TROPHÄEN</span><h2>${a.name}</h2><p>${a.description}</p><button class="secondary-button" data-action="progress-arena" data-id="${a.id}" ${profile.trophies < a.trophies || profile.arena === a.id ? "disabled" : ""}>${profile.arena === a.id ? "Deine Arena" : profile.trophies < a.trophies ? "Noch verschlossen" : "Arena betreten"}</button></div></article>`).join("")}</div>`;
    return null;
  }
  function modal() {
    const m = ui.modal;
    if (m?.type !== "treasure") return null;
    if (!m.loot) {
      const def = CHESTS.find((c) => c.id === ui.profile.chests[m.slot]?.type);
      if (!def) return "";
      const item = ui.profile.chests[m.slot],
        left =
          item.status === "locked"
            ? def.seconds
            : remaining(item, Date.now() + (ui.serverOffset || 0)),
        price = left
          ? Math.max(1, Math.ceil((left / def.seconds) * def.gems))
          : 0;
      return `<div class="chest-opening sealed">${chestArt(def.id)}<h2>${def.name}</h2><p>${price ? `Sofort öffnen kostet ${price} Mondsteine.` : "Das Siegel ist bereit."}</p><button class="primary-button" data-action="progress-crack" data-slot="${m.slot}" data-hold="true">Antippen oder halten zum Öffnen</button></div>`;
    }
    const card = m.loot.cards[m.index || 0];
    const last = (m.index || 0) === m.loot.cards.length - 1;
    return `<div class="chest-opening opened ${card.rarity === "legendary" ? "legendary-drop" : ""}" style="--rarity:${RARITIES[card.rarity].color}"><div class="loot-rays"></div><span class="overline">${RARITIES[card.rarity].name} · ${(m.index || 0) + 1}/${m.loot.cards.length}</span><div class="loot-card" data-rarity="${card.rarity}"><span>${glyph[card.role]}</span><h2>${card.name}</h2><p>${card.description}</p><strong>${card.duplicate ? `+${card.fragments} Fragmente` : "NEUE KARTE ENTDECKT"}</strong></div><p>+${m.loot.gold} Gold aus der Truhe</p><button class="primary-button" data-action="progress-next">${last ? "In die Sammlung" : "Nächste Karte"}</button></div>`;
  }
  async function handle(action, data) {
    if (action === "progress-reveal") {
      ui.modal = { type: "treasure", slot: Number(data.slot) };
      render();
      return;
    }
    if (action === "progress-next") {
      if (ui.modal.index + 1 >= ui.modal.loot.cards.length) ui.modal = null;
      else ui.modal.index++;
      render();
      sound(
        ui.modal?.loot?.cards[ui.modal.index].rarity === "legendary"
          ? "legendary"
          : "move",
      );
      return;
    }
    if (ui.busy || (action === "progress-crack" && ui.modal?.loot)) return;
    ui.busy = true;
    try {
      let path,
        body = {};
      if (action === "progress-start") {
        path = "/api/chests/start";
        body = { slot: Number(data.slot) };
      }
      if (action === "progress-crack") {
        path = "/api/chests/open";
        body = { slot: Number(data.slot), boost: true };
      }
      if (action === "progress-buy") {
        path = "/api/shop/buy";
        body = { offerId: data.id };
      }
      if (action === "progress-upgrade") {
        path = "/api/upgrade";
        body = { cardId: data.id };
      }
      if (action === "progress-login") path = "/api/login/claim";
      if (action === "progress-quest") {
        path = "/api/quests/claim";
        body = { questId: data.id };
      }
      if (action === "progress-pass-buy") path = "/api/pass/buy";
      if (action === "progress-pass-claim") {
        path = "/api/pass/claim";
        body = { tier: Number(data.tier), track: data.track };
      }
      if (action === "progress-arena") {
        path = "/api/arena";
        body = { arena: data.id };
      }
      if (!path) return;
      if (action === "progress-crack") {
        document.querySelector(".chest-opening")?.classList.add("breaking");
        await new Promise((r) => setTimeout(r, 650));
      }
      const result = await request(path, body);
      ui.progress = result;
      ui.profile = result.profile;
      ui.serverOffset = result.serverTime - Date.now();
      if (result.loot) {
        ui.modal = { type: "treasure", loot: result.loot, index: 0 };
        vibrate();
        sound(
          result.loot.cards[0].rarity === "legendary" ? "legendary" : "capture",
        );
      } else
        toast(
          action === "progress-upgrade"
            ? "Deine Karte ist stärker geworden."
            : "In deinem Königreich gespeichert.",
        );
    } catch (error) {
      toast(error.message, true);
    } finally {
      ui.busy = false;
      render();
    }
  }
  function startTimers() {
    clearInterval(timer);
    timer = setInterval(() => {
      if (ui.tab !== "chests" || ui.modal) return;
      document.querySelectorAll("[data-ready]").forEach((el) => {
        const at = Number(el.dataset.ready);
        if (at) {
          const left = Math.max(
            0,
            Math.ceil((at - Date.now() - (ui.serverOffset || 0)) / 1000),
          );
          if (!left && !el.dataset.done) {
            el.dataset.done = "1";
            load();
          } else el.textContent = left ? duration(left) : "Bereit zum Öffnen";
        }
      });
    }, 1000);
    document.addEventListener("pointerdown", (e) => {
      const b = e.target.closest("[data-hold]");
      if (!b) return;
      b.classList.add("charging");
      holdTimer = setTimeout(() => handle("progress-crack", b.dataset), 650);
    });
    for (const type of ["pointerup", "pointercancel"])
      document.addEventListener(type, () => {
        clearTimeout(holdTimer);
        document.querySelector(".charging")?.classList.remove("charging");
      });
  }
  return { page, modal, handle, load, startTimers };
}
