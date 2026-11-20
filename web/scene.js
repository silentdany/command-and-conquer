// Map sketch behind the wheel: their base on top (red), ours at the
// bottom (blue), mid between. Each base uses the wheel's own "pyramid"
// (flag room top, roof top right, tunnel top left, GY bottom left, ramp
// bottom right), so the sketch trains the same hand movement as the wheel.
// It is a schematic, not a map of the game.

const SVG = "http://www.w3.org/2000/svg";

const LAYOUT = { FR: [0, -1], ROOF: [0.95, -0.42], TUN: [-0.95, -0.42], GY: [-0.62, 0.72], RAMP: [0.62, 0.72] };
const NAMES = { FR: "flag room", ROOF: "roof", TUN: "tunnel", GY: "graveyard", RAMP: "ramp", MID: "mid" };
const COLORS = { ours: "#52a1ff", theirs: "#e6383a", mid: "#d8d2c4" };

function el(name, attrs, parent) {
  const node = document.createElementNS(SVG, name);
  for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
  if (parent) parent.appendChild(node);
  return node;
}

function zoneCenter(side, place) {
  if (side === "mid" || place === "MID") return [500, 500];
  const [dx, dy] = LAYOUT[place];
  const cy = side === "theirs" ? 205 : 795;
  return [500 + dx * 150, cy + dy * 110];
}

// scene = "<marker>[:count] <side> <place>", see situations.txt.
export function parseScene(text) {
  const [markerPart = "", side = "mid", place = "MID"] = (text || "").trim().split(/\s+/);
  const [marker, count] = markerPart.split(":");
  return { marker, count: count === undefined ? null : Number(count), side, place: place.toUpperCase() };
}

export function drawScene(container, scene, iconUrl) {
  container.textContent = "";
  const svg = el("svg", { viewBox: "200 -30 600 1060", preserveAspectRatio: "xMidYMid meet" }, container);

  const base = (side) => {
    const g = el("g", { opacity: 0.9 }, svg);
    const color = COLORS[side];
    const cy = side === "theirs" ? 205 : 795;
    el("rect", { x: 250, y: cy - 175, width: 500, height: 330, rx: 26, fill: color, "fill-opacity": 0.05,
      stroke: color, "stroke-opacity": 0.35, "stroke-width": 2 }, g);
    const label = el("text", { x: 500, y: side === "theirs" ? cy - 190 : cy + 205, "text-anchor": "middle",
      fill: color, "fill-opacity": 0.6, "font-size": 20, "letter-spacing": 4 }, g);
    label.textContent = side === "theirs" ? "THEIR BASE" : "OUR BASE";
    for (const place of Object.keys(LAYOUT)) {
      const [x, y] = zoneCenter(side, place);
      const hot = scene && scene.side === side && scene.place === place;
      el("circle", { cx: x, cy: y, r: hot ? 50 : 40, fill: color, "fill-opacity": hot ? 0.35 : 0.08,
        stroke: color, "stroke-opacity": hot ? 1 : 0.4, "stroke-width": hot ? 4 : 2 }, g);
      const t = el("text", { x, y: y + 66, "text-anchor": "middle", fill: "#e8e6e1",
        "fill-opacity": hot ? 1 : 0.5, "font-size": 18 }, g);
      t.textContent = NAMES[place];
    }
  };
  base("theirs");
  base("ours");

  const midHot = scene && (scene.side === "mid" || scene.place === "MID");
  el("path", { d: "M500 375 L500 625", stroke: "#d8d2c4", "stroke-opacity": 0.12, "stroke-width": 14, "stroke-dasharray": "2 14", "stroke-linecap": "round" }, svg);
  el("circle", { cx: 500, cy: 500, r: midHot ? 54 : 44, fill: COLORS.mid, "fill-opacity": midHot ? 0.3 : 0.06,
    stroke: COLORS.mid, "stroke-opacity": midHot ? 0.9 : 0.35, "stroke-width": midHot ? 4 : 2 }, svg);
  const mt = el("text", { x: 575, y: 506, fill: "#e8e6e1", "fill-opacity": midHot ? 1 : 0.5, "font-size": 18 }, svg);
  mt.textContent = "mid";

  if (!scene || !scene.marker) return;
  const [x, y] = zoneCenter(scene.side, scene.place);
  const marker = (icon, color, label) => {
    el("image", { href: iconUrl(icon), x: x - 30, y: y - 30, width: 60, height: 60,
      style: `filter: drop-shadow(0 0 6px ${color})` }, svg);
    if (label) {
      const t = el("text", { x: x + 40, y: y - 26, fill: color, "font-size": 22, "font-weight": 700 }, svg);
      t.textContent = label;
    }
  };
  const dots = (n, color) => {
    for (let i = 0; i < Math.min(n, 10); i++) {
      const a = (i / Math.max(n, 1)) * Math.PI * 2;
      el("circle", { cx: x + Math.cos(a) * 28, cy: y + Math.sin(a) * 28, r: 9, fill: color, stroke: "#000", "stroke-width": 2 }, svg);
    }
    const t = el("text", { x: x + 44, y: y - 30, fill: color, "font-size": 24, "font-weight": 700 }, svg);
    t.textContent = n === 0 ? "nobody" : `×${n}`;
  };
  switch (scene.marker) {
    case "efc": marker("efc", COLORS.theirs, "their carrier"); break;
    case "fc": marker("flag", COLORS.ours, "our carrier"); break;
    case "you": marker("flag", COLORS.ours, "YOU carry"); break;
    case "cap": marker("cap", "#ffd84d", "our flag is home"); break;
    case "enemies": dots(scene.count ?? 1, COLORS.theirs); break;
    case "allies": dots(scene.count ?? 1, COLORS.ours); break;
  }
}
