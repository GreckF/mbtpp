#!/usr/bin/env node
// Launcher of moonpp (the JS build of src/moonpp). The program runs in a
// worker thread with a large stack, because the interpreter and the type
// checker recurse deeply.
const { Worker } = require("worker_threads");
const path = require("path");
const fs = require("fs");

const root = path.resolve(__dirname, "..");
const main = path.join(root, "_build", "js", "release", "build", "moonpp", "moonpp.js");
if (!fs.existsSync(main)) {
  console.error(`moonpp is not built yet; run \`moon build --target js\` in ${root}`);
  process.exit(1);
}
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
