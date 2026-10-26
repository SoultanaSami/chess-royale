import { EMOTES } from "/shared/catalog.js";
const esc = (s) =>
  String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const time = (ms) =>
  `${Math.floor(Math.max(0, ms) / 60000)}:${String(Math.floor(Math.max(0, ms) / 1000) % 60).padStart(2, "0")}`;
export function createOnlineUI({
  ui,
  request,
  render,
  toast,
  persist,
  showResult,
  progress,
  sound,
}) {
  let socket,
    retry,
    heartbeat,
    reconnectAttempt = 0,
    manuallyOffline = false;
  ui.connection = "connecting";
  function connect() {
    if (!ui.token || manuallyOffline || !navigator.onLine) return;
    if (socket && [0, 1].includes(socket.readyState)) return;
    ui.connection = "connecting";
    render();
    socket = new WebSocket(
      `${location.protocol === "https:" ? "wss:" : "ws:"}//${location.host}/ws`,
    );
    socket.onopen = () => {
      reconnectAttempt = 0;
      socket.send(JSON.stringify({ type: "auth", token: ui.token }));
      clearInterval(heartbeat);
      heartbeat = setInterval(() => {
        if (socket.readyState === 1)
          socket.send(JSON.stringify({ type: "ping" }));
      }, 20000);
    };
    socket.onmessage = (event) => {
      let msg;
      try {
        msg = JSON.parse(event.data);
      } catch {
        return;
      }
      if (msg.type === "authenticated") {
        ui.connection = "online";
        ui.profile = msg.profile;
        if (ui.match?.mode && ui.match.mode !== "training" && !ui.replay)
          send({ type: "resume", matchId: ui.match.matchId });
        const params = new URLSearchParams(location.search);
        if (params.has("room")) {
          ui.joinCode = params.get("room").toUpperCase();
          ui.tab = "multiplayer";
        }
        render();
      }
      if (msg.type === "state") {
        ui.match = msg;
        ui.replay = null;
        ui.room = null;
        ui.queued = false;
        ui.busy = false;
        ui.selection = null;
        ui.savedMatchId = msg.matchId;
        ui.tab = "game";
        persist();
        showResult();
        render();
      }
      if (
        msg.type === "clock" &&
        ui.match?.matchId === msg.matchId &&
        !ui.replay
      ) {
        ui.match.clock = msg.clock;
        updateClocks();
      }
      if (msg.type === "room") {
        ui.room = msg;
        ui.queued = false;
        ui.tab = "multiplayer";
        render();
      }
      if (msg.type === "queued") {
        ui.queued = msg.mode;
        render();
      }
      if (msg.type === "queue-cancelled") {
        ui.queued = false;
        render();
      }
      if (msg.type === "profile") {
        ui.profile = msg.profile;
        progress.load(false).then(render);
      }
      if (msg.type === "error") {
        ui.busy = false;
        toast(msg.error, true);
      }
      if (msg.type === "tournament") {
        ui.tournament = msg.tournament;
        if (!ui.match || ui.match.state?.result) ui.tab = "multiplayer";
        render();
      }
      if (msg.type === "emote" && ui.match?.matchId === msg.matchId) {
        ui.emote = `${msg.name}: ${msg.text}`;
        render();
        setTimeout(() => {
          ui.emote = "";
          render();
        }, 4000);
        sound();
      }
    };
    socket.onclose = () => {
      clearInterval(heartbeat);
      ui.connection = "offline";
      ui.busy = false;
      render();
      if (!manuallyOffline) {
        clearTimeout(retry);
        retry = setTimeout(
          connect,
          Math.min(8000, 700 * 2 ** reconnectAttempt++),
        );
      }
    };
    socket.onerror = () => {
      ui.connection = "offline";
      render();
    };
  }
  async function send(msg) {
    if (manuallyOffline || ui.network === "offline")
      throw new Error(
        "Du bist offline. Deine Partie wartet auf die Wiederverbindung.",
      );
    if (ui.network === "slow") await new Promise((r) => setTimeout(r, 1800));
    if (socket?.readyState !== 1)
      throw new Error("Die Verbindung wird gerade wiederhergestellt.");
    socket.send(JSON.stringify(msg));
  }
  function setNetwork(mode) {
    manuallyOffline = mode === "offline";
    if (manuallyOffline) {
      clearTimeout(retry);
      socket?.close();
    } else connect();
  }
  function updateClocks() {
    if (!ui.match?.clock) return;
    for (const c of ["w", "b"])
      document
        .querySelectorAll(`[data-clock="${c}"]`)
        .forEach((el) => (el.textContent = time(ui.match.clock[c])));
  }
  async function load() {
    try {
      const result = await request("/api/leaderboard");
      ui.ladder = result.players;
      const replay = await request("/api/replays");
      ui.replays = replay.matches;
      render();
    } catch (e) {
      toast(e.message, true);
    }
  }
  function page(tab) {
    if (tab === "leaderboard")
      return `<section class="page-intro"><span class="overline">NAMEN, DIE BLEIBEN</span><h1>Die Chronik der Krone</h1><p>Trophäen entscheiden den Rang. Elo misst deine Spielstärke.</p></section><div class="ladder">${(ui.ladder || []).map((p) => `<article class="ladder-row ${p.id === ui.profile.id ? "you" : ""}"><b>${p.rank <= 3 ? ["♛", "♜", "♞"][p.rank - 1] : p.rank}</b><div><strong>${esc(p.name)}</strong><small>${p.elo} Elo · ${p.wins} Siege</small></div><span>${p.trophies} ♜</span></article>`).join("") || "<p>Die Chronik wird geladen …</p>"}</div><section class="progress-section"><h2>Deine Replays</h2>${(ui.replays || []).map((m) => `<button class="replay-row" data-action="online-replay" data-id="${m.id}"><span>${esc(m.mode)} · ${new Date(m.createdAt).toLocaleDateString("de-DE")}</span><b>${m.result ? "Ansehen →" : "Laufende Partie →"}</b></button>`).join("") || '<p class="fine-print">Deine ersten Partien erscheinen hier.</p>'}</section>`;
    if (tab !== "multiplayer") return null;
    const t = ui.tournament;
    return `<section class="page-intro"><span class="overline">DIE TORE STEHEN OFFEN</span><h1>Die Duellhalle</h1><p><span class="connection-dot ${ui.connection}"></span>${ui.connection === "online" ? "Mit der Arena verbunden" : "Verbindung wird wiederhergestellt …"}</p></section><div class="online-modes"><button class="online-mode" data-action="online-queue" data-mode="ranked"><span>♛</span><strong>Ranglistenduell</strong><small>Gegner mit ähnlichen Trophäen · 5 + 3</small></button><button class="online-mode" data-action="online-queue" data-mode="chaos"><span>✦</span><strong>Runenchaos</strong><small>Zufälliges gemeinsames Deck · Stufe 1</small></button></div>${ui.queued ? `<div class="queue-banner"><span class="busy-dot"></span> Ein würdiger Gegner wird gesucht …<button class="text-button" data-action="online-cancel">Suche beenden</button></div>` : ""}<section class="progress-section"><h2>Unter Freunden</h2><button class="primary-button" data-action="online-create">Duellraum eröffnen</button>${ui.room ? `<div class="room-ticket"><span class="overline">DEIN RAUMCODE</span><strong>${ui.room.code}</strong><p>Öffne das zweite Handy und tritt mit diesem Code bei.</p><button class="secondary-button" data-action="online-share">Einladung teilen</button></div>` : ""}<label class="code-label" for="room-code">Raum- oder Turniercode</label><input class="code-input" id="room-code" placeholder="ABC123" maxlength="6" value="${esc(ui.joinCode || "")}" autocomplete="off"><div class="online-buttons"><button class="secondary-button" data-action="online-join">Beitreten</button><button class="secondary-button" data-action="online-watch">Zuschauen</button></div></section><section class="progress-section"><h2>Das Viererturnier</h2><p class="fine-print">Zwei Halbfinals und ein Finale. Der Sieger erhält 500 Gold. Bei Remis zieht die zuerst gesetzte Seite weiter.</p><div class="online-buttons"><button class="secondary-button" data-action="online-tournament-create">Turnier gründen</button><button class="secondary-button" data-action="online-tournament-join">Mit Code beitreten</button></div>${t ? `<div class="room-ticket"><span class="overline">TURNIER ${t.code}</span><strong>${t.status === "waiting" ? `${t.participants.length} / 4` : "Das Turnier läuft"}</strong><p>${t.participants.map((p) => esc(p.name)).join(" · ")}</p></div><div class="bracket">${t.bracket.map((m, i) => `<article><span>${i === 2 ? "FINALE" : `HALBFINALE ${i + 1}`}</span><p>${m.players.map((p) => esc(p.name)).join(" ⚔ ")}</p><small>${m.result ? (m.result.winner === null ? "Remis · erste Setzung weiter" : `${esc(m.players[m.result.winner === "w" ? 0 : 1].name)} gewinnt`) : "Partie läuft"}</small><button class="text-button" data-action="online-watch-code" data-code="${m.code}">Zuschauen</button></article>`).join("")}${t.champion ? `<p>♛ Sieger: ${esc(t.participants.find((p) => p.id === t.champion)?.name)}</p>` : ""}</div>` : ""}</section><button class="text-button online-home" data-action="tab" data-tab="home">Zurück in die Burghalle</button>`;
  }
  function controls() {
    if (ui.replay)
      return `<div class="replay-controls"><button class="secondary-button" data-action="online-replay-step" data-step="-1" ${ui.replay.index === 0 ? "disabled" : ""}>←</button><span>Zug ${ui.replay.index} / ${ui.replay.frames.length - 1}</span><button class="secondary-button" data-action="online-replay-step" data-step="1" ${ui.replay.index >= ui.replay.frames.length - 1 ? "disabled" : ""}>→</button><button class="text-button" data-action="tab" data-tab="leaderboard">Chronik</button></div>`;
    if (!ui.match || ui.match.mode === "training") return "";
    return `<div class="clock-bar"><span class="connection-dot ${ui.connection}"></span><span>${ui.match.color === null ? "ZUSCHAUER" : ui.connection === "online" ? "LIVE" : "VERBINDE …"}</span><b data-clock="w">${time(ui.match.clock?.w)}</b><small>Weiß / Schwarz</small><b data-clock="b">${time(ui.match.clock?.b)}</b></div>${ui.emote ? `<div class="emote-bubble">${esc(ui.emote)}</div>` : ""}<div class="emote-controls">${
      ui.match.color
        ? EMOTES.slice(0, 3)
            .map(
              (text) =>
                `<button class="text-button" data-action="online-emote" data-text="${text}">${text}</button>`,
            )
            .join("")
        : ""
    }</div>`;
  }
  async function action(action) {
    ui.busy = true;
    render();
    try {
      await send({
        type: "action",
        matchId: ui.match.matchId,
        version: ui.match.state.version,
        requestId:
          globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`,
        action,
      });
    } catch (e) {
      ui.busy = false;
      toast(e.message, true);
    }
  }
  async function handle(name, data) {
    try {
      const value = document
        .querySelector("#room-code")
        ?.value?.trim()
        .toUpperCase();
      if (value) ui.joinCode = value;
      if (name === "online-open") {
        ui.tab = "multiplayer";
        render();
        return;
      }
      if (name === "online-queue")
        return await send({ type: "queue", mode: data.mode });
      if (name === "online-cancel") return await send({ type: "cancel-queue" });
      if (name === "online-create") return await send({ type: "room-create" });
      if (name === "online-join")
        return await send({ type: "room-join", code: ui.joinCode });
      if (name === "online-watch" || name === "online-watch-code")
        return await send({ type: "watch", code: data.code || ui.joinCode });
      if (name === "online-tournament-create")
        return await send({ type: "tournament-create" });
      if (name === "online-tournament-join")
        return await send({ type: "tournament-join", code: ui.joinCode });
      if (name === "online-emote")
        return await send({
          type: "emote",
          matchId: ui.match.matchId,
          text: data.text,
        });
      if (name === "online-share") {
        const url = `${location.origin}/?frame=off&room=${ui.room.code}`;
        if (navigator.share)
          await navigator.share({
            title: "Chess Royale · Duell",
            text: `Mein Raumcode: ${ui.room.code}`,
            url,
          });
        else if (navigator.clipboard) {
          await navigator.clipboard.writeText(url);
          toast("Einladungslink kopiert.");
        } else prompt("Einladungslink", url);
        return;
      }
      if (name === "online-replay") {
        const result = await request("/api/replay/" + data.id);
        ui.replay = { ...result, index: 0 };
        ui.match = {
          matchId: result.matchId,
          state: result.frames[0],
          color: null,
          mode: "replay",
          players: result.players,
        };
        ui.tab = "game";
        render();
        return;
      }
      if (name === "online-replay-step") {
        ui.replay.index = Math.max(
          0,
          Math.min(
            ui.replay.frames.length - 1,
            ui.replay.index + Number(data.step),
          ),
        );
        ui.match.state = ui.replay.frames[ui.replay.index];
        render();
        return;
      }
    } catch (e) {
      toast(e.message, true);
    }
  }
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) {
      connect();
      if (
        socket?.readyState === 1 &&
        ui.match?.mode !== "training" &&
        ui.match?.matchId &&
        !ui.replay
      )
        send({ type: "resume", matchId: ui.match.matchId }).catch(() => {});
    }
  });
  window.addEventListener("online", connect);
  return { connect, page, controls, handle, action, setNetwork, load };
}
