import { examples } from "./examples.js";

// ---- syntax highlighting -------------------------------------------------

const common = [
  "fn", "let", "mut", "if", "else", "match", "enum", "struct", "trait", "impl",
  "for", "in", "with", "while", "return", "break", "continue", "raise", "try",
  "catch", "suberror", "derive", "pub", "priv", "noraise", "loop", "as", "is",
];
const words = (ws) => new RegExp("(?:" + ws.join("|") + ")\\b");

function defineMode(name, extra) {
  CodeMirror.defineSimpleMode(name, {
    start: [
      { regex: /\/\/.*/, token: "comment" },
      { regex: /#\|.*/, token: "string" },
      { regex: /"(?:[^\\"]|\\.)*"?/, token: "string" },
      { regex: /'(?:[^\\']|\\.)'/, token: "string" },
      { regex: /#[a-z_]+/, token: "meta" },
      { regex: /(fn|lemma)(\s+)([a-z_]\w*)/, token: ["keyword", null, "def"] },
      { regex: words([...common, ...extra]), token: "keyword" },
      { regex: /(?:true|false)\b/, token: "atom" },
      { regex: /0x[0-9a-fA-F_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?/, token: "number" },
      { regex: /@[a-z_]\w*/, token: "variable-2" },
      { regex: /[A-Z]\w*/, token: "type" },
      { regex: /[-+*\/%=<>!&|^~?:]+/, token: "operator" },
      { regex: /[a-z_]\w*/, token: "variable" },
    ],
    meta: { lineComment: "//" },
  });
}
defineMode("mbtpp", ["lemma", "proof", "monad", "forall", "Type", "Prop"]);
defineMode("moonbit", ["guard", "defer", "test", "type", "typealias", "extern", "const", "async"]);

// ---- workers ---------------------------------------------------------------

/** A worker running the checker, interpreter and compiler. */
class Engine {
  constructor() {
    this.next = 0;
    this.spawn();
  }
  spawn() {
    this.pending = new Map();
    this.worker = new Worker(new URL("./worker.js", import.meta.url), { type: "module" });
    this.worker.onmessage = (e) => {
      const p = this.pending.get(e.data.id);
      if (p) {
        this.pending.delete(e.data.id);
        p(e.data.result);
      }
    };
    this.worker.onerror = (e) => {
      e.preventDefault();
      this.restart("error: " + (e.message || "the worker failed"));
    };
  }
  restart(result) {
    this.worker.terminate();
    const ps = [...this.pending.values()];
    this.spawn();
    for (const p of ps) p(result);
  }
  /** Run `op` on `src`; stop it (and answer an error) after `timeout` ms. */
  call(op, src, timeout = 0) {
    const id = ++this.next;
    return new Promise((resolve) => {
      this.pending.set(id, resolve);
      this.worker.postMessage({ id, op, src });
      if (timeout > 0) {
        setTimeout(() => {
          if (this.pending.has(id)) {
            this.restart("error: stopped after " + timeout / 1000 + " s (an infinite loop?)");
          }
        }, timeout);
      }
    });
  }
}

const checker = new Engine();
const runner = new Engine();

// ---- editors ---------------------------------------------------------------

const $ = (id) => document.getElementById(id);

const editor = CodeMirror.fromTextArea($("src"), {
  mode: "mbtpp",
  lineNumbers: true,
  indentUnit: 2,
  tabSize: 2,
  matchBrackets: true,
  extraKeys: {
    Tab: (cm) => cm.replaceSelection("  "),
    "Ctrl-Enter": () => runProgram(),
    "Cmd-Enter": () => runProgram(),
    "Shift-Ctrl-Enter": () => compileProgram(),
    "Shift-Cmd-Enter": () => compileProgram(),
  },
});

const viewer = CodeMirror.fromTextArea($("code"), {
  mode: "moonbit",
  lineNumbers: true,
  readOnly: true,
});

// ---- type checking on edit -------------------------------------------------

const loc = /^main\.mbtpp:(\d+):(\d+):/;
let errLine = null;
let checkSeq = 0;
let checkTimer = 0;

function markError(msg) {
  if (errLine !== null) {
    editor.removeLineClass(errLine, "background", "err-line");
    errLine = null;
  }
  const m = loc.exec(msg.replace(/^error: (cannot compile: )?/, ""));
  if (m) {
    errLine = editor.getLineHandle(Number(m[1]) - 1);
    if (errLine) editor.addLineClass(errLine, "background", "err-line");
  }
}

function showStatus(result) {
  const status = $("status");
  if (result === "ok") {
    status.className = "status ok";
    status.textContent = "✓ 类型检查通过";
    markError("");
  } else {
    status.className = "status err";
    status.textContent = result;
    markError(result);
  }
}

async function checkNow() {
  const seq = ++checkSeq;
  const result = await checker.call("check", editor.getValue(), 10000);
  if (seq === checkSeq) showStatus(result);
}

editor.on("change", () => {
  clearTimeout(checkTimer);
  $("status").className = "status";
  $("status").textContent = "检查中…";
  checkTimer = setTimeout(checkNow, 350);
});

$("status").addEventListener("click", () => {
  const m = loc.exec($("status").textContent);
  if (m) {
    editor.focus();
    editor.setCursor({ line: Number(m[1]) - 1, ch: Number(m[2]) - 1 });
  }
});

// ---- output tabs -----------------------------------------------------------

const tabs = { output: "", main: "", runtime: "" };
let current = "output";

function showTab(name) {
  current = name;
  for (const t of document.querySelectorAll(".tab")) {
    t.setAttribute("aria-selected", String(t.dataset.tab === name));
  }
  const isCode = name !== "output";
  $("output").classList.toggle("hidden", isCode);
  $("code-wrap").classList.toggle("hidden", !isCode);
  if (isCode) {
    viewer.setValue(tabs[name] || "// 先点击“编译到 MoonBit”");
    viewer.refresh();
  }
  $("out-note").textContent =
    name === "main" && tabs.main ? "编译生成的 MoonBit 代码" :
    name === "runtime" ? "编译后程序共用的运行时" : "";
}

for (const t of document.querySelectorAll(".tab")) {
  t.addEventListener("click", async () => {
    if (t.dataset.tab === "runtime" && !tabs.runtime) {
      tabs.runtime = reindent(await runner.call("runtime", ""));
    }
    showTab(t.dataset.tab);
  });
}

/**
 * Indent generated code by its brackets (`moonpp build` runs `moon fmt`,
 * which is not available here).
 */
function reindent(code) {
  let depth = 0;
  const out = [];
  for (const raw of code.split("\n")) {
    const line = raw.trim();
    let lead = 0;
    while (lead < line.length && "})]".includes(line[lead])) lead++;
    out.push(line === "" ? "" : "  ".repeat(Math.max(0, depth - lead)) + line);
    let inStr = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (inStr) {
        if (c === "\\") i++;
        else if (c === '"') inStr = false;
      } else if (c === '"') inStr = true;
      else if (c === "'" && line[i + 2] === "'") i += 2;
      else if (c === "'" && line[i + 1] === "\\") i = line.indexOf("'", i + 2);
      else if (c === "/" && line[i + 1] === "/") break;
      else if ("{([".includes(c)) depth++;
      else if ("})]".includes(c)) depth--;
      if (i < 0) break;
    }
    if (depth < 0) depth = 0;
  }
  return out.join("\n");
}

function setOutput(text, isErr) {
  const out = $("output");
  out.className = isErr ? "err" : "";
  out.textContent = text === "" ? "（没有输出）" : text;
}

async function busy(button, label, work) {
  const old = button.textContent;
  button.disabled = true;
  button.textContent = label;
  try {
    await work();
  } finally {
    button.disabled = false;
    button.textContent = old;
  }
}

function runProgram() {
  return busy($("run"), "运行中…", async () => {
    showTab("output");
    $("output").className = "";
    $("output").textContent = "运行中…";
    const result = await runner.call("run", editor.getValue(), 15000);
    const isErr = loc.test(result) || result.startsWith("error:");
    setOutput(result, isErr);
    if (loc.test(result)) markError(result);
  });
}

function compileProgram() {
  return busy($("compile"), "编译中…", async () => {
    const result = await runner.call("compile", editor.getValue(), 15000);
    if (result.startsWith("error:")) {
      tabs.main = "";
      showTab("output");
      setOutput(result, true);
      markError(result);
    } else {
      tabs.main = reindent(result);
      showTab("main");
    }
  });
}

$("run").addEventListener("click", runProgram);
$("compile").addEventListener("click", compileProgram);

// ---- examples and sharing --------------------------------------------------

const select = $("examples");
for (const [name] of examples) {
  const o = document.createElement("option");
  o.value = name;
  o.textContent = name + ".mbtpp";
  select.append(o);
}
select.addEventListener("change", () => {
  const ex = examples.find(([n]) => n === select.value);
  if (ex) {
    editor.setValue(ex[1]);
    tabs.main = "";
    setOutput("", false);
    $("output").innerHTML = '<span class="hint">点击“运行”用解释器执行，点击“编译到 MoonBit”查看生成的代码。</span>';
    showTab("output");
    history.replaceState(null, "", location.pathname);
  }
});

function encode(s) {
  const bytes = new TextEncoder().encode(s);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function decode(s) {
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/"));
  return new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
}

$("share").addEventListener("click", async () => {
  const url = location.origin + location.pathname + "#code=" + encode(editor.getValue());
  history.replaceState(null, "", url);
  try {
    await navigator.clipboard.writeText(url);
    $("share").textContent = "已复制链接";
  } catch {
    $("share").textContent = "链接已在地址栏";
  }
  setTimeout(() => ($("share").textContent = "分享"), 1500);
});

let initial = null;
if (location.hash.startsWith("#code=")) {
  try {
    initial = decode(location.hash.slice(6));
    select.value = "";
  } catch {
    initial = null;
  }
}
editor.setValue(initial ?? examples[0][1]);
if (initial !== null) select.selectedIndex = -1;
