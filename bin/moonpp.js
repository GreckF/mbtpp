#!/usr/bin/env node
// Launcher of moonpp (the JS build of src/moonpp). The program runs in a
// worker thread with a large stack, because the interpreter and the type
// checker recurse deeply.
const { Worker } = require("worker_threads");
const path = require("path");
const fs = require("fs");

const root = path.resolve(__dirname, "..");
// the release build (`moon build --target js --release`), or else the debug
// build, whichever is newer
const builds = ["release", "debug"]
  .map((p) => path.join(root, "_build", "js", p, "build", "moonpp", "moonpp.js"))
  .filter((f) => fs.existsSync(f))
  .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
if (builds.length === 0) {
  console.error(`moonpp is not built yet; run \`moon build --target js --release\` in ${root}`);
  process.exit(1);
}
const main = builds[0];
const worker = new Worker(main, {
  argv: process.argv.slice(2),
  resourceLimits: { stackSizeMb: 512 },
});
let exitCode = 0;
worker.on("message", (m) => {
  if (m && typeof m.exitCode === "number") exitCode = m.exitCode;
});
worker.on("exit", (code) => {
  process.exitCode = code || exitCode;
});
worker.on("error", (e) => {
  console.error((e && e.stack) || e);
  process.exitCode = 1;
});
