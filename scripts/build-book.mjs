// Build the manual: the Chinese book (book/) into docs/book and the English
// one (book/en/) into docs/book/en. The Chinese build replaces docs/book, so
// it goes first; the English book shares the theme files of book/theme.
//   node scripts/build-book.mjs
import { execSync } from "node:child_process";
import { cpSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
cpSync(join(root, "book", "theme"), join(root, "book", "en", "theme"), { recursive: true });
for (const dir of ["book", join("book", "en")]) {
  execSync(`mdbook build "${join(root, dir)}"`, { stdio: "inherit" });
}
