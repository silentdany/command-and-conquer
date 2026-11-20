// Map sketch behind the wheel: their base on top (red), ours at the
// bottom (blue), mid between. Each base uses the wheel's own "pyramid"
// (flag room top, roof top right, tunnel top left, GY bottom left, ramp
// bottom right), so the sketch trains the same hand movement as the wheel.
// It is a schematic, not a map of the game. On the page it sits in the
// round minimap frame, zoomed on the zone of the situation.

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

// Square view centred on the zone of the situation, like a minimap
// centred on the player.
const VIEW = 470;
function viewBox(scene) {
  const side = scene ? scene.side : "mid";
  const cy = side === "theirs" ? 215 : side === "ours" ? 785 : 500;
  return `${500 - VIEW / 2} ${cy - VIEW / 2} ${VIEW} ${VIEW}`;
}

export function drawScene(container, scene, iconUrl) {
  container.textContent = "";
  const svg = el("svg", { viewBox: viewBox(scene), preserveAspectRatio: "xMidYMid meet" }, container);
  // the road from one base to the other
  el("path", { d: "M500 -100 L500 1100", stroke: "#b49a6a", "stroke-opacity": 0.18, "stroke-width": 46 }, svg);

  const base = (side) => {
    const g = el("g", { opacity: 0.9 }, svg);
    const color = COLORS[side];
    const cy = side === "theirs" ? 205 : 795;
    el("rect", { x: 250, y: cy - 175, width: 500, height: 330, rx: 26, fill: "#0c0f08", "fill-opacity": 0.45,
      stroke: color, "stroke-opacity": 0.35, "stroke-width": 2 }, g);
    const label = el("text", { x: 500, y: side === "theirs" ? cy - 190 : cy + 205, "text-anchor": "middle",
      fill: color, "fill-opacity": 0.9, "font-size": 26, "letter-spacing": 4, "font-family": "Marcellus, serif" }, g);
    label.textContent = side === "theirs" ? "THEIR BASE" : "OUR BASE";
    for (const place of Object.keys(LAYOUT)) {
      const [x, y] = zoneCenter(side, place);
      const hot = scene && scene.side === side && scene.place === place;
      el("circle", { cx: x, cy: y, r: hot ? 50 : 40, fill: color, "fill-opacity": hot ? 0.4 : 0.14,
        stroke: color, "stroke-opacity": hot ? 1 : 0.4, "stroke-width": hot ? 4 : 2 }, g);
      const t = el("text", { x, y: y + 72, "text-anchor": "middle", fill: hot ? "#ffd100" : "#f2efe6",
        "fill-opacity": hot ? 1 : 0.75, "font-size": 27, "font-family": "Marcellus, serif",
        stroke: "#000", "stroke-width": 4, "paint-order": "stroke" }, g);
      t.textContent = NAMES[place];
    }
  };
  base("theirs");
  base("ours");

  const midHot = scene && (scene.side === "mid" || scene.place === "MID");
  el("path", { d: "M500 375 L500 625", stroke: "#d8d2c4", "stroke-opacity": 0.12, "stroke-width": 14, "stroke-dasharray": "2 14", "stroke-linecap": "round" }, svg);
  el("circle", { cx: 500, cy: 500, r: midHot ? 54 : 44, fill: COLORS.mid, "fill-opacity": midHot ? 0.3 : 0.06,
    stroke: COLORS.mid, "stroke-opacity": midHot ? 0.9 : 0.35, "stroke-width": midHot ? 4 : 2 }, svg);
  const mt = el("text", { x: 562, y: 510, fill: midHot ? "#ffd100" : "#f2efe6", "fill-opacity": midHot ? 1 : 0.75,
    "font-size": 27, "font-family": "Marcellus, serif", stroke: "#000", "stroke-width": 4, "paint-order": "stroke" }, svg);
  mt.textContent = "mid";

  if (!scene || !scene.marker) return;
  const [x, y] = zoneCenter(scene.side, scene.place);
  // Carriers are named in their own frames under the minimap, so their
  // markers carry no text; counts and "flag home" do.
  const marker = (icon, color, label) => {
    el("image", { href: iconUrl(icon), x: x - 30, y: y - 30, width: 60, height: 60,
      style: `filter: drop-shadow(0 0 6px ${color})` }, svg);
    if (label) {
      const t = el("text", { x, y: y - 46, "text-anchor": "middle", fill: color, "font-size": 28, "font-weight": 700,
        "font-family": "Marcellus, serif", stroke: "#000", "stroke-width": 5, "paint-order": "stroke" }, svg);
      t.textContent = label;
    }
  };
  const dots = (n, color) => {
    for (let i = 0; i < Math.min(n, 10); i++) {
      const a = (i / Math.max(n, 1)) * Math.PI * 2;
      el("circle", { cx: x + Math.cos(a) * 28, cy: y + Math.sin(a) * 28, r: 9, fill: color, stroke: "#000", "stroke-width": 2 }, svg);
    }
    const t = el("text", { x: x + (x > 560 ? -56 : 56), y: y + 10, "text-anchor": x > 560 ? "end" : "start", fill: color,
      "font-size": 30, "font-weight": 700, "font-family": "Marcellus, serif", stroke: "#000", "stroke-width": 5, "paint-order": "stroke" }, svg);
    t.textContent = n === 0 ? "nobody" : `×${n}`;
  };
  switch (scene.marker) {
    case "efc": marker("efc", COLORS.theirs); break;
    case "fc": marker("flag", COLORS.ours); break;
    case "you": marker("flag", COLORS.ours, "YOU"); break;
    case "cap": marker("cap", "#ffd84d", "flag home"); break;
    case "enemies": dots(scene.count ?? 1, COLORS.theirs); break;
    case "allies": dots(scene.count ?? 1, COLORS.ours); break;
  }
}
