// The game interface around the wheel: zone background, minimap header,
// flag carriers, target frame, score, clock, action bar. Plain DOM updates;
// the wheel itself is drawn by app.js from the add-on's Lua.

const $ = (id) => document.getElementById(id);

const SUBZONES = { ours: "Silverwing Hold", mid: "Warsong Gulch", theirs: "Warsong Lumber Mill" };
const TARGETS = {
  enemy: { name: "Gruk", cls: "enemy", letter: "G" },
  friend: { name: "Bjorn", cls: "friend", letter: "B" },
};

// side = ours | mid | theirs (from the situation's scene)
export function setZone(side) {
  const zone = SUBZONES[side] ? side : "mid";
  $("world").dataset.zone = zone;
  $("subzone").textContent = SUBZONES[zone];
}

export function setTarget(kind) {
  const t = TARGETS[kind];
  const frame = $("target");
  frame.hidden = !t;
  if (!t) return;
  frame.className = `unit target ${t.cls}`;
  $("target-name").textContent = t.name;
  $("target-portrait").querySelector(".letter").textContent = t.letter;
}

// Flag carrier frames under the minimap, from the scene marker.
export function setCarriers(scene, iconUrl) {
  const box = $("carriers");
  box.textContent = "";
  const marker = scene && scene.marker;
  const add = (side, name, icon, hp) => {
    const row = document.createElement("div");
    row.className = `carrier wow-panel ${side}`;
    row.innerHTML = `<img alt="" src="${iconUrl(icon)}"><span class="who"></span><span class="bar hp"><i style="--v: ${hp}%"></i></span>`;
    row.querySelector(".who").textContent = name;
    box.appendChild(row);
  };
  if (marker === "efc") add("theirs", "Gruk has our flag", "efc", 58);
  if (marker === "fc" || marker === "cap") add("ours", "Bjorn has their flag", "flag", 81);
  if (marker === "you") add("ours", "You have their flag", "flag", 93);
}

// Good calls win flags for us, mistakes give flags to them.
export function setScore(done, errors) {
  $("score-ally").textContent = `${Math.min(3, Math.floor(done / 5))}/3`;
  $("score-horde").textContent = `${Math.min(3, Math.floor(errors / 3))}/3`;
  $("xp").style.width = `${(done % 5) * 20}%`;
}

export function startClocks() {
  const started = Date.now();
  const tick = () => {
    const now = new Date();
    $("clock").textContent = now.toTimeString().slice(0, 5);
    const s = Math.floor((Date.now() - started) / 1000);
    $("bg-timer").textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
  };
  tick();
  setInterval(tick, 1000);
}

// Light the action bar slot of a key (TAB, SPACE, 1-5, N).
export function pressSlot(key, down) {
  const slot = document.querySelector(`.slot[data-key="${key === "SPACE" ? "TAB" : key}"]`);
  if (slot) slot.classList.toggle("down", down);
}

// Restart a CSS animation on an element.
export function replay(el, cls) {
  el.classList.remove(cls);
  void el.offsetWidth;
  el.classList.add(cls);
}
