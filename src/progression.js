import { randomInt, randomUUID, createHash } from "node:crypto";
import {
  ALL_CARDS,
  PIECES,
  SPELLS,
  CHESTS,
  RARITIES,
  ARENAS,
  BALANCE,
} from "../shared/catalog.js";
const requireThat = (condition, message) => {
  if (!condition) throw new Error(message);
};
const dayOf = (now) => new Date(now).toISOString().slice(0, 10);
export const QUESTS = [
  {
    id: "moves",
    name: "Der erste Plan",
    description: "Spiele 10 Aktionen.",
    stat: "moves",
    target: 10,
    gold: 120,
    xp: 20,
  },
  {
    id: "summons",
    name: "Ruf der Verstärkung",
    description: "Beschwöre 3 Figuren.",
    stat: "summons",
    target: 3,
    gold: 160,
    xp: 25,
  },
  {
    id: "wins",
    name: "Für die Holzhalle",
    description: "Gewinne eine Partie.",
    stat: "wins",
    target: 1,
    gold: 200,
    xp: 30,
  },
];
export function refreshProgress(profile, now = Date.now()) {
  const day = dayOf(now);
  if (profile.quests.day !== day)
    profile.quests = { day, claimed: [], baseline: { ...profile.stats } };
  if (profile.shopDay !== day) {
    profile.shopDay = day;
    profile.purchases = [];
  }
  const seasonId = String(Math.floor(now / (BALANCE.seasonDays * 86400000)));
  if (profile.season.id !== seasonId) {
    if (profile.season.id) {
      profile.gold += Math.floor(profile.trophies / 2);
      profile.trophies = Math.floor(profile.trophies * 0.6);
      profile.lastSeasonReward = {
        gold: Math.floor(profile.trophies / 1.2),
        at: now,
      };
    }
    profile.season = { id: seasonId, xp: 0, premium: false, claimed: [] };
  }
  profile.unlocked = Object.keys(profile.collection);
  profile.level = 1 + Math.floor(profile.stats.matches / 10);
  return profile;
}
function cardPool(chest) {
  return chest.pool === "royal"
    ? ALL_CARDS.filter((c) => c.role === "k" || c.role === "spell")
    : ALL_CARDS;
}
function weighted(chest, random = () => randomInt(1000000) / 1000000) {
  let roll = random() * Object.values(chest.weights).reduce((a, b) => a + b, 0);
  for (const [rarity, weight] of Object.entries(chest.weights)) {
    roll -= weight;
    if (roll < 0) return rarity;
  }
  return "common";
}
export function grantCard(profile, id) {
  const card = ALL_CARDS.find((c) => c.id === id);
  requireThat(card, "Unbekannte Karte.");
  const duplicate = Boolean(profile.collection[id]);
  if (duplicate)
    profile.collection[id].fragments += RARITIES[card.rarity].fragments;
  else profile.collection[id] = { level: 1, fragments: 0 };
  profile.unlocked = Object.keys(profile.collection);
  return {
    ...card,
    duplicate,
    fragments: duplicate ? RARITIES[card.rarity].fragments : 0,
  };
}
export function rollChest(
  profile,
  type,
  random = () => randomInt(1000000) / 1000000,
) {
  const chest = CHESTS.find((c) => c.id === type);
  requireThat(chest, "Unbekannte Truhe.");
  const pity = profile.pity[type] || { epic: 0, legendary: 0 };
  pity.epic++;
  pity.legendary++;
  const guarantee =
    pity.legendary >= chest.pityLegendary
      ? "legendary"
      : pity.epic >= chest.pityEpic
        ? "epic"
        : null;
  const cards = [];
  for (let i = 0; i < chest.cards; i++) {
    const rarity = i === 0 && guarantee ? guarantee : weighted(chest, random);
    const pool = cardPool(chest).filter((c) => c.rarity === rarity);
    cards.push(
      grantCard(
        profile,
        pool[Math.min(pool.length - 1, Math.floor(random() * pool.length))].id,
      ),
    );
  }
  if (cards.some((c) => c.rarity === "legendary")) pity.legendary = 0;
  if (cards.some((c) => c.rarity === "epic" || c.rarity === "legendary"))
    pity.epic = 0;
  profile.pity[type] = pity;
  profile.gold += chest.gold;
  profile.stats.chests++;
  return { type, cards, gold: chest.gold, guarantee, pity: { ...pity } };
}
export function chestAction(
  profile,
  action,
  { slot, boost = false } = {},
  now = Date.now(),
) {
  requireThat(
    Number.isInteger(slot) && slot >= 0 && slot < 4,
    "Ungültiger Truhenplatz.",
  );
  const item = profile.chests[slot];
  requireThat(item, "Dieser Truhenplatz ist leer.");
  const definition = CHESTS.find((c) => c.id === item.type);
  if (action === "start") {
    requireThat(item.status === "locked", "Diese Truhe wird bereits geöffnet.");
    requireThat(
      !profile.chests.some((c) => c?.status === "opening" && c.readyAt > now),
      "Es kann nur eine Truhe gleichzeitig aufschließen.",
    );
    item.status = "opening";
    item.readyAt = now + definition.seconds * 1000;
    return { chest: item };
  }
  requireThat(action === "open", "Unbekannte Truhenaktion.");
  const remaining =
    item.status === "locked"
      ? definition.seconds * 1000
      : Math.max(0, item.readyAt - now);
  if (remaining > 0) {
    requireThat(boost, "Das Schloss braucht noch Zeit.");
    const price = Math.max(
      1,
      Math.ceil((remaining / (definition.seconds * 1000)) * definition.gems),
    );
    requireThat(profile.gems >= price, `Du benötigst ${price} Mondsteine.`);
    profile.gems -= price;
  }
  const loot = rollChest(profile, item.type);
  profile.chests[slot] = null;
  return { loot };
}
export function offersFor(profile, now = Date.now()) {
  const seed = createHash("sha256").update(dayOf(now)).digest().readUInt32LE();
  const daily = [
    PIECES[seed % PIECES.length],
    ALL_CARDS[(seed + 13) % ALL_CARDS.length],
  ];
  return [
    ...daily.map((card, i) => ({
      id: `card-${i}`,
      kind: "card",
      cardId: card.id,
      name: card.name,
      price: { common: 150, rare: 300, epic: 650, legendary: 1500 }[
        card.rarity
      ],
      purchased: profile.purchases?.includes(`card-${i}`),
    })),
    ...CHESTS.map((c) => ({
      id: `chest-${c.id}`,
      kind: "chest",
      chestId: c.id,
      name: c.name,
      price: c.price,
    })),
  ];
}
export function progressionView(profile, now = Date.now()) {
  refreshProgress(profile, now);
  return {
    profile,
    serverTime: now,
    offers: offersFor(profile, now),
    quests: QUESTS.map((q) => ({
      ...q,
      progress: Math.max(
        0,
        (profile.stats[q.stat] || 0) - (profile.quests.baseline?.[q.stat] || 0),
      ),
      claimed: profile.quests.claimed.includes(q.id),
    })),
    season: {
      ...profile.season,
      endsAt: (Number(profile.season.id) + 1) * BALANCE.seasonDays * 86400000,
      tiers: Array.from({ length: 10 }, (_, i) => ({
        tier: i + 1,
        xp: (i + 1) * 50,
        gold: (i + 1) * 60,
        gems: 10 + (i + 1) * 2,
      })),
    },
    loginAvailable: profile.loginDay !== dayOf(now),
    arenas: ARENAS,
  };
}
export function progressAction(profile, path, data, now = Date.now()) {
  refreshProgress(profile, now);
  let extra = {};
  if (path === "/api/chests/start" || path === "/api/chests/open")
    extra = chestAction(
      profile,
      path.endsWith("start") ? "start" : "open",
      data,
      now,
    );
  else if (path === "/api/shop/buy") {
    const offer = offersFor(profile, now).find((o) => o.id === data.offerId);
    requireThat(offer, "Dieses Angebot ist nicht verfügbar.");
    requireThat(
      !offer.purchased,
      "Du hast dieses Tagesangebot bereits abgeholt.",
    );
    requireThat(profile.gold >= offer.price, "Nicht genug Gold.");
    if (offer.kind === "chest") {
      const slot = profile.chests.findIndex((c) => !c);
      requireThat(slot !== -1, "Alle vier Truhenplätze sind belegt.");
      profile.chests[slot] = {
        id: randomUUID(),
        type: offer.chestId,
        status: "locked",
        readyAt: null,
      };
    } else {
      extra.card = grantCard(profile, offer.cardId);
      profile.purchases.push(offer.id);
    }
    profile.gold -= offer.price;
  } else if (path === "/api/upgrade") {
    const owned = profile.collection[data.cardId];
    requireThat(owned, "Diese Karte ist noch nicht freigeschaltet.");
    requireThat(
      owned.level < BALANCE.maxLevel,
      "Die höchste Stufe ist bereits erreicht.",
    );
    const gold = owned.level * BALANCE.upgradeBaseGold,
      fragments = owned.level * BALANCE.upgradeBaseFragments;
    requireThat(
      profile.gold >= gold && owned.fragments >= fragments,
      `Benötigt: ${gold} Gold und ${fragments} Fragmente.`,
    );
    profile.gold -= gold;
    owned.fragments -= fragments;
    owned.level++;
  } else if (path === "/api/login/claim") {
    requireThat(
      profile.loginDay !== dayOf(now),
      "Der heutige Login-Bonus ist bereits abgeholt.",
    );
    profile.loginStreak =
      profile.loginDay === dayOf(now - 86400000)
        ? (profile.loginStreak || 0) + 1
        : 1;
    profile.loginDay = dayOf(now);
    profile.gold += 100 + Math.min(profile.loginStreak, 7) * 20;
    profile.gems += 5;
    profile.season.xp += 15;
  } else if (path === "/api/quests/claim") {
    const quest = QUESTS.find((q) => q.id === data.questId);
    requireThat(quest, "Unbekannte Aufgabe.");
    requireThat(
      !profile.quests.claimed.includes(quest.id),
      "Diese Belohnung wurde bereits abgeholt.",
    );
    requireThat(
      profile.stats[quest.stat] - (profile.quests.baseline[quest.stat] || 0) >=
        quest.target,
      "Diese Aufgabe ist noch nicht erfüllt.",
    );
    profile.quests.claimed.push(quest.id);
    profile.gold += quest.gold;
    profile.season.xp += quest.xp;
  } else if (path === "/api/pass/buy") {
    requireThat(!profile.season.premium, "Der Saison-Pass ist bereits aktiv.");
    requireThat(
      profile.gems >= 200,
      "Der Pass kostet 200 erspielte Mondsteine.",
    );
    profile.gems -= 200;
    profile.season.premium = true;
  } else if (path === "/api/pass/claim") {
    const tier = Number(data.tier),
      track = data.track === "premium" ? "premium" : "free",
      key = `${track}-${tier}`;
    requireThat(
      Number.isInteger(tier) && tier >= 1 && tier <= 10,
      "Ungültige Saisonstufe.",
    );
    requireThat(
      profile.season.xp >= tier * 50,
      "Diese Saisonstufe ist noch nicht erreicht.",
    );
    requireThat(
      !profile.season.claimed.includes(key),
      "Diese Belohnung wurde bereits abgeholt.",
    );
    requireThat(
      track === "free" || profile.season.premium,
      "Dafür brauchst du den Saison-Pass.",
    );
    profile.season.claimed.push(key);
    if (track === "free") profile.gold += tier * 60;
    else profile.gems += 10 + tier * 2;
  } else if (path === "/api/arena") {
    const arena = ARENAS.find((a) => a.id === data.arena);
    requireThat(
      arena && profile.trophies >= arena.trophies,
      "Diese Arena ist noch verschlossen.",
    );
    profile.arena = arena.id;
  } else throw new Error("Unbekannte Fortschrittsaktion.");
  return { ...progressionView(profile, now), ...extra };
}
export function awardMatch(profile, winner, color) {
  refreshProgress(profile);
  profile.stats.matches++;
  profile.season.xp += 20;
  if (winner === color) {
    profile.stats.wins++;
    profile.gold += BALANCE.matchGold;
    profile.season.xp += 20;
    const slot = profile.chests.findIndex((c) => !c);
    if (slot >= 0)
      profile.chests[slot] = {
        id: randomUUID(),
        type: randomInt(5) === 0 ? "iron" : "wood",
        status: "locked",
        readyAt: null,
      };
  }
}
