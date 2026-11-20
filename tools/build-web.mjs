// Builds the web site into _site/ (or the folder given):
//   npm ci --prefix web && node tools/build-web.mjs
//   /                   landing page of the add-on (web/landing/)
//   /hud/               shared interface style, font, backgrounds
//   /training-ground/   training page (web/): runs the add-on's real Lua
//                       files, copied here in TOC order, on the shared WoW
//                       emulation, with the add-on's textures as PNG.
// Node only (no Python), so Vercel builds it on every push (vercel.json).
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { decodeTga, encodePng } from "./tga2png.mjs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const site = join(root, process.argv[2] || "_site");
const out = join(site, "training-ground");
const addon = join(root, "CommandAndConquer");

rmSync(site, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
cpSync(join(root, "web/landing"), site, { recursive: true });
// Shared game-interface style, font and backgrounds (landing and training).
cpSync(join(root, "web/hud"), join(site, "hud"), { recursive: true });

for (const f of ["index.html", "style.css", "app.js", "scene.js", "hud.js", "sound.js", "glue.lua", "situations.txt"]) {
  cpSync(join(root, "web", f), join(out, f));
}

// Add-on files listed by the TOC, and the emulation.
const toc = readFileSync(join(addon, "CommandAndConquer.toc"), "utf8");
const files = toc.split(/\r?\n/).map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));
const lua = ["glue.lua", "lua/tools/sim/wowemu.lua", "lua/CommandAndConquer/CommandAndConquer.toc"];
mkdirSync(join(out, "lua/CommandAndConquer"), { recursive: true });
mkdirSync(join(out, "lua/tools/sim"), { recursive: true });
cpSync(join(addon, "CommandAndConquer.toc"), join(out, "lua/CommandAndConquer/CommandAndConquer.toc"));
for (const f of files) {
  cpSync(join(addon, f), join(out, "lua/CommandAndConquer", f));
  lua.push(`lua/CommandAndConquer/${f}`);
}
cpSync(join(root, "tools/sim/wowemu.lua"), join(out, "lua/tools/sim/wowemu.lua"));

// wasmoon (Lua 5.4 compiled to WebAssembly), from web/node_modules.
const wasmoon = join(root, "web/node_modules/wasmoon/dist");
mkdirSync(join(out, "vendor/wasmoon"), { recursive: true });
for (const f of ["index.js", "glue.wasm"]) cpSync(join(wasmoon, f), join(out, "vendor/wasmoon", f));

// Same textures and icons as the add-on, as PNG (same pixels).
const walk = (dir) => readdirSync(dir).flatMap((n) => {
  const p = join(dir, n);
  return statSync(p).isDirectory() ? walk(p) : [p];
});
const mediaSrc = join(addon, "Media");
const pngs = [];
for (const tga of walk(mediaSrc).filter((p) => p.endsWith(".tga"))) {
  const rel = relative(mediaSrc, tga).split("\\").join("/").replace(/\.tga$/, ".png");
  const dest = join(out, "media", rel);
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, encodePng(decodeTga(readFileSync(tga))));
  pngs.push(`media/${rel}`);
}

const version = (toc.match(/^## Version:\s*(.+)$/m) || [])[1]?.trim() || "?";
let commit = (process.env.VERCEL_GIT_COMMIT_SHA || process.env.GITHUB_SHA || "").slice(0, 7);
if (!commit) {
  try { commit = execSync("git rev-parse --short HEAD", { cwd: root }).toString().trim(); } catch { commit = "local"; }
}
const build = { version, commit, date: new Date().toISOString().slice(0, 10), lua, media: pngs };
writeFileSync(join(out, "build.json"), JSON.stringify(build, null, 2));
console.log(`site built in ${relative(root, site) || "."}: add-on v${version}, ${lua.length} Lua files, ${pngs.length} images`);
