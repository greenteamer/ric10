// Builds tests/fixtures/prefabs.json: every prefab of the current game with its
// hash, display name and (when known) prefab name.
//
//   node scripts/import-prefabs.mjs <stationpedia.txt> <prefab_map.rs>
//
// stationpedia.txt  (ic10lsp)  "<hash> <display name>" for the current game build
// prefab_map.rs     (ic10emu)  prefab names; older, so each name is accepted only
//                              when its CRC32 is a hash of the current game
// Prefabs whose name is unknown keep `name: null`; ric10 then emits their number.
import fs from "fs";
import path from "path";
import { hash } from "../tests/support/ic10.mjs";

const [stationpedia, prefabMap] = process.argv.slice(2);
if (!stationpedia || !prefabMap) {
  console.error("usage: node scripts/import-prefabs.mjs <stationpedia.txt> <prefab_map.rs>");
  process.exit(2);
}

const game = new Map();
for (const raw of fs.readFileSync(stationpedia, "utf8").split("\n")) {
  const line = raw.replace(/\r$/, "").trim();
  if (!line) continue;
  const i = line.indexOf(" ");
  game.set(Number(line.slice(0, i)), line.slice(i + 1).trim());
}

const names = new Map();
for (const m of fs.readFileSync(prefabMap, "utf8").matchAll(/prefab_name: "([A-Za-z0-9_]+)"/g)) {
  const h = hash(m[1]);
  if (game.has(h)) names.set(h, m[1]);
}

// Recover names of newer prefabs: an untranslated display name "<N:EN:Name>" is the
// prefab name, and "Structure"/"Item"/... + PascalCase(display) is a common pattern.
// A candidate is accepted only when its CRC32 equals the game hash, so guesses are exact.
const pascal = (d) =>
  d
    .replace(/[^A-Za-z0-9]+/g, " ")
    .trim()
    .split(" ")
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join("");
const PREFIXES = ["", "Structure", "Item", "Appliance", "Kit", "Dynamic", "Landingpad", "Entity", "Rocket"];
let guessed = 0;
for (const [h, display] of game) {
  if (names.has(h)) continue;
  const key = /^<N:EN:([A-Za-z0-9_]+)>$/.exec(display);
  const candidates = key ? [key[1]] : PREFIXES.map((p) => p + pascal(display));
  const hit = candidates.find((c) => hash(c) === h);
  if (hit) {
    names.set(h, hit);
    guessed++;
  }
}
if (guessed) console.log(`recovered ${guessed} names from display names`);

const prefabs = [...game.entries()]
  .map(([h, display]) => ({ hash: h, name: names.get(h) ?? null, display }))
  .sort((a, b) => (a.name ?? a.display).localeCompare(b.name ?? b.display));

const out = {
  sources: [
    "https://github.com/Xandaros/ic10lsp/blob/master/stationpedia.txt (hashes and display names)",
    "https://github.com/Ryex/ic10emu/blob/develop/stationeers_data/src/database/prefab_map.rs (prefab names, verified by CRC32)",
  ],
  retrieved: new Date().toISOString().slice(0, 10),
  prefabs,
};
const dest = path.resolve(import.meta.dirname, "..", "tests", "fixtures", "prefabs.json");
fs.writeFileSync(dest, JSON.stringify(out, null, 1) + "\n");
console.log(`${prefabs.length} prefabs, ${names.size} with names -> ${path.relative(process.cwd(), dest)}`);
