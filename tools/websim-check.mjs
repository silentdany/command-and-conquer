// Runs tools/wheelsim.lua (the offline wheel test) under wasmoon, the Lua
// 5.4 runtime of the training web page, to prove the add-on code and the
// emulation behave the same there as in Lua 5.1.
//   node tools/websim-check.mjs      (after npm ci --prefix web)
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(join(root, "web", "package.json"));
const { LuaFactory } = require("wasmoon");

const lua = await new LuaFactory().createEngine();
lua.global.set("CNC_ROOT", root);
lua.global.set("CNC_READ", (path) => readFileSync(path, "utf8"));
try {
  await lua.doString(readFileSync(join(root, "tools", "wheelsim.lua"), "utf8"));
} catch (err) {
  console.error(String(err));
  process.exit(1);
} finally {
  lua.global.close();
}
