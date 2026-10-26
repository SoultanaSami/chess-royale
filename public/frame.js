const PRESETS = [
  {
    id: "iphone",
    name: "iPhone 15",
    width: 393,
    height: 852,
    kind: "ios",
    caption: "393 × 852 · iOS",
  },
  {
    id: "pixel",
    name: "Pixel 8",
    width: 412,
    height: 915,
    kind: "android",
    caption: "412 × 915 · Android",
  },
  {
    id: "small",
    name: "Kompaktes Handy",
    width: 360,
    height: 640,
    kind: "small",
    caption: "360 × 640 · Small",
  },
  {
    id: "tablet",
    name: "Tablet",
    width: 768,
    height: 1024,
    kind: "tablet",
    caption: "768 × 1024 · Tablet",
  },
];

const ICONS = {
  phone:
    '<rect x="6" y="2" width="12" height="20" rx="3"/><path d="M10 18h4"/>',
  tablet:
    '<rect x="3" y="2" width="18" height="20" rx="3"/><path d="M11 18h2"/>',
  rotate:
    '<path d="M3 10a9 9 0 0 1 15-6l3 3M21 2v5h-5M21 14a9 9 0 0 1-15 6l-3-3M3 22v-5h5"/>',
  reload: '<path d="M20 7A9 9 0 1 0 21 13M20 2v5h-5"/>',
  camera:
    '<path d="M8 5l2-3h4l2 3h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z"/><circle cx="12" cy="13" r="4"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  arrow: '<path d="M8 5h11v11M19 5 5 19"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  wifi: '<path d="M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0M8 16a6 6 0 0 1 8 0"/><circle cx="12" cy="20" r=".7" fill="currentColor"/>',
  chevron: '<path d="m9 5 7 7-7 7"/>',
  crown: '<path d="m3 7 4 4 5-7 5 7 4-4-2 12H5zM5 22h14"/>',
  touch:
    '<path d="M9 13V5a2 2 0 0 1 4 0v6l2-1 5 3v6a3 3 0 0 1-3 3h-4l-7-7a2 2 0 0 1 3-2z"/><path d="M5 8a6 6 0 0 1 11-5"/>',
};

function icon(name, extra = "") {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" ${extra}>${ICONS[name] || ""}</svg>`;
}

function isLocal() {
  return ["localhost", "127.0.0.1", "[::1]", "::1"].includes(location.hostname);
}

/** Mount the local desktop device lab. Returns false when the game should initialize. */
export async function startFrame() {
  const params = new URLSearchParams(location.search);
  if (
    !isLocal() ||
    params.get("frame") === "off" ||
    !matchMedia("(min-width: 900px) and (pointer: fine)").matches
  )
    return false;

  const css = document.createElement("link");
  css.rel = "stylesheet";
  css.href = "/frame.css";
  document.head.append(css);
  document.title = "Chess Royale · Device Lab";
  document.body.classList.add("lab-body");
  const root = document.createElement("div");
  root.className = "lab-root";
  root.innerHTML = `
    <header class="lab-header">
      <div class="lab-brand"><span class="lab-brand-mark">${icon("crown")}</span><div><strong>CHESS <span>ROYALE</span></strong><small>THE NEXT MOVE IS YOURS</small></div></div>
      <div class="lab-environment"><span class="lab-live-dot"></span> LOCAL DEVELOPMENT <span class="lab-env-divider"></span> DEVICE LAB</div>
      <a class="lab-open" href="/?frame=off" target="_blank" rel="noopener">App öffnen ${icon("arrow")}</a>
    </header>
    <aside class="lab-sidebar" aria-label="Simulator-Einstellungen">
      <div class="lab-sidebar-intro"><span class="lab-eyebrow">DEIN SPIEL. JEDE GRÖSSE.</span><h1>Device Lab<span>.</span></h1><p>Die mobile Arena, direkt auf deinem Desktop.</p></div>
      <section class="lab-control-section"><h2>GERÄT <span>01—04</span></h2><div class="lab-presets" role="group" aria-label="Gerät auswählen">${PRESETS.map((p, i) => `<button class="lab-preset ${i === 0 ? "is-active" : ""}" data-preset="${p.id}" aria-pressed="${i === 0}"><span class="lab-preset-icon">${icon(p.kind === "tablet" ? "tablet" : "phone")}</span><span><strong>${p.name}</strong><small>${p.caption}</small></span><span class="lab-preset-check">${icon("check")}</span></button>`).join("")}</div></section>
      <section class="lab-control-section"><h2>ANSICHT</h2><div class="lab-actions"><button data-action="rotate" title="Alle Geräte drehen">${icon("rotate")}<span>Drehen</span></button><button data-action="reload" title="Spiel neu laden">${icon("reload")}<span>Neu laden</span></button><button data-action="screenshot" title="Screenshot des ersten Geräts herunterladen">${icon("camera")}<span>Screenshot</span></button></div><button class="lab-touch-toggle is-active" data-action="touch" aria-pressed="true">${icon("touch")}<span>Touch-Simulation</span><span class="lab-toggle-track" aria-hidden="true"></span></button></section>
      <section class="lab-control-section"><h2>VERBINDUNG <span class="lab-network-label">LIVE</span></h2><div class="lab-network" role="group" aria-label="Netzwerksimulation"><button data-network="normal" class="is-active" aria-pressed="true">Online</button><button data-network="slow" aria-pressed="false">Langsam</button><button data-network="offline" aria-pressed="false">Offline</button></div><p class="lab-help" id="lab-network-help">Normale Verbindung zum lokalen Spiel.</p></section>
      <section class="lab-control-section lab-session-section"><h2>MULTIPLAYER TESTEN</h2><button class="lab-add-device" data-action="second">${icon("plus")} Zweites Gerät</button><p class="lab-help">Zwei Geräte. Zwei lokale Profile.<br>Eine gemeinsame Arena.</p></section>
      <div class="lab-sidebar-bottom"><span class="lab-small-crown">${icon("crown")}</span><div>BUILT FOR THE NEXT MOVE<small>Chess Royale · Local</small></div></div>
    </aside>
    <main class="lab-workspace">
      <div class="lab-workspace-heading"><div><span class="lab-live-dot"></span><strong>Live-Vorschau</strong><span class="lab-view-caption">iPhone 15</span></div><span class="lab-viewport-note">ECHTE APP · INTERAKTIV</span></div>
      <div class="lab-preview" aria-label="Gerätevorschau"></div>
      <div class="lab-workspace-footer"><span>${icon("phone")} <span class="lab-dimension-label">393 × 852</span><span class="lab-footer-dot">·</span><span class="lab-scale-label">100 %</span></span><span>Tippen. Ziehen. Den nächsten Zug machen.</span><span class="lab-version">v1.0</span></div>
    </main>
    <div class="lab-toast" role="status" aria-live="polite"></div>`;
  document.body.replaceChildren(root);

  let preset = PRESETS[0];
  let rotated = false;
  let network = "normal";
  let touchEnabled = true;
  let toastTimer;
  let devices = [];
  const preview = root.querySelector(".lab-preview");
  const say = (text) => {
    const toast = root.querySelector(".lab-toast");
    toast.textContent = text;
    toast.classList.add("is-visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("is-visible"), 3500);
  };

  const sendNetwork = (frame) =>
    frame.contentWindow?.postMessage(
      { type: "network", mode: network },
      location.origin,
    );
  function mountDevice(id) {
    const column = document.createElement("section");
    column.className = "lab-device-column";
    column.innerHTML = `<div class="lab-device-label"><span class="lab-device-label-dot"></span><strong>${id === "one" ? "DEIN GERÄT" : "ZWEITES GERÄT"}</strong><span class="lab-device-account">Profil ${id === "one" ? "01" : "02"}</span>${id === "two" ? `<button class="lab-remove-device" aria-label="Zweites Gerät schließen">${icon("close")}</button>` : ""}</div><div class="lab-device-holder"><div class="lab-device-hardware"><span class="lab-side-button lab-side-button-a"></span><span class="lab-side-button lab-side-button-b"></span><span class="lab-side-button lab-side-button-c"></span><div class="lab-device-screen"><iframe title="Chess Royale – ${id === "one" ? "erstes" : "zweites"} Gerät" src="/?frame=off&device=${id}" allow="clipboard-write" loading="eager"></iframe><div class="lab-phone-status" aria-hidden="true"><time>9:41</time><div><svg class="lab-signal" viewBox="0 0 18 12"><path d="M1 8h2v4H1zM5 5h2v7H5zM9 2h2v10H9zM13 0h2v12h-2z" fill="currentColor"/></svg><svg class="lab-phone-wifi" viewBox="0 0 16 12"><path d="M1 3q7-6 14 0M4 6q4-4 8 0M7 9q1-1 2 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg><span class="lab-battery"><i></i></span></div></div><div class="lab-phone-camera" aria-hidden="true"><i></i></div><div class="lab-home-indicator" aria-hidden="true"></div><div class="lab-touch" aria-hidden="true"></div></div></div></div>`;
    preview.append(column);
    const frame = column.querySelector("iframe");
    const device = { id, column, frame, removeListeners: null };
    devices.push(device);
    frame.addEventListener("load", () => {
      sendNetwork(frame);
      device.removeListeners?.();
      const touch = column.querySelector(".lab-touch");
      try {
        const doc = frame.contentDocument;
        const show = (event) => {
          if (!touchEnabled) return;
          touch.style.left = `${event.clientX}px`;
          touch.style.top = `${event.clientY}px`;
          touch.classList.add("is-visible");
        };
        const hide = () => touch.classList.remove("is-visible");
        doc.addEventListener("pointerdown", show, true);
        doc.addEventListener("pointermove", show, true);
        doc.addEventListener("pointerup", hide, true);
        doc.addEventListener("pointercancel", hide, true);
        doc.addEventListener("pointerleave", hide, true);
        device.removeListeners = () => {
          doc.removeEventListener("pointerdown", show, true);
          doc.removeEventListener("pointermove", show, true);
          doc.removeEventListener("pointerup", hide, true);
          doc.removeEventListener("pointercancel", hide, true);
          doc.removeEventListener("pointerleave", hide, true);
        };
      } catch {
        /* The local preview can briefly navigate during a reload. */
      }
    });
    column
      .querySelector(".lab-remove-device")
      ?.addEventListener("click", removeSecond);
    updateDeviceLayout();
  }

  function removeSecond() {
    const second = devices.find((d) => d.id === "two");
    if (!second) return;
    second.removeListeners?.();
    second.column.remove();
    devices = devices.filter((d) => d !== second);
    const control = root.querySelector('[data-action="second"]');
    control.innerHTML = `${icon("plus")} Zweites Gerät`;
    control.setAttribute("aria-pressed", "false");
    updateDeviceLayout();
  }

  function updateDeviceLayout() {
    const width = rotated ? preset.height : preset.width;
    const height = rotated ? preset.width : preset.height;
    const bezel = preset.kind === "tablet" ? 18 : 11;
    const outerWidth = width + bezel * 2;
    const outerHeight = height + bezel * 2;
    preview.style.setProperty("--device-count", devices.length);
    const columnWidth = Math.max(
      220,
      (preview.clientWidth - 64 - (devices.length - 1) * 32) / devices.length,
    );
    const availableHeight = Math.max(230, preview.clientHeight - 72);
    const scale = Math.min(
      1,
      columnWidth / outerWidth,
      availableHeight / outerHeight,
    );
    for (const d of devices) {
      const shell = d.column.querySelector(".lab-device-hardware");
      shell.className = `lab-device-hardware lab-kind-${preset.kind}${rotated ? " is-landscape" : ""}`;
      Object.assign(shell.style, {
        width: `${outerWidth}px`,
        height: `${outerHeight}px`,
        padding: `${bezel}px`,
        transform: `scale(${scale})`,
      });
      Object.assign(d.column.querySelector(".lab-device-holder").style, {
        width: `${outerWidth * scale}px`,
        height: `${outerHeight * scale}px`,
      });
      Object.assign(d.frame.style, {
        width: `${width}px`,
        height: `${height}px`,
      });
      Object.assign(d.column.querySelector(".lab-device-screen").style, {
        width: `${width}px`,
        height: `${height}px`,
      });
    }
    root.querySelector(".lab-dimension-label").textContent =
      `${width} × ${height}`;
    root.querySelector(".lab-scale-label").textContent =
      `${Math.round(scale * 100)} %`;
    root.querySelector(".lab-view-caption").textContent =
      `${preset.name}${rotated ? " · Querformat" : ""}${devices.length > 1 ? " · 2 Geräte" : ""}`;
    updateClocks();
  }

  function updateClocks() {
    const current = new Intl.DateTimeFormat("de-DE", {
      hour: "2-digit",
      minute: "2-digit",
    }).format(new Date());
    root.querySelectorAll(".lab-phone-status time").forEach((clock) => {
      clock.textContent = current;
    });
  }

  root.querySelectorAll("[data-preset]").forEach((button) =>
    button.addEventListener("click", () => {
      preset = PRESETS.find((p) => p.id === button.dataset.preset);
      root.querySelectorAll("[data-preset]").forEach((b) => {
        const active = b === button;
        b.classList.toggle("is-active", active);
        b.setAttribute("aria-pressed", String(active));
      });
      updateDeviceLayout();
    }),
  );
  root.querySelectorAll("[data-network]").forEach((button) =>
    button.addEventListener("click", () => {
      network = button.dataset.network;
      root.querySelectorAll("[data-network]").forEach((b) => {
        const active = b === button;
        b.classList.toggle("is-active", active);
        b.setAttribute("aria-pressed", String(active));
      });
      root.querySelector(".lab-network-label").textContent = {
        normal: "LIVE",
        slow: "SLOW",
        offline: "OFF",
      }[network];
      root.querySelector("#lab-network-help").textContent = {
        normal: "Normale Verbindung zum lokalen Spiel.",
        slow: "Die App verzögert Netzwerkanfragen für diesen Test.",
        offline: "Die App simuliert einen Verbindungsverlust.",
      }[network];
      devices.forEach((d) => sendNetwork(d.frame));
      say(
        {
          normal: "Verbindung wiederhergestellt",
          slow: "Langsame Verbindung wird simuliert",
          offline: "Offline-Modus wird simuliert",
        }[network],
      );
    }),
  );
  root.querySelector('[data-action="rotate"]').addEventListener("click", () => {
    rotated = !rotated;
    updateDeviceLayout();
  });
  root
    .querySelector('[data-action="touch"]')
    .addEventListener("click", (event) => {
      touchEnabled = !touchEnabled;
      event.currentTarget.classList.toggle("is-active", touchEnabled);
      event.currentTarget.setAttribute("aria-pressed", String(touchEnabled));
      if (!touchEnabled)
        root
          .querySelectorAll(".lab-touch")
          .forEach((touch) => touch.classList.remove("is-visible"));
    });
  root.querySelector('[data-action="reload"]').addEventListener("click", () => {
    devices.forEach((d) => d.frame.contentWindow?.location.reload());
    say("Vorschau neu geladen");
  });
  root
    .querySelector('[data-action="second"]')
    .addEventListener("click", (event) => {
      if (devices.length > 1) {
        removeSecond();
        return;
      }
      mountDevice("two");
      event.currentTarget.innerHTML = `${icon("close")} Zweites Gerät schließen`;
      event.currentTarget.setAttribute("aria-pressed", "true");
      say("Zweites Gerät mit eigenem lokalen Profil geöffnet");
    });
  root
    .querySelector('[data-action="screenshot"]')
    .addEventListener("click", async (event) => {
      const button = event.currentTarget;
      button.disabled = true;
      try {
        if (!window.htmlToImage) {
          await new Promise((resolve, reject) => {
            const script = document.createElement("script");
            script.src = "/vendor/html-to-image.js";
            script.onload = resolve;
            script.onerror = () => {
              script.remove();
              reject(
                new Error("Screenshot-Bibliothek konnte nicht geladen werden."),
              );
            };
            document.head.append(script);
          });
        }
        const frame = devices[0].frame;
        const doc = frame.contentDocument;
        if (!window.htmlToImage?.toPng || !doc?.body)
          throw new Error("Die Vorschau ist noch nicht bereit.");
        await doc.fonts?.ready;
        const width = parseInt(frame.style.width, 10);
        const height = parseInt(frame.style.height, 10);
        const data = await window.htmlToImage.toPng(doc.body, {
          width,
          height,
          pixelRatio: 2,
          backgroundColor: "#11161e",
          cacheBust: false,
          skipFonts: true,
          style: {
            margin: "0",
            width: `${width}px`,
            height: `${height}px`,
            overflow: "hidden",
          },
        });
        const link = document.createElement("a");
        link.download = `chess-royale-${preset.id}-${new Date().toISOString().slice(0, 19).replaceAll(":", "-")}.png`;
        link.href = data;
        link.click();
        say("Screenshot als PNG heruntergeladen");
      } catch (error) {
        say(error.message || "Screenshot konnte nicht erstellt werden.");
      } finally {
        button.disabled = false;
      }
    });
  window.addEventListener("message", (event) => {
    if (
      event.origin !== location.origin ||
      !devices.some((d) => d.frame.contentWindow === event.source)
    )
      return;
    if (event.data?.type === "chessroyale:ready")
      sendNetwork(
        devices.find((d) => d.frame.contentWindow === event.source).frame,
      );
  });
  mountDevice("one");
  new ResizeObserver(updateDeviceLayout).observe(preview);
  setInterval(updateClocks, 15000);
  window.chessRoyaleFrame = {
    getState: () => ({
      preset: preset.id,
      rotated,
      network,
      touchEnabled,
      devices: devices.map((d) => d.id),
    }),
  };
  return true;
}
