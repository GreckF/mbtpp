// MoonBit++ for VS Code. The checking is done by `moonpp ide <file>`, which
// type checks the package of the file and prints, as JSON, the diagnostics,
// the types and definitions of the names used, and the goals of tactic
// blocks. Unsaved buffers are passed in an overlay file. Everything shown
// (diagnostics, hovers, definitions, the info view) comes from the last
// result for the file.
const vscode = require("vscode");
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

/** @type {vscode.DiagnosticCollection} */
let diagnostics;
/** Results of `moonpp ide`, by file key: { names, proofs, diags, symbols }. */
const results = new Map();
/** The package (directory or file) of each checked file, and its run. */
const runs = new Map();
let seq = 0;
let statusItem;
let infoPanel;
let output;
const timers = new Map();

function config() {
  return vscode.workspace.getConfiguration("mbtpp");
}

function key(file) {
  const p = path.resolve(file);
  return process.platform === "win32" ? p.toLowerCase() : p;
}

function quote(s) {
  return '"' + s.replace(/"/g, '\\"') + '"';
}

/** What `moonpp` checks for a file: its directory if it has a moon.pkg, else the file. */
function target(file) {
  const dir = path.dirname(file);
  const isPkg = ["moon.pkg", "moon.pkg.json"].some((f) => fs.existsSync(path.join(dir, f)));
  return { isPkg, dir, path: isPkg ? dir : file };
}

function moonpp() {
  return config().get("moonppPath") || "moonpp";
}

// ---------------------------------------------------------------- checking

function scheduleCheck(doc, delay) {
  if (doc.languageId !== "mbtpp" || doc.uri.scheme !== "file") return;
  const t = target(doc.uri.fsPath);
  const k = key(t.path);
  clearTimeout(timers.get(k));
  timers.set(k, setTimeout(() => check(doc.uri.fsPath), delay));
}

/** Check the package of `file`; resolves when the result is applied (or superseded). */
function check(file) {
  return new Promise((resolve) => checkThen(file, resolve));
}

function checkThen(file, done) {
  const t = target(file);
  const k = key(t.path);
  const id = ++seq;
  const prev = runs.get(k);
  if (prev && prev.proc) killTree(prev.proc);
  // unsaved buffers of the package
  const overlay = {};
  for (const d of vscode.workspace.textDocuments) {
    if (d.languageId === "mbtpp" && d.isDirty && d.uri.scheme === "file") {
      const f = d.uri.fsPath;
      if (key(f) === key(file) || (t.isPkg && key(path.dirname(f)) === key(t.dir))) {
        overlay[f] = d.getText();
      }
    }
  }
  const tmp = path.join(os.tmpdir(), `mbtpp-overlay-${process.pid}-${id}.json`);
  fs.writeFileSync(tmp, JSON.stringify(overlay));
  setStatus("checking");
  const cmd = `${moonpp()} ide ${quote(file)} --overlay ${quote(tmp)}`;
  const proc = cp.exec(
    cmd,
    { cwd: t.dir, maxBuffer: 64 * 1024 * 1024, windowsHide: true },
    (err, stdout, stderr) => {
      clearTimeout(limit);
      fs.rm(tmp, () => {});
      const run = runs.get(k);
      if (!run || run.id !== id) return done(); // superseded
      run.proc = undefined;
      let res;
      try {
        res = JSON.parse(stdout.trim().split(/\r?\n/).pop());
      } catch (e) {
        const msg = timedOut
          ? `the check took more than ${timeout} s (see the setting mbtpp.checkTimeout)`
          : (stderr || stdout || String(err)).trim();
        output.appendLine(`$ ${cmd}\n${msg}`);
        setStatus("failed", msg.split("\n")[0]);
        return done();
      }
      apply(res);
      done();
    },
  );
  // the whole check is stopped after `mbtpp.checkTimeout` seconds
  const timeout = config().get("checkTimeout") ?? 120;
  let timedOut = false;
  const limit =
    timeout > 0
      ? setTimeout(() => {
          timedOut = true;
          killTree(proc);
        }, timeout * 1000)
      : undefined;
  runs.set(k, { id, proc });
}

/**
 * Stop a check: `cp.exec` runs a shell, and on Windows killing it leaves
 * moonpp (a child of the shell) running, so the whole tree is stopped.
 */
function killTree(proc) {
  if (proc.exitCode !== null) return;
  if (process.platform === "win32") {
    cp.exec(`taskkill /pid ${proc.pid} /T /F`, { windowsHide: true }, () => {});
  } else {
    proc.kill();
  }
}

function apply(res) {
  const byFile = new Map();
  const empty = (f) => ({ file: f, names: [], proofs: [], diags: [], symbols: [] });
  for (const f of res.files) byFile.set(key(f), empty(f));
  const entry = (f) => {
    const k = key(f);
    if (!byFile.has(k)) byFile.set(k, empty(f));
    return byFile.get(k);
  };
  for (const n of res.names) entry(n.file).names.push(n);
  for (const s of res.symbols || []) entry(s.file).symbols.push(s);
  for (const p of res.proofs) entry(p.file).proofs.push(p);
  const hints = config().get("mbtHints");
  for (const d of res.diagnostics) {
    if (d.severity === "hint" && !hints) continue;
    entry(d.file).diags.push(d);
  }
  let errors = 0;
  for (const [k, r] of byFile) {
    results.set(k, r);
    const uri = vscode.Uri.file(r.file);
    const doc = vscode.workspace.textDocuments.find((d) => key(d.uri.fsPath) === k);
    diagnostics.set(
      uri,
      r.diags.map((d) => {
        if (d.severity === "error") errors++;
        return toDiagnostic(d, doc);
      }),
    );
  }
  setStatus(errors > 0 ? "error" : "ok");
  updateInfoView();
}

function toDiagnostic(d, doc) {
  const line = Math.max(0, d.line - 1);
  const col = Math.max(0, d.col - 1);
  let range = new vscode.Range(line, col, line, col + 1);
  if (doc && line < doc.lineCount) {
    const text = doc.lineAt(line);
    if (d.severity === "hint") {
      range = new vscode.Range(line, text.firstNonWhitespaceCharacterIndex, line, text.text.length);
    } else {
      const w = doc.getWordRangeAtPosition(new vscode.Position(line, col), /[@\w:.]+|\S/);
      range = w || new vscode.Range(line, col, line, text.text.length);
    }
  }
  const sev =
    d.severity === "error" ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Hint;
  const diag = new vscode.Diagnostic(range, d.message, sev);
  diag.source = "moonpp";
  if (d.mbt) diag.code = "mbt";
  return diag;
}

function setStatus(state, detail) {
  const icons = { checking: "$(sync~spin)", ok: "$(check)", error: "$(error)", failed: "$(warning)" };
  statusItem.text = `${icons[state]} MoonBit++`;
  statusItem.tooltip =
    state === "failed"
      ? `moonpp could not run: ${detail}\nSet mbtpp.moonppPath, or see the MoonBit++ output.`
      : state === "checking"
        ? "Checking…"
        : state === "ok"
          ? "No errors"
          : "Errors in the package";
  statusItem.show();
}

// ---------------------------------------------------------------- lookups

function resultFor(doc) {
  return results.get(key(doc.uri.fsPath));
}

function nameAt(doc, pos) {
  const r = resultFor(doc);
  if (!r) return undefined;
  const line = pos.line + 1;
  const col = pos.character + 1;
  let best;
  for (const n of r.names) {
    if (n.line === line && n.col <= col && col <= n.col + n.len) {
      // the innermost (shortest) one
      if (!best || n.len < best.len) best = n;
    }
  }
  return best;
}

const hoverProvider = {
  provideHover(doc, pos) {
    const n = nameAt(doc, pos);
    if (!n) return undefined;
    const md = new vscode.MarkdownString();
    md.appendCodeblock(n.type, "mbtpp");
    const range = new vscode.Range(n.line - 1, n.col - 1, n.line - 1, n.col - 1 + n.len);
    return new vscode.Hover(md, range);
  },
};

const definitionProvider = {
  provideDefinition(doc, pos) {
    const n = nameAt(doc, pos);
    if (!n || !n.def) return undefined;
    // the declaration is at `fn`, `enum`, ...: go to the name after it
    const g = n.type.slice(0, n.type.indexOf(" : "));
    const s = { name: g, line: n.def.line, col: n.def.col };
    return new vscode.Location(vscode.Uri.file(n.def.file), symbolRange(s, lineOf(n.def.file, n.def.line)));
  },
};

/** A line of a file, from its open document or from disk. */
function lineOf(file, line) {
  const doc = vscode.workspace.textDocuments.find((d) => key(d.uri.fsPath) === key(file));
  try {
    const text = doc ? doc.getText() : fs.readFileSync(file, "utf8");
    return text.split("\n")[line - 1];
  } catch (e) {
    return undefined;
  }
}

const codeActionProvider = {
  provideCodeActions(doc, _range, context) {
    const actions = [];
    for (const d of context.diagnostics) {
      if (d.code !== "mbt") continue;
      const line = doc.lineAt(d.range.start.line);
      const indent = line.text.slice(0, line.firstNonWhitespaceCharacterIndex);
      const a = new vscode.CodeAction("Add #mbt", vscode.CodeActionKind.QuickFix);
      a.edit = new vscode.WorkspaceEdit();
      a.edit.insert(doc.uri, new vscode.Position(line.lineNumber, 0), indent + "#mbt\n");
      a.diagnostics = [d];
      a.isPreferred = true;
      actions.push(a);
    }
    if (actions.length > 0) {
      const all = new vscode.CodeAction(
        "Add #mbt everywhere possible (moonpp fix)",
        vscode.CodeActionKind.QuickFix,
      );
      all.command = { command: "mbtpp.fix", title: "moonpp fix" };
      actions.push(all);
    }
    return actions;
  },
};

// ---------------------------------------------------------------- symbols

function symbolKind(kind) {
  const K = vscode.SymbolKind;
  return (
    {
      fn: K.Function,
      lemma: K.Function,
      let: K.Variable,
      enum: K.Enum,
      struct: K.Struct,
      trait: K.Interface,
      type: K.Class,
      constructor: K.EnumMember,
      field: K.Field,
      method: K.Method,
    }[kind] || K.Function
  );
}

/** The range of the name of a declaration (its position is that of `fn`, `enum`, ...). */
function symbolRange(s, lineText) {
  const i = s.name.lastIndexOf("::");
  const short = i >= 0 ? s.name.slice(i + 2) : s.name;
  let col = s.col - 1;
  if (lineText !== undefined) {
    const k = lineText.indexOf(short, col);
    if (k >= 0) col = k;
  }
  return new vscode.Range(s.line - 1, col, s.line - 1, col + short.length);
}

/** Outline: `Vector::Cons` is `Cons` under `Vector` when both are in the file. */
const documentSymbolProvider = {
  async provideDocumentSymbols(doc) {
    if (!resultFor(doc)) await check(doc.uri.fsPath);
    const r = resultFor(doc);
    if (!r) return [];
    const syms = [...r.symbols].sort((a, b) => a.line - b.line || a.col - b.col);
    const top = new Map();
    const out = [];
    const mk = (s, name) => {
      const l = doc.lineAt(Math.min(s.line - 1, doc.lineCount - 1));
      const line = l.range;
      const sel = symbolRange(s, l.text);
      return new vscode.DocumentSymbol(
        name,
        s.kind,
        symbolKind(s.kind),
        line.contains(sel) ? line : sel,
        sel,
      );
    };
    for (const s of syms) {
      const i = s.name.lastIndexOf("::");
      const parent = i > 0 ? top.get(s.name.slice(0, i)) : undefined;
      if (parent) {
        parent.children.push(mk(s, s.name.slice(i + 2)));
      } else {
        const d = mk(s, s.name);
        top.set(s.name, d);
        out.push(d);
      }
    }
    return out;
  },
};

/** Symbol search (Ctrl+T): all .mbtpp files of the workspace are checked the first time. */
let workspaceChecked;
const workspaceSymbolProvider = {
  async provideWorkspaceSymbols(query) {
    if (!workspaceChecked) {
      workspaceChecked = (async () => {
        const files = await vscode.workspace.findFiles(
          "**/*.mbtpp",
          "**/{_build,.mooncakes,mbtpp_out,_mbtpp_build,node_modules,.git}/**",
          2000,
        );
        const seen = new Set();
        for (const f of files) {
          const t = target(f.fsPath);
          if (results.has(key(f.fsPath)) || seen.has(key(t.path))) continue;
          seen.add(key(t.path));
          await check(f.fsPath);
        }
      })();
    }
    await workspaceChecked;
    const q = query.toLowerCase();
    const matches = (name) => {
      let i = 0;
      for (const c of name.toLowerCase()) if (i < q.length && c === q[i]) i++;
      return i === q.length;
    };
    const out = [];
    for (const r of results.values()) {
      for (const s of r.symbols) {
        const i = s.name.lastIndexOf("::");
        if (!matches(i > 0 ? s.name.slice(i + 2) : s.name)) continue;
        out.push(
          new vscode.SymbolInformation(
            i > 0 ? s.name.slice(i + 2) : s.name,
            symbolKind(s.kind),
            i > 0 ? s.name.slice(0, i) : path.basename(r.file),
            new vscode.Location(vscode.Uri.file(r.file), symbolRange(s)),
          ),
        );
      }
    }
    return out;
  },
};

// ---------------------------------------------------------------- info view

/** The end offset of the block whose `{` follows `from`, or -1. */
function blockEnd(text, from) {
  let i = text.indexOf("{", from);
  if (i < 0) return -1;
  let depth = 0;
  for (; i < text.length; i++) {
    const c = text[i];
    if (c === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++;
    } else if (c === '"') {
      for (i++; i < text.length && text[i] !== '"' && text[i] !== "\n"; i++) {
        if (text[i] === "\\") i++;
      }
    } else if (c === "{") {
      depth++;
    } else if (c === "}") {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

function before(a, b) {
  return a.line < b.line || (a.line === b.line && a.col <= b.col);
}

/** What the info view shows for a cursor position. */
function infoAt(doc, pos) {
  const r = resultFor(doc);
  if (!r) return { kind: "none", messages: [] };
  const cur = { line: pos.line + 1, col: pos.character + 1 };
  const messages = r.diags
    .filter((d) => d.severity === "error" && d.line === cur.line)
    .map((d) => d.message);
  const text = doc.getText();
  const offset = doc.offsetAt(pos);
  let proof;
  for (const p of r.proofs) {
    if (!before(p, cur)) continue;
    const start = doc.offsetAt(new vscode.Position(p.line - 1, p.col - 1));
    const end = blockEnd(text, start);
    if (offset <= (end < 0 ? text.length : end)) proof = p; // the innermost one
  }
  if (proof) {
    let tac;
    let index = -1;
    proof.tactics.forEach((t, k) => {
      if (t.line > 0 && before(t, cur)) {
        tac = t;
        index = k;
      }
    });
    if (!tac) return { kind: "goals", where: "start of the proof", goals: proof.start, messages };
    const line = doc.lineAt(tac.line - 1).text.trim();
    if (tac.goals === null) {
      // the error of a failed tactic is reported at the tactic
      const errs = r.diags
        .filter((d) => d.severity === "error" && d.line === tac.line)
        .map((d) => d.message);
      return {
        kind: "failed",
        where: line,
        goals: index > 0 ? proof.tactics[index - 1].goals || [] : proof.start,
        messages: errs.length > 0 ? errs : messages,
      };
    }
    return { kind: "goals", where: "after " + line, goals: tac.goals, messages };
  }
  const n = nameAt(doc, pos);
  if (n) return { kind: "type", type: n.type, messages };
  return { kind: "none", messages };
}

function showInfoView() {
  if (infoPanel) {
    infoPanel.reveal(vscode.ViewColumn.Beside, true);
  } else {
    infoPanel = vscode.window.createWebviewPanel(
      "mbtppInfo",
      "MoonBit++ Info",
      { viewColumn: vscode.ViewColumn.Beside, preserveFocus: true },
      { enableScripts: true },
    );
    infoPanel.webview.html = infoHtml();
    infoPanel.onDidDispose(() => (infoPanel = undefined));
  }
  updateInfoView();
}

function updateInfoView() {
  if (!infoPanel) return;
  const ed = vscode.window.activeTextEditor;
  if (!ed || ed.document.languageId !== "mbtpp") return;
  infoPanel.webview.postMessage(infoAt(ed.document, ed.selection.active));
}

function infoHtml() {
  return `<!doctype html>
<html><head><meta charset="utf-8">
<style>
  body { font-family: var(--vscode-editor-font-family); font-size: var(--vscode-editor-font-size); padding: 6px 12px; }
  h3 { font-family: var(--vscode-font-family); font-size: 12px; font-weight: 600; color: var(--vscode-descriptionForeground); margin: 10px 0 6px; }
  .goal { border-left: 2px solid var(--vscode-textLink-foreground); padding: 4px 10px; margin-bottom: 10px; white-space: pre-wrap; }
  .goal .hyp { color: var(--vscode-editor-foreground); }
  .goal .turnstile { color: var(--vscode-textLink-foreground); font-weight: 600; }
  .done { color: var(--vscode-testing-iconPassed, #3fb950); }
  .msg { color: var(--vscode-errorForeground); white-space: pre-wrap; border-left: 2px solid var(--vscode-errorForeground); padding: 4px 10px; margin-bottom: 8px; }
  .muted { color: var(--vscode-descriptionForeground); font-family: var(--vscode-font-family); }
  .ty { white-space: pre-wrap; }
</style></head>
<body><div id="root" class="muted">Move the cursor into a proof block or onto a name.</div>
<script>
  const root = document.getElementById("root");
  const esc = (s) => s.replace(/[&<>]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[c]);
  window.addEventListener("message", (e) => {
    const s = e.data;
    let h = "";
    if (s.kind === "goals" || s.kind === "failed") {
      h += "<h3>" + (s.kind === "failed" ? "Tactic failed: " : "") + esc(s.where) + "</h3>";
      if (s.kind === "goals" && s.goals.length === 0) h += '<div class="done">No goals: the proof is complete.</div>';
      if (s.kind === "failed") h += '<h3>Goals before it</h3>';
      s.goals.forEach((g, k) => {
        h += '<div class="goal">';
        if (s.goals.length > 1) h += '<div class="muted">Goal ' + (k + 1) + " of " + s.goals.length + "</div>";
        for (const x of g.hyps) h += '<div class="hyp">' + esc(x) + "</div>";
        h += '<div><span class="turnstile">⊢</span> ' + esc(g.goal) + "</div></div>";
      });
    } else if (s.kind === "type") {
      h += "<h3>Type</h3><div class=\\"ty\\">" + esc(s.type) + "</div>";
    } else {
      h += '<div class="muted">No goals here. Move the cursor into a proof block or onto a name.</div>';
    }
    if (s.messages && s.messages.length > 0) {
      h += "<h3>Messages</h3>";
      for (const m of s.messages) h += '<div class="msg">' + esc(m) + "</div>";
    }
    root.className = "";
    root.innerHTML = h;
  });
</script></body></html>`;
}

// ---------------------------------------------------------------- commands

let terminal;

function runInTerminal(sub) {
  const ed = vscode.window.activeTextEditor;
  if (!ed || ed.document.languageId !== "mbtpp") {
    vscode.window.showWarningMessage("Open a .mbtpp file first.");
    return;
  }
  const doc = ed.document;
  const go = () => {
    const t = target(doc.uri.fsPath);
    if (!terminal || terminal.exitStatus !== undefined) {
      terminal = vscode.window.createTerminal("MoonBit++");
    }
    terminal.show(true);
    terminal.sendText(`cd ${quote(t.dir)}`);
    terminal.sendText(`${moonpp()} ${sub} ${quote(t.path)}`);
  };
  if (doc.isDirty) doc.save().then(go);
  else go();
}

// ---------------------------------------------------------------- activation

function activate(context) {
  diagnostics = vscode.languages.createDiagnosticCollection("mbtpp");
  output = vscode.window.createOutputChannel("MoonBit++");
  statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 0);
  statusItem.command = "mbtpp.infoView";
  const sel = { language: "mbtpp", scheme: "file" };
  context.subscriptions.push(
    diagnostics,
    output,
    statusItem,
    vscode.languages.registerHoverProvider(sel, hoverProvider),
    vscode.languages.registerDefinitionProvider(sel, definitionProvider),
    vscode.languages.registerDocumentSymbolProvider(sel, documentSymbolProvider),
    vscode.languages.registerWorkspaceSymbolProvider(workspaceSymbolProvider),
    vscode.languages.registerCodeActionsProvider(sel, codeActionProvider, {
      providedCodeActionKinds: [vscode.CodeActionKind.QuickFix],
    }),
    vscode.workspace.onDidOpenTextDocument((d) => scheduleCheck(d, 0)),
    vscode.workspace.onDidSaveTextDocument((d) => scheduleCheck(d, 0)),
    vscode.workspace.onDidChangeTextDocument((e) => {
      if (config().get("checkOnType")) scheduleCheck(e.document, config().get("checkDelay"));
    }),
    vscode.window.onDidChangeTextEditorSelection(() => updateInfoView()),
    vscode.window.onDidChangeActiveTextEditor((ed) => {
      if (ed && ed.document.languageId === "mbtpp") {
        statusItem.show();
        if (!resultFor(ed.document)) scheduleCheck(ed.document, 0);
        updateInfoView();
      } else {
        statusItem.hide();
      }
    }),
    vscode.commands.registerCommand("mbtpp.run", () => runInTerminal("run")),
    vscode.commands.registerCommand("mbtpp.runCompiled", () => runInTerminal("run --compiled")),
    vscode.commands.registerCommand("mbtpp.check", () => runInTerminal("check")),
    vscode.commands.registerCommand("mbtpp.build", () => runInTerminal("build")),
    vscode.commands.registerCommand("mbtpp.fix", () => runInTerminal("fix")),
    vscode.commands.registerCommand("mbtpp.infoView", showInfoView),
  );
  for (const d of vscode.workspace.textDocuments) scheduleCheck(d, 0);
}

function deactivate() {}

module.exports = { activate, deactivate };
