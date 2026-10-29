// Check the MoonBit++ examples of the manual (book/src and book/en/src):
//   node scripts/check-book.mjs
// Every ```moonbit block is type checked with moonpp, and run when it has a
// `main`; blocks are standalone programs (```text is used for fragments).
// A block starting with a `// requires <module>` line needs a dependency:
// it is not checked.
import { execSync } from "node:child_process";
import { mkdtempSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const srcs = [join(root, "book", "src"), join(root, "book", "en", "src")];
const tmp = mkdtempSync(join(tmpdir(), "mbtpp-book-"));

function* markdown(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) yield* markdown(p);
    else if (name.endsWith(".md")) yield p;
  }
}

let failed = 0;
let count = 0;
for (const file of srcs.flatMap((d) => [...markdown(d)])) {
  const text = readFileSync(file, "utf8").replace(/\r\n/g, "\n");
  const blocks = [...text.matchAll(/```moonbit\n([\s\S]*?)```/g)].map((m) => m[1]);
  blocks.forEach((code, k) => {
    if (code.startsWith("// requires ")) return;
    count++;
    const f = join(tmp, `b${count}.mbtpp`);
    writeFileSync(f, code);
    const cmd = /\bfn main\b/.test(code) ? "run" : "check";
    try {
      execSync(`moonpp ${cmd} "${f}"`, { stdio: "pipe" });
    } catch (e) {
      failed++;
      console.log(`${relative(root, file)} (block ${k + 1}):`);
      console.log(String(e.stdout) + String(e.stderr));
    }
  });
}
console.log(`${count - failed} of ${count} examples ok`);
process.exitCode = failed > 0 ? 1 : 0;
