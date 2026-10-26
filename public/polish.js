import { TUTORIAL } from "/shared/catalog.js";
import { translateDOM } from "/translations.js";
const esc = (s) =>
  String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
export function createPolish({
  ui,
  request,
  render,
  toast,
  persist,
  startMatch,
  performAction,
}) {
  let musicContext,
    musicTimer,
    ambientSource,
    ambientGain,
    lastArena = "";
  let pendingSettings = Promise.resolve();
  let settingsRevision = 0;
  function prefs() {
    return (
      ui.profile?.settings || {
        sound: true,
        music: false,
        vibration: true,
        quality: "high",
        language: "de",
        battery: false,
        colorblind: false,
        largeText: false,
      }
    );
  }
  function settings() {
    const p = prefs();
    const toggle = (id, name, description) =>
      `<div class="setting-row"><div class="setting-copy"><strong>${name}</strong><span>${description}</span></div><button class="toggle ${p[id] ? "on" : ""}" data-action="pref-toggle" data-key="${id}" role="switch" aria-checked="${Boolean(p[id])}" aria-label="${name}"></button></div>`;
    return `${toggle("sound", "Spielklänge", "Holz, Stahl und leise Runenklänge.")}${toggle("music", "Musik & Atmosphäre", "Laute, Flöte, Feuer und Wind deiner Arena.")}${toggle("vibration", "Vibration", "Haptisches Feedback bei Zügen und Truhen.")}${toggle("battery", "Akkuschonmodus", "Weniger Effekte, keine Hintergrundmusik.")}${toggle("colorblind", "Farbenblind-Modus", "Blau und Pergament mit deutlichen Zielmarkierungen.")}${toggle("largeText", "Große Schrift", "Lesbarere Texte und Bedienelemente.")}<label class="preference-select"><span>Grafikqualität</span><select data-pref="quality"><option value="high" ${p.quality === "high" ? "selected" : ""}>Hoch</option><option value="low" ${p.quality === "low" ? "selected" : ""}>Reduziert</option></select></label><label class="preference-select"><span>Sprache</span><select data-pref="language"><option value="de" ${p.language === "de" ? "selected" : ""}>Deutsch</option><option value="en" ${p.language === "en" ? "selected" : ""}>English</option></select></label><label class="preference-select"><span>Dein Name</span><input id="player-name" maxlength="24" value="${esc(ui.profile.name)}" autocomplete="off"></label><button class="secondary-button" data-action="pref-name">Namen speichern</button><p class="fine-print">Dein Gastprofil bleibt auf diesem Gerät gespeichert. Alle Inhalte sind mit Spielgeld erhältlich.</p>${["localhost", "127.0.0.1", "[::1]"].includes(location.hostname) ? '<button class="secondary-button" data-action="dev">Entwicklerwerkzeuge</button>' : ""}`;
  }
  function apply() {
    if (!ui.profile) return;
    const p = prefs();
    ui.sound = p.sound;
    ui.vibration = p.vibration;
    document.documentElement.lang = p.language || "de";
    document.body.classList.toggle("battery-mode", Boolean(p.battery));
    document.body.classList.toggle("low-quality", p.quality === "low");
    document.body.classList.toggle("colorblind", Boolean(p.colorblind));
    document.body.classList.toggle("large-text", Boolean(p.largeText));
    translateDOM(document.querySelector("#app"), p.language);
    ambient();
  }
  async function save(next) {
    ui.profile.settings = { ...prefs(), ...next };
    const snapshot = { ...ui.profile.settings };
    const revision = ++settingsRevision;
    ui.preferencesSaving = true;
    persist();
    apply();
    render();
    pendingSettings = pendingSettings.then(async () => {
      try {
        const result = await request("/api/settings", { settings: snapshot });
        if (revision === settingsRevision) {
          ui.profile.settings = result.profile.settings;
          persist();
        }
      } catch (e) {
        toast(e.message, true);
      } finally {
        if (revision === settingsRevision) ui.preferencesSaving = false;
        render();
      }
    });
    return pendingSettings;
  }
  async function handle(action, data) {
    if (action === "pref-toggle")
      return save({ [data.key]: !prefs()[data.key] });
    if (action === "pref-name") {
      try {
        const name = document.querySelector("#player-name").value;
        const result = await request("/api/settings", { name });
        ui.profile.name = result.profile.name;
        render();
        toast("Dein Name wurde gespeichert.");
      } catch (e) {
        toast(e.message, true);
      }
      return;
    }
    if (action === "tutorial-start") {
      ui.tutorialRequested = true;
      await startMatch();
      return;
    }
    if (action === "tutorial-finish") return performAction({ type: "resign" });
  }
  function home() {
    const lesson = Math.min(3, (ui.profile?.tutorial || 0) + 1);
    if (ui.profile?.tutorial >= 3)
      return '<div class="tutorial-complete">✦ Eldrins Lehrpfad abgeschlossen</div>';
    return `<article class="wizard-invitation"><img src="/art/eldrin.svg" alt="Eldrin, der alte Runenhüter" width="65" height="80" loading="lazy"><div><span class="overline">ELDRINS LEHRPFAD · ${lesson}/3</span><h3>${TUTORIAL[lesson - 1].title}</h3><p>Drei geführte Trainingspartien. Dein erster Schritt zur Krone.</p><button class="text-button" data-action="tutorial-start">Lektion beginnen →</button></div></article>`;
  }
  function guide() {
    const lesson = ui.match?.tutorial;
    if (!lesson || ui.match.state.result) return "";
    const info = TUTORIAL[lesson.lesson - 1];
    return `<aside class="wizard-guide" role="note"><img src="/art/eldrin.svg" width="47" height="58" alt="Eldrin"><div><strong>Eldrin · ${info.title}</strong><p>${lesson.goalReached ? "Gut gemacht. Spiele die Partie weiter oder schließe diese Lektion ab." : info.text}</p>${lesson.goalReached ? '<button class="text-button" data-action="tutorial-finish">Lektion abschließen</button>' : ""}</div></aside>`;
  }
  function stopMusic() {
    clearInterval(musicTimer);
    musicTimer = null;
    try {
      ambientSource?.stop();
    } catch {}
    ambientSource = null;
    if (musicContext?.state === "running") musicContext.suspend();
  }
  function ambient() {
    const p = prefs();
    if (!p.music || p.battery || document.hidden) {
      stopMusic();
      return;
    }
    if (!navigator.userActivation?.hasBeenActive && !musicContext) return;
    const arena = ui.match?.state?.arena || ui.profile?.arena || "hall";
    if (musicTimer && lastArena === arena) return;
    stopMusic();
    lastArena = arena;
    try {
      musicContext ||= new (window.AudioContext || window.webkitAudioContext)();
      musicContext.resume();
      const note = (
        freq,
        at,
        length = 0.8,
        type = "triangle",
        volume = 0.012,
      ) => {
        const o = musicContext.createOscillator(),
          g = musicContext.createGain();
        o.type = type;
        o.frequency.value = freq;
        g.gain.setValueAtTime(0.0001, at);
        g.gain.exponentialRampToValueAtTime(volume, at + 0.03);
        g.gain.exponentialRampToValueAtTime(0.0001, at + length);
        o.connect(g);
        g.connect(musicContext.destination);
        o.start(at);
        o.stop(at + length + 0.02);
      };
      const bases = {
        hall: 146.83,
        forest: 130.81,
        forge: 110,
        ice: 174.61,
        graveyard: 123.47,
        grove: 196,
        mines: 98,
        dragon: 116.54,
      };
      let step = 0;
      const melody = [1, 1.5, 1.25, 1.125, 1.5, 1.25, 1, 0];
      const phrase = () => {
        const base = bases[arena] || 146.83,
          t = musicContext.currentTime;
        note(base, t, 0.7, "triangle", 0.009);
        if (melody[step % 8])
          note(base * 2 * melody[step % 8], t + 0.12, 1.4, "sine", 0.013);
        if (step % 4 === 0) note(base / 2, t, 0.35, "sine", 0.018);
        step++;
      };
      phrase();
      musicTimer = setInterval(phrase, 1200);
      const buffer = musicContext.createBuffer(
          1,
          musicContext.sampleRate * 2,
          musicContext.sampleRate,
        ),
        samples = buffer.getChannelData(0);
      let previous = 0;
      for (let i = 0; i < samples.length; i++) {
        previous = (previous + Math.random() * 0.06 - 0.03) * 0.97;
        samples[i] = previous;
      }
      ambientSource = musicContext.createBufferSource();
      ambientSource.buffer = buffer;
      ambientSource.loop = true;
      ambientGain = musicContext.createGain();
      ambientGain.gain.value = ["forge", "dragon"].includes(arena)
        ? 0.045
        : 0.018;
      const filter = musicContext.createBiquadFilter();
      filter.type = "lowpass";
      filter.frequency.value = arena === "ice" ? 850 : 360;
      ambientSource.connect(filter);
      filter.connect(ambientGain);
      ambientGain.connect(musicContext.destination);
      ambientSource.start();
    } catch {
      stopMusic();
    }
  }
  document.addEventListener("change", (event) => {
    const key = event.target.dataset?.pref;
    if (key) save({ [key]: event.target.value });
  });
  document.addEventListener("pointerdown", () => ambient(), { once: true });
  document.addEventListener("visibilitychange", ambient);
  document.addEventListener("keydown", (event) => {
    const modal = document.querySelector('[role="dialog"]');
    if (event.key === "Tab" && modal) {
      const items = [
        ...modal.querySelectorAll("button:not(:disabled),input,select,a[href]"),
      ];
      if (!items.length) return;
      const first = items[0],
        last = items.at(-1);
      if (
        event.shiftKey &&
        (document.activeElement === first ||
          !modal.contains(document.activeElement))
      ) {
        event.preventDefault();
        last.focus();
      } else if (
        !event.shiftKey &&
        (document.activeElement === last ||
          !modal.contains(document.activeElement))
      ) {
        event.preventDefault();
        first.focus();
      }
    }
    if (
      event.target.matches("[data-square]") &&
      ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(event.key)
    ) {
      event.preventDefault();
      const buttons = [...document.querySelectorAll("[data-square]")],
        i = buttons.indexOf(event.target),
        offset = { ArrowUp: -8, ArrowDown: 8, ArrowLeft: -1, ArrowRight: 1 }[
          event.key
        ];
      buttons[Math.max(0, Math.min(63, i + offset))]?.focus();
    }
  });
  return { settings, apply, handle, home, guide };
}
