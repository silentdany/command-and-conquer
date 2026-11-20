// Training page for the Command & Conquer add-on.
//
// The wheel is not redrawn here: the add-on's own Lua files (Data.lua,
// Wheel.lua, Core.lua...) run in the browser through wasmoon, on the same
// WoW emulation as the offline tests (tools/sim/wowemu.lua). This file only
// paints what the emulated game shows (the add-on's textures, exported to
// PNG), forwards the mouse and keys, and reads what the secure button sent.

import { parseScene, drawScene } from "./scene.js";
import { setZone, setTarget, setCarriers, setScore, startClocks, pressSlot, replay } from "./hud.js";
import { play, unlockAudio, isMuted, setMuted } from "./sound.js";

const UI_HEIGHT = 768; // WoW's UI is 768 units high
const FONT = '"Trebuchet MS", "Segoe UI", system-ui, sans-serif';
const MEDIA_PREFIX = "Interface\\AddOns\\CommandAndConquer\\Media\\";
const KEYS = { Tab: "TAB", Space: "SPACE", Digit1: "1", Digit2: "2", Digit3: "3", Digit4: "4", Digit5: "5" };
const STORE = "cnc-trainer-v1";

const $ = (id) => document.getElementById(id);
const game = $("game");
const canvas = $("screen");
const ctx = canvas.getContext("2d");

let L; // Lua functions
let scale = 1;
let dpr = 1;
let mode = "train";

function showError(err) {
  console.error(err);
  let box = document.querySelector(".error");
  if (!box) {
    box = document.createElement("div");
    box.className = "error";
    game.appendChild(box);
  }
  box.textContent = `Something broke: ${err && err.message ? err.message : err}`;
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

async function fetchText(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(`${path}: ${res.status}`);
  return res.text();
}

function loadImage(src) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve([src, img]);
    img.onerror = () => resolve([src, null]);
    img.src = src;
  });
}

const images = new Map();
const tintCache = new Map();

function mediaUrl(texturePath) {
  if (!texturePath.startsWith(MEDIA_PREFIX)) return null;
  return "media/" + texturePath.slice(MEDIA_PREFIX.length).replaceAll("\\", "/") + ".png";
}

// WoW multiplies a texture by its vertex colour; same here.
function tinted(texturePath, r, g, b) {
  const key = `${texturePath}|${r}|${g}|${b}`;
  if (tintCache.has(key)) return tintCache.get(key);
  const base = images.get(mediaUrl(texturePath));
  let out = base || null;
  if (base && !(r === "1.00" && g === "1.00" && b === "1.00")) {
    const off = document.createElement("canvas");
    off.width = base.naturalWidth;
    off.height = base.naturalHeight;
    const c = off.getContext("2d");
    c.fillStyle = `rgb(${r * 255}, ${g * 255}, ${b * 255})`;
    c.fillRect(0, 0, off.width, off.height);
    c.globalCompositeOperation = "multiply";
    c.drawImage(base, 0, 0);
    c.globalCompositeOperation = "destination-in";
    c.drawImage(base, 0, 0);
    out = off;
  }
  tintCache.set(key, out);
  return out;
}

async function boot() {
  const build = await (await fetch("build.json")).json();
  $("build").textContent = `Add-on v${build.version} · build ${build.commit} · ${build.date}`;

  const sources = new Map();
  await Promise.all(build.lua.map(async (p) => sources.set(p, await fetchText(p))));
  (await Promise.all(build.media.map(loadImage))).forEach(([src, img]) => img && images.set(src, img));

  const factory = new wasmoon.LuaFactory("vendor/wasmoon/glue.wasm");
  const lua = await factory.createEngine();
  lua.global.set("CNC_READ", (path) => {
    if (!sources.has(path)) throw new Error(`missing file ${path}`);
    return sources.get(path);
  });
  await lua.doString(sources.get("glue.lua"));
  const fn = (name) => lua.global.get(name);
  L = {
    resize: fn("CNC_RESIZE"), mouse: fn("CNC_MOUSE"), key: fn("CNC_KEY"), tick: fn("CNC_TICK"),
    draw: fn("CNC_DRAW"), output: fn("CNC_OUTPUT"), slash: fn("CNC_SLASH"), set: fn("CNC_SET"),
    path: fn("CNC_PATH"), message: fn("CNC_MESSAGE"), keys: fn("CNC_KEYS"),
  };

  situations = parseSituations(await fetchText("situations.txt"));
  resize();
  new ResizeObserver(resize).observe(game);
  bindInput();
  bindPanel();
  bindSound();
  startClocks();
  addChat("system", "The battle for Warsong Gulch has begun!");
  setMode("train");
  requestAnimationFrame(frame);
}

// ---------------------------------------------------------------------------
// Drawing the emulated screen
// ---------------------------------------------------------------------------

function resize() {
  const rect = game.getBoundingClientRect();
  dpr = window.devicePixelRatio || 1;
  canvas.width = Math.round(rect.width * dpr);
  canvas.height = Math.round(rect.height * dpr);
  scale = rect.height / UI_HEIGHT;
  L.resize(rect.width / scale, UI_HEIGHT);
}

function render() {
  const data = L.draw();
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.setTransform(dpr * scale, 0, 0, dpr * scale, 0, 0);
  if (!data) return;
  for (const line of data.split("\n")) {
    const f = line.split("\t");
    if (f[0] === "T") {
      const img = tinted(f[1], f[7], f[8], f[9]);
      if (!img) continue;
      const w = +f[4], h = +f[5];
      ctx.save();
      ctx.globalAlpha = +f[10];
      ctx.translate(+f[2], UI_HEIGHT - f[3]);
      ctx.rotate(-f[6]);
      ctx.drawImage(img, -w / 2, -h / 2, w, h);
      ctx.restore();
    } else if (f[0] === "F") {
      const [, text, ax, ay, point, size, r, g, b, a] = f;
      ctx.save();
      ctx.font = `600 ${size}px ${FONT}`;
      ctx.textAlign = point.includes("LEFT") ? "left" : point.includes("RIGHT") ? "right" : "center";
      ctx.textBaseline = point.startsWith("TOP") ? "top" : point.startsWith("BOTTOM") ? "bottom" : "middle";
      const x = +ax, y = UI_HEIGHT - ay;
      ctx.globalAlpha = 0.9 * a;
      ctx.fillStyle = "#000";
      ctx.fillText(text, x + 1, y + 1);
      ctx.globalAlpha = +a;
      ctx.fillStyle = `rgb(${r * 255}, ${g * 255}, ${b * 255})`;
      ctx.fillText(text, x, y);
      ctx.restore();
    }
  }
}

let last = performance.now();
function frame(t) {
  const dt = Math.min(0.1, Math.max(0, (t - last) / 1000));
  last = t;
  try {
    L.tick(dt);
    handleOutput(L.output());
    render();
  } catch (err) {
    showError(err);
    return;
  }
  requestAnimationFrame(frame);
}

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------

const held = new Set();

function typing(e) {
  const t = e.target;
  return t && (t.tagName === "INPUT" && t.type === "text" || t.tagName === "SELECT" || t.tagName === "TEXTAREA");
}

function bindInput() {
  game.addEventListener("pointermove", (e) => {
    const rect = game.getBoundingClientRect();
    L.mouse((e.clientX - rect.left) / scale, UI_HEIGHT - (e.clientY - rect.top) / scale);
  });
  game.addEventListener("pointerdown", (e) => {
    unlockAudio();
    if (!typing(e) && e.target.closest && !e.target.closest(".panel, .chat")) game.focus();
  });
  window.addEventListener("keydown", (e) => {
    if (typing(e)) {
      if (e.key === "Escape") e.target.blur();
      return;
    }
    unlockAudio();
    const k = KEYS[e.code];
    if (k && !e.ctrlKey && !e.altKey && !e.metaKey) {
      e.preventDefault();
      if (!e.repeat && !held.has(k)) {
        held.add(k);
        pressSlot(k, true);
        L.key(k, true);
      }
      return;
    }
    if (mode === "train" && e.code === "KeyN") {
      e.preventDefault();
      pressSlot("N", true);
      setTimeout(() => pressSlot("N", false), 150);
      nextSituation();
    }
    if (e.code === "Slash" || e.code === "Enter") {
      e.preventDefault();
      $("slash-input").focus();
    }
  });
  window.addEventListener("keyup", (e) => {
    const k = KEYS[e.code];
    if (k && held.has(k)) {
      e.preventDefault();
      held.delete(k);
      pressSlot(k, false);
      L.key(k, false);
    }
  });
  window.addEventListener("blur", () => {
    for (const k of held) {
      pressSlot(k, false);
      L.key(k, false);
    }
    held.clear();
  });
  $("slash").addEventListener("submit", (e) => {
    e.preventDefault();
    const input = $("slash-input");
    const text = input.value.trim();
    input.value = "";
    input.blur();
    game.focus();
    if (!text) return;
    if (!L.slash(text)) addChat("system", `Unknown command: ${text} (try /cnc)`);
  });
  if (matchMedia("(pointer: coarse)").matches && !matchMedia("(pointer: fine)").matches) $("touch").hidden = false;
  game.focus();
}

// ---------------------------------------------------------------------------
// Chat and what the secure button sent
// ---------------------------------------------------------------------------

function addChat(kind, text) {
  const list = $("chat");
  const li = document.createElement("li");
  li.className = kind;
  li.textContent = text;
  list.appendChild(li);
  while (list.children.length > 12) list.firstChild.remove();
}

function handleOutput(out) {
  if (!out) return;
  for (const line of out.split("\n")) {
    const f = line.split("\t");
    switch (f[0]) {
      case "chat":
        if (f[1] === "INSTANCE_CHAT") addChat("instance", `[Instance] [You]: ${f[2]}`);
        else addChat("whisper", `To [${f[3]}] (practice): ${f[2]}`);
        play("send");
        break;
      case "ping":
        addChat("ping", `Ping “${f[1]}” on ${f[3] || f[2]}${f[2] === "target" ? " (target)" : ` (${f[2]})`}`);
        break;
      case "mark":
        addChat("ping", `Raid mark ${f[1] === "8" ? "skull" : f[1]} on ${f[3] || f[2]}`);
        break;
      case "print":
        addChat("system", f[1]);
        break;
      case "blocked":
        addChat("blocked", `Blocked in combat: ${f[1]} (this would be a bug in the add-on)`);
        break;
      case "call":
        onCall(f[1], f[2], f[3]);
        break;
      default:
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------

function setMode(next) {
  mode = next;
  document.body.classList.toggle("sandbox", mode === "sandbox");
  for (const tab of document.querySelectorAll(".modes button")) {
    tab.setAttribute("aria-selected", String(tab.dataset.mode === mode));
  }
  $("panel").hidden = mode !== "sandbox";
  if (mode === "sandbox") {
    current = null;
    drawScene($("scene"), null, iconUrl);
    setZone("mid");
    setCarriers(null, iconUrl);
    showInstruction("Sandbox", "Free wheel. Everything the add-on would send shows in the chat.");
    setResult("", "");
    const target = document.querySelector('[data-set="target"]').value;
    L.set("target", target);
    setTarget(target);
  } else {
    nextSituation();
  }
  updateStats();
  game.focus();
}

function bindPanel() {
  for (const tab of document.querySelectorAll(".modes button")) {
    tab.addEventListener("click", () => setMode(tab.dataset.mode));
  }
  for (const input of document.querySelectorAll("[data-set]")) {
    input.addEventListener("change", () => {
      const value = input.type === "checkbox" ? (input.checked ? "on" : "off") : input.value;
      if (!L.set(input.dataset.set, value)) {
        $("panel-note").textContent = "Can't change that in combat, as in game.";
        if (input.type === "checkbox") input.checked = !input.checked;
      } else {
        $("panel-note").textContent = "";
        if (input.dataset.set === "target") setTarget(value);
      }
      game.focus();
    });
  }
}

// ---------------------------------------------------------------------------
// Training
// ---------------------------------------------------------------------------

let situations = [];
let current = null;
let shownAt = 0;
let answered = false;
let lastId = null;
const session = { done: 0, errors: 0, total: 0, streak: 0 };

function loadStore() {
  try {
    return JSON.parse(localStorage.getItem(STORE)) || { best: {} };
  } catch {
    return { best: {} };
  }
}
function saveStore(data) {
  try {
    localStorage.setItem(STORE, JSON.stringify(data));
  } catch {
    // private mode: best times are not kept
  }
}
const store = loadStore();

function iconUrl(name) {
  return `media/icons/${name}.png`;
}

function parseSituations(text) {
  const list = [];
  for (const raw of text.split(/\r?\n/)) {
    if (!raw.trim() || raw.trim().startsWith("#")) continue;
    const [id, scene, instruction, keys, options = ""] = raw.split("|").map((s) => s.trim());
    const path = L.path(keys);
    if (!path || path.startsWith("!")) {
      console.warn(`situation ${id}: ${path}`);
      continue;
    }
    const opts = Object.fromEntries(options.split(/\s+/).filter(Boolean).map((o) => o.split("=")));
    list.push({ id, scene: parseScene(scene), instruction, keys, path, msg: L.message(path), opts });
  }
  return list;
}

function setResult(cls, html) {
  const el = $("card-result");
  el.className = "card-result";
  void el.offsetWidth; // restart the shake or flash animation
  el.className = `card-result ${cls}`;
  el.innerHTML = html;
}

function escapeHtml(s) {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}

function nextSituation() {
  if (mode !== "train" || situations.length === 0) return;
  let pick;
  do {
    pick = situations[Math.floor(Math.random() * situations.length)];
  } while (situations.length > 1 && pick.id === lastId);
  lastId = pick.id;
  current = pick;
  answered = false;
  L.set("target", pick.opts.target || "none");
  setTarget(pick.opts.target || "none");
  drawScene($("scene"), pick.scene, iconUrl);
  setZone(pick.scene.side);
  setCarriers(pick.scene, iconUrl);
  showInstruction(`Situation ${session.done + 1}`, pick.instruction);
  setResult("", "");
  const best = store.best[pick.id];
  $("best").textContent = best ? `Best on this one: ${(best / 1000).toFixed(2)} s` : "First time on this one";
  shownAt = performance.now();
}

function onCall(result, msg, path) {
  if (mode !== "train" || !current || answered) return;
  if (result === "blocked") {
    setResult("bad", "Too fast: the add-on keeps 1 s between calls.");
    play("error");
    return;
  }
  if (result === "undo" || !result.startsWith("sent")) return;
  const ms = performance.now() - shownAt;
  if (path === current.path) {
    answered = true;
    session.done += 1;
    session.total += ms;
    session.streak += 1;
    const best = store.best[current.id];
    const record = !best || ms < best;
    if (record) {
      store.best[current.id] = Math.round(ms);
      saveStore(store);
      $("best").textContent = `Best on this one: ${(ms / 1000).toFixed(2)} s`;
    }
    play(session.streak % 5 === 0 ? "streak" : "success");
    replay($("tracker"), "flash");
    setResult("ok", `✓ ${(ms / 1000).toFixed(2)} s${record ? (best ? " · new best!" : "") : ` · best ${(best / 1000).toFixed(2)} s`}`);
    updateStats();
    setTimeout(() => {
      if (mode === "train" && answered) nextSituation();
    }, 900);
  } else {
    session.errors += 1;
    session.streak = 0;
    play("error");
    setResult("bad", `✗ Expected <code>${escapeHtml(current.keys)}</code> → “${escapeHtml(current.msg)}”. ` +
      `You did ${escapeHtml(L.keys(path))}. Try again, or N to skip.`);
    updateStats();
  }
}

let lastStreak = 0;
function updateStats() {
  const el = $("stats");
  setScore(session.done, session.errors);
  if (mode !== "train") {
    el.textContent = "";
    return;
  }
  const avg = session.done ? (session.total / session.done / 1000).toFixed(2) + " s" : "–";
  el.innerHTML = `<span>Calls done</span><b>${session.done}</b><span>Mistakes</span><b>${session.errors}</b>` +
    `<span>Average time</span><b>${avg}</b><span>Streak</span><b id="streak">${session.streak}</b>`;
  if (session.streak > lastStreak) $("streak").classList.add("pulse");
  lastStreak = session.streak;
}

function showInstruction(kicker, text) {
  $("card-kicker").textContent = kicker;
  $("card-text").textContent = text;
  replay($("card-text"), "fresh");
}

function bindSound() {
  const btn = $("mute");
  const show = () => {
    btn.textContent = isMuted() ? "Sound: off" : "Sound: on";
    btn.setAttribute("aria-pressed", String(isMuted()));
  };
  btn.addEventListener("click", () => {
    setMuted(!isMuted());
    unlockAudio();
    show();
    game.focus();
  });
  show();
}

boot().catch(showError);
